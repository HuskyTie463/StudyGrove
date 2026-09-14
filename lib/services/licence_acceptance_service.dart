import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../legal/beta_licence.dart';
import 'app_version.dart';

/// Licence acceptance retention (do not promise indefinite storage):
///
/// Records are retained for the life of the signed-in account plus a
/// reasonable period after deletion as required for legal defence (as
/// described in the in-app Privacy Policy; typically up to 7 years where
/// lawful), then deleted with account deletion where lawful.
///
/// Guest (no account) records live only on this device via SharedPreferences.
/// Clearing app data or reinstalling may remove them.
///
/// Cloud path: users/{uid}/licenceAcceptances/{autoId} — append-only so
/// historical rows are preserved when terms are revised.
class LicenceSaveException implements Exception {
  LicenceSaveException([this.message = saveFailedMessage]);

  static const saveFailedMessage =
      'Could not save your acceptance. Check your connection and try again.';

  final String message;

  @override
  String toString() => message;
}

class LicenceAcceptanceRecord {
  const LicenceAcceptanceRecord({
    this.id,
    this.accountId,
    required this.version,
    required this.acceptedAt,
    required this.appVersion,
    required this.agreementText,
  });

  final String? id;
  final String? accountId;
  final String version;
  final DateTime acceptedAt;
  final String appVersion;
  final String agreementText;

  LicenceAcceptanceRecord copyWith({
    String? id,
    String? accountId,
    String? version,
    DateTime? acceptedAt,
    String? appVersion,
    String? agreementText,
  }) {
    return LicenceAcceptanceRecord(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      version: version ?? this.version,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      appVersion: appVersion ?? this.appVersion,
      agreementText: agreementText ?? this.agreementText,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'accountId': accountId,
        'version': version,
        'acceptedAtIso': acceptedAt.toUtc().toIso8601String(),
        'appVersion': appVersion,
        'agreementText': agreementText,
      };

  factory LicenceAcceptanceRecord.fromJson(Map<String, dynamic> json) {
    final iso = json['acceptedAtIso'] as String?;
    return LicenceAcceptanceRecord(
      id: json['id'] as String?,
      accountId: json['accountId'] as String?,
      version: json['version'] as String? ?? '',
      acceptedAt: iso == null || iso.isEmpty
          ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
          : DateTime.parse(iso),
      appVersion: json['appVersion'] as String? ?? '',
      agreementText: json['agreementText'] as String? ?? '',
    );
  }
}

abstract class LicenceRecordStore {
  Future<List<LicenceAcceptanceRecord>> loadAll();

  /// Appends a new row. Must not overwrite the only historical record.
  /// Implementations confirm the write succeeded before returning.
  Future<LicenceAcceptanceRecord> append(LicenceAcceptanceRecord record);
}

class MemoryLicenceStore implements LicenceRecordStore {
  MemoryLicenceStore({this.failNextAppend = false});

  final List<LicenceAcceptanceRecord> records = [];
  bool failNextAppend;
  int _seq = 0;

  @override
  Future<List<LicenceAcceptanceRecord>> loadAll() async =>
      List<LicenceAcceptanceRecord>.from(records);

  @override
  Future<LicenceAcceptanceRecord> append(LicenceAcceptanceRecord record) async {
    if (failNextAppend) {
      failNextAppend = false;
      throw LicenceSaveException();
    }
    final stored = record.copyWith(id: record.id ?? 'mem-${_seq++}');
    records.add(stored);
    return stored;
  }
}

class SharedPreferencesLicenceStore implements LicenceRecordStore {
  SharedPreferencesLicenceStore({this.prefsKey = prefsStorageKey});

  static const prefsStorageKey = 'sg_licence_acceptances_v1';

  final String prefsKey;

