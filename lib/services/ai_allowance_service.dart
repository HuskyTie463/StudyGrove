import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'entitlement_service.dart';
import 'study_ai_exceptions.dart';
import 'study_ai_settings.dart';
import 'subscription_catalog.dart';

/// Calendar-month Study AI uses. Synced locally and to Firestore.
class AiAllowanceService extends ChangeNotifier {
  String? _uid;
  var _used = 0;
  var _monthKey = '';
  var _ready = false;

  bool get ready => _ready;
  int get used => _used;
  int get remaining => AiAllowanceLogic.remaining(_used);
  int get limit => AiAllowanceLogic.monthlyLimit;
  String get monthKey => _monthKey;

  DateTime get resetsOn {
    final now = DateTime.now();
    return AiAllowanceLogic.nextReset(now);
  }

  String get remainingLabel {
    return '$remaining of $limit Study AI uses left this month';
  }

  bool get skipsAllowance => skipsFor(voice: false);

  bool skipsFor({required bool voice}) {
    if (studyAiSettings.usingCustomKey) return true;
    if (voice && studyAiSettings.usingCustomTtsKey) return true;
    return false;
  }

  Future<void> bindUser(String uid) async {
    if (_uid == uid && _ready) return;
    _uid = uid;
    final prefs = await SharedPreferences.getInstance();
    final storedMonth = prefs.getString(_monthPrefsKey(uid));
    final storedUsed = prefs.getInt(_usedPrefsKey(uid)) ?? 0;
    final rolled = AiAllowanceLogic.applyReset(
      storedMonth: storedMonth,
      storedUsed: storedUsed,
      now: DateTime.now(),
    );
    _monthKey = rolled.monthKey;
    _used = rolled.used;
    _ready = true;
    notifyListeners();
    await _persist(localOnly: true);
    await _hydrateFromCloud(uid);
  }

  Future<void> unbind() async {
    _uid = null;
    _used = 0;
    _monthKey = '';
    _ready = false;
    notifyListeners();
  }

  Future<void> ensureCanUse({int units = 1, bool voice = false}) async {
    await _rollIfNeeded();
    if (skipsFor(voice: voice)) return;
    if (!entitlementService.isPro) {
      throw StudyAiProRequiredException();
    }
    if (!AiAllowanceLogic.canConsume(_used, units)) {
      throw StudyAiAllowanceException(resetsOn: resetsOn);
    }
  }

  Future<void> consume({int units = 1, bool voice = false}) async {
    await ensureCanUse(units: units, voice: voice);
    if (skipsFor(voice: voice)) return;
    _used += units;
    await _persist();
    notifyListeners();
  }

  /// Debug / Windows owner: refill the calendar month.
  Future<void> resetForTesting() async {
    if (!kDebugMode) return;
    _used = 0;
    _monthKey = AiAllowanceLogic.monthKey(DateTime.now());
    await _persist();
    notifyListeners();
  }

  Future<void> _rollIfNeeded() async {
    final rolled = AiAllowanceLogic.applyReset(
      storedMonth: _monthKey.isEmpty ? null : _monthKey,
      storedUsed: _used,
      now: DateTime.now(),
    );
    if (rolled.monthKey == _monthKey && rolled.used == _used) return;
    _monthKey = rolled.monthKey;
    _used = rolled.used;
    await _persist();
    notifyListeners();
  }

  Future<void> _hydrateFromCloud(String uid) async {
    if (uid.isEmpty || uid == 'NO_USER') return;
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data()?['aiAllowance'] as Map<String, dynamic>?;
      if (data == null) return;
      final rolled = AiAllowanceLogic.applyReset(
        storedMonth: data['monthKey'] as String?,
        storedUsed: (data['used'] as num?)?.toInt() ?? 0,
        now: DateTime.now(),
      );
      // Take the higher used count so a second device cannot reset the cap.
      if (rolled.monthKey == _monthKey && rolled.used > _used) {
        _used = rolled.used;
        await _persist(localOnly: true);
        notifyListeners();
      } else if (rolled.monthKey == _monthKey) {
        await _persist();
      }
    } catch (_) {}
  }

  Future<void> _persist({bool localOnly = false}) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_monthPrefsKey(uid), _monthKey);
    await prefs.setInt(_usedPrefsKey(uid), _used);
    if (localOnly || uid == 'NO_USER') return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'aiAllowance': {
          'monthKey': _monthKey,
          'used': _used,
          'limit': limit,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  static String _monthPrefsKey(String uid) => 'ai_allowance_month_$uid';
  static String _usedPrefsKey(String uid) => 'ai_allowance_used_$uid';
}

final aiAllowanceService = AiAllowanceService();

String formatAllowanceReset(DateTime resetsOn) {
  const months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '1 ${months[resetsOn.month - 1]} ${resetsOn.year}';
}
