import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';

class AgendaService {
  AgendaService(this.uid);

  final String uid;
  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _weekDoc(String weekKey) =>
      _db.collection('users').doc(uid).collection('agenda_weeks').doc(weekKey);

  String weekKeyFromMonday(DateTime monday) {
    final d = DateTime(monday.year, monday.month, monday.day);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static DateTime mondayOf(DateTime anyDay) {
    final day = DateTime(anyDay.year, anyDay.month, anyDay.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  Stream<Map<String, List<AgendaSlotItem>>> streamWeek(String weekKey) {
    return _weekDoc(weekKey).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return <String, List<AgendaSlotItem>>{};
      final raw = data['slots'];
      if (raw is! Map) return <String, List<AgendaSlotItem>>{};
      final out = <String, List<AgendaSlotItem>>{};
      for (final e in raw.entries) {
        out[e.key] = _parseSlotList(e.value);
      }
      return out;
    });
  }

  List<AgendaSlotItem> _parseSlotList(dynamic v) {
    if (v is! List) return [];
    return v.map((e) {
      if (e is! Map) return AgendaSlotItem(id: '', title: '', done: false);
      return AgendaSlotItem.fromMap(Map<String, dynamic>.from(e));
    }).where((item) => item.id.isNotEmpty).toList();
  }

  String _newItemId() =>
      _db.collection('users').doc(uid).collection('agenda_weeks').doc().id;

  Future<void> addSlotItem({
    required String weekKey,
    required int dayIndex,
    required int hour,
    required String title,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;

    final ref = _weekDoc(weekKey);
    final slotKey = '${dayIndex}_$hour';
    final id = _newItemId();

    await _db.runTransaction((txn) async {
      final snap = await txn.get(ref);
      final slots = Map<String, dynamic>.from(snap.data()?['slots'] ?? {});
      final list = List<Map<String, dynamic>>.from(slots[slotKey] ?? []);
      list.add({'id': id, 'title': trimmed, 'done': false});
      slots[slotKey] = list;
      txn.set(
        ref,
        {
          'slots': slots,
          'weekKey': weekKey,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> setSlotItemDone({
    required String weekKey,
    required String slotKey,
    required String itemId,
    required bool done,
  }) async {
    final ref = _weekDoc(weekKey);

    await _db.runTransaction((txn) async {
      final snap = await txn.get(ref);
      final slots = Map<String, dynamic>.from(snap.data()?['slots'] ?? {});
      final list = List<Map<String, dynamic>>.from(slots[slotKey] ?? []);
      final idx = list.indexWhere((e) => e['id'] == itemId);
      if (idx < 0) return;
      list[idx] = {...list[idx], 'done': done};
      slots[slotKey] = list;
      txn.set(
        ref,
        {
          'slots': slots,
          'weekKey': weekKey,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> removeSlotItem({
    required String weekKey,
    required String slotKey,
    required String itemId,
  }) async {
    final ref = _weekDoc(weekKey);

    await _db.runTransaction((txn) async {
      final snap = await txn.get(ref);
      final slots = Map<String, dynamic>.from(snap.data()?['slots'] ?? {});
      final list = List<Map<String, dynamic>>.from(slots[slotKey] ?? []);
      list.removeWhere((e) => e['id'] == itemId);
      if (list.isEmpty) {
        slots.remove(slotKey);
      } else {
        slots[slotKey] = list;
      }
      txn.set(
        ref,
        {
          'slots': slots,
          'weekKey': weekKey,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

}