  @override
  Future<List<LicenceAcceptanceRecord>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map((e) => LicenceAcceptanceRecord.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<LicenceAcceptanceRecord> append(LicenceAcceptanceRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadAll();
    final stored = record.copyWith(
      id: record.id ?? 'local-${existing.length}-${record.acceptedAt.millisecondsSinceEpoch}',
    );
    final next = [...existing, stored];
    final ok = await prefs.setString(
      prefsKey,
      jsonEncode(next.map((e) => e.toJson()).toList()),
    );
    if (!ok) throw LicenceSaveException();
    final confirmed = await loadAll();
    final found = confirmed.any(
      (e) =>
          e.version == stored.version &&
          e.acceptedAt.toUtc() == stored.acceptedAt.toUtc() &&
          e.agreementText == stored.agreementText,
    );
    if (!found) throw LicenceSaveException();
    return stored;
  }
}

class FirestoreLicenceStore implements LicenceRecordStore {
  FirestoreLicenceStore(this.uid, {FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(uid).collection('licenceAcceptances');

  @override
  Future<List<LicenceAcceptanceRecord>> loadAll() async {
    final snap = await _col.get();
    return snap.docs.map(_fromDoc).toList();
  }

  @override
  Future<LicenceAcceptanceRecord> append(LicenceAcceptanceRecord record) async {
    final doc = _col.doc();
    await doc.set({
      'accountId': uid,
      'version': record.version,
      'acceptedAt': FieldValue.serverTimestamp(),
      'acceptedAtIso': record.acceptedAt.toUtc().toIso8601String(),
      'appVersion': record.appVersion,
      'agreementText': record.agreementText,
    });
    final confirm = await doc.get();
    if (!confirm.exists) throw LicenceSaveException();
    return _fromDoc(confirm);
  }

  LicenceAcceptanceRecord _fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final ts = data['acceptedAt'];
    DateTime acceptedAt;
    if (ts is Timestamp) {
      acceptedAt = ts.toDate();
    } else if (data['acceptedAtIso'] is String) {
      acceptedAt = DateTime.parse(data['acceptedAtIso'] as String);
    } else {
      acceptedAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
    return LicenceAcceptanceRecord(
      id: doc.id,
      accountId: data['accountId'] as String? ?? uid,
      version: data['version'] as String? ?? '',
      acceptedAt: acceptedAt,
      appVersion: data['appVersion'] as String? ?? '',
      agreementText: data['agreementText'] as String? ?? '',
    );
  }
}

typedef CloudLicenceStoreFactory = LicenceRecordStore Function(String uid);

class LicenceAcceptanceService {
  LicenceAcceptanceService({
    LicenceRecordStore? localStore,
    CloudLicenceStoreFactory? cloudStoreFor,
    Future<String> Function()? appVersionReader,
    DateTime Function()? clock,
    this.requiredVersion = BetaLicence.currentVersion,
  })  : _localStore = localStore ?? SharedPreferencesLicenceStore(),
        _cloudStoreFor = cloudStoreFor,
        _appVersionReader = appVersionReader ?? readAppVersion,
        _clock = clock ?? DateTime.now;

  final LicenceRecordStore _localStore;
  final CloudLicenceStoreFactory? _cloudStoreFor;
  final Future<String> Function() _appVersionReader;
  final DateTime Function() _clock;
  final String requiredVersion;

  LicenceRecordStore _cloud(String uid) {
    if (_cloudStoreFor != null) return _cloudStoreFor(uid);
    return FirestoreLicenceStore(uid);
  }

  LicenceAcceptanceRecord? latestOf(Iterable<LicenceAcceptanceRecord> rows) {
    LicenceAcceptanceRecord? best;
    for (final row in rows) {
      if (best == null) {
        best = row;
        continue;
      }
      final byVersion = BetaLicence.compareVersions(row.version, best.version);
      if (byVersion > 0 ||
          (byVersion == 0 && !row.acceptedAt.isBefore(best.acceptedAt))) {
        best = row;
      }
    }
    return best;
  }

  bool _satisfies(LicenceAcceptanceRecord? row) {
    if (row == null) return false;
    return BetaLicence.compareVersions(requiredVersion, row.version) <= 0;
  }

  /// Whether the agreement dialog must be shown.
  ///
  /// True whenever there is **no successful acceptance record** for the
  /// current required version — including existing accounts that used the
  /// app before this feature existed. Appearance of the dialog is never
  /// treated as acceptance. Waits for [uid] to be known (null = guest).
  Future<bool> needsAcceptance({String? uid}) async {
    if (uid != null && uid.isNotEmpty) {
      try {
        final cloudLatest = latestOf(await _cloud(uid).loadAll());
        if (_satisfies(cloudLatest)) return false;

        final localRows = await _localStore.loadAll();
        final guestOrLocal = latestOf(
          localRows.where(
            (r) =>
                r.accountId == null ||
                r.accountId!.isEmpty ||
                r.accountId == uid,
          ),
        );
        if (_satisfies(guestOrLocal)) {
          try {
            await _copyToAccount(guestOrLocal!, uid);
            return false;
          } catch (_) {
            // Signed-in users must have a confirmed cloud row. Show the
            // dialog again so they can retry — do not pretend it saved.
            return true;
          }
        }
        return true;
      } catch (_) {
        final localRows = await _localStore.loadAll();
        final cached = latestOf(
          localRows.where((r) => r.accountId == uid),
        );
        if (_satisfies(cached)) return false;
        return true;
      }
    }

    final localLatest = latestOf(await _localStore.loadAll());
    return !_satisfies(localLatest);
  }

  Future<LicenceAcceptanceRecord> accept({String? uid}) async {
    final record = LicenceAcceptanceRecord(
      accountId: uid,
      version: requiredVersion,
      acceptedAt: _clock().toUtc(),
      appVersion: await _appVersionReader(),
      agreementText: BetaLicence.textForVersion(requiredVersion),
    );

    if (uid != null && uid.isNotEmpty) {
      final saved = await _cloud(uid).append(record.copyWith(accountId: uid));
      try {
        await _localStore.append(saved.copyWith(accountId: uid));
      } catch (_) {
        // Cloud write already confirmed; local cache is best-effort.
      }
      return saved;
    }

    return _localStore.append(record);
  }

  Future<void> _copyToAccount(LicenceAcceptanceRecord source, String uid) async {
    final cloud = _cloud(uid);
    final existing = await cloud.loadAll();
    if (existing.any((r) => _satisfies(r))) return;
    final copied = source.copyWith(
      id: null,
      accountId: uid,
      acceptedAt: source.acceptedAt,
    );
    final saved = await cloud.append(copied);
    try {
      await _localStore.append(saved.copyWith(accountId: uid));
    } catch (_) {}
  }
}

final licenceAcceptanceService = LicenceAcceptanceService();
