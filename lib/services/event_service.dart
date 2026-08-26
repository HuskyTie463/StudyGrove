import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../utils/datetime_utils.dart';

class EventService {
  EventService(this.uid);

  final String uid;
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(uid).collection('events');
  CollectionReference<Map<String, dynamic>> get _recurringCol =>
      _db.collection('users').doc(uid).collection('recurring_events');

  AppEvent _oneOffFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d,
      {String? fallbackDayKey}) {
    final data = d.data();
    final start = (data['startMinutes'] as int?) ?? 0;
    return AppEvent(
      id: d.id,
      title: (data['title'] as String?) ?? '',
      dayKey: (data['dayKey'] as String?) ?? fallbackDayKey ?? '',
      startMinutes: start,
      endMinutes: data['endMinutes'] as int?,
      location: data['location'] as String?,
      subjectId: data['subjectId'] as String?,
    );
  }

  RecurringEvent _recurringFromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data();
    final start = (data['startMinutes'] as int?) ?? 0;
    return RecurringEvent(
      id: d.id,
      title: (data['title'] as String?) ?? '',
      weekday: (data['weekday'] as int?) ?? 1,
      startMinutes: start,
      endMinutes: data['endMinutes'] as int?,
      location: data['location'] as String?,
      subjectId: data['subjectId'] as String?,
    );
  }

  AppEvent _recurringAsAppEvent(RecurringEvent r, String key) {
    return AppEvent(
      id: 'recur_${r.id}',
      title: r.title,
      dayKey: key,
      startMinutes: r.startMinutes,
      endMinutes: r.endMinutes,
      location: r.location,
      subjectId: r.subjectId,
      isRecurring: true,
    );
  }

  Stream<List<AppEvent>> streamEventsForDay(DateTime day) {
    final key = dayKey(day);
    return _col
        .where('dayKey', isEqualTo: key)
        .orderBy('startMinutes', descending: false)
        .snapshots()
        .map((snap) {
          return snap.docs
              .map((d) => _oneOffFromDoc(d, fallbackDayKey: key))
              .toList();
        });
  }

  Stream<List<RecurringEvent>> streamRecurringEvents() {
    return _recurringCol.snapshots().map((snap) {
      final list = snap.docs.map(_recurringFromDoc).toList();
      list.sort((a, b) {
        final w = a.weekday.compareTo(b.weekday);
        return w != 0 ? w : a.startMinutes.compareTo(b.startMinutes);
      });
      return list;
    });
  }

  /// Event counts per dayKey for a calendar month (one-offs + recurring weekdays).
  Stream<Map<String, int>> streamMonthEventCounts(DateTime month) {
    return streamMonthEventSubjectIds(month).map((map) {
      return map.map((key, ids) => MapEntry(key, ids.length));
    });
  }

  /// dayKey -> list of subjectIds (nullable means untagged) for bar colours
  Stream<Map<String, List<String?>>> streamMonthEventSubjectIds(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);
    final startKey = dayKey(start);
    final endKey = dayKey(end);
    final controller =
        StreamController<Map<String, List<String?>>>.broadcast();

    List<AppEvent> lastOneOff = [];
    List<RecurringEvent> lastRecurring = [];

    void emit() {
      final byDay = <String, List<String?>>{};
      for (final e in lastOneOff) {
        byDay.putIfAbsent(e.dayKey, () => []).add(e.subjectId);
      }
      for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
        final key = dayKey(d);
        for (final r in lastRecurring.where((r) => r.weekday == d.weekday)) {
          byDay.putIfAbsent(key, () => []).add(r.subjectId);
        }
      }
      if (!controller.isClosed) controller.add(byDay);
    }

    late final StreamSubscription sub1;
    late final StreamSubscription sub2;
    sub1 = _col
        .where('dayKey', isGreaterThanOrEqualTo: startKey)
        .where('dayKey', isLessThanOrEqualTo: endKey)
        .snapshots()
        .listen((snap) {
          lastOneOff = snap.docs.map(_oneOffFromDoc).toList();
          emit();
        }, onError: controller.addError);
    sub2 = streamRecurringEvents().listen(
      (events) {
        lastRecurring = events;
        emit();
      },
      onError: (_) {
        lastRecurring = [];
        emit();
      },
    );

    controller.onCancel = () {
      sub1.cancel();
      sub2.cancel();
    };

    return controller.stream;
  }

  /// All one-off and recurring events grouped across a seven-day week.
  Stream<Map<String, List<AppEvent>>> streamEventsForWeek(DateTime weekStart) {
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final end = start.add(const Duration(days: 6));
    final controller =
        StreamController<Map<String, List<AppEvent>>>.broadcast();

    List<AppEvent> lastOneOff = [];
    List<RecurringEvent> lastRecurring = [];

    void emit() {
      final grouped = <String, List<AppEvent>>{
        for (var i = 0; i < 7; i++)
          dayKey(start.add(Duration(days: i))): <AppEvent>[],
      };

      for (final event in lastOneOff) {
        grouped[event.dayKey]?.add(event);
      }
      for (var i = 0; i < 7; i++) {
        final date = start.add(Duration(days: i));
        final key = dayKey(date);
        grouped[key]!.addAll(
          lastRecurring
              .where((event) => event.weekday == date.weekday)
              .map((event) => _recurringAsAppEvent(event, key)),
        );
        grouped[key]!.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
      }

      if (!controller.isClosed) controller.add(grouped);
    }

    late final StreamSubscription oneOffSubscription;
    late final StreamSubscription recurringSubscription;
    oneOffSubscription = _col
        .where('dayKey', isGreaterThanOrEqualTo: dayKey(start))
        .where('dayKey', isLessThanOrEqualTo: dayKey(end))
        .snapshots()
        .listen((snapshot) {
          lastOneOff = snapshot.docs.map(_oneOffFromDoc).toList();
          emit();
        }, onError: controller.addError);
    recurringSubscription = streamRecurringEvents().listen(
      (events) {
        lastRecurring = events;
        emit();
      },
      onError: (_) {
        lastRecurring = [];
        emit();
      },
    );

    controller.onCancel = () {
      oneOffSubscription.cancel();
      recurringSubscription.cancel();
    };
    return controller.stream;
  }

  /// Returns a stream of events for a day, merging one-off events with recurring events for that weekday.
  Stream<List<AppEvent>> streamCombinedEventsForDay(DateTime day) {
    final key = dayKey(day);
    final weekday = day.weekday; // 1=Mon, 7=Sun
    final controller = StreamController<List<AppEvent>>.broadcast();

    List<AppEvent> lastOneOff = [];
    List<RecurringEvent> lastRecurring = [];

    void emit() {
      final recurringForDay = lastRecurring
          .where((r) => r.weekday == weekday)
          .map((r) => _recurringAsAppEvent(r, key));
      final combined = [...lastOneOff, ...recurringForDay]
        ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
      if (!controller.isClosed) controller.add(combined);
    }

    late final StreamSubscription sub1;
    late final StreamSubscription sub2;
    sub1 = streamEventsForDay(day).listen((events) {
      lastOneOff = events;
      emit();
    }, onError: controller.addError);
    sub2 = streamRecurringEvents().listen(
      (events) {
        lastRecurring = events;
        emit();
      },
      onError: (_) {
        // If recurring fails (e.g. rules), use empty - don't block the stream
        lastRecurring = [];
        emit();
      },
    );

    controller.onCancel = () {
      sub1.cancel();
      sub2.cancel();
    };

    return controller.stream;
  }

  Future<void> addEvent({
    required DateTime day,
    required String title,
    required TimeOfDay time,
    TimeOfDay? endTime,
    String? location,
    String? subjectId,
  }) async {
    final start = timeToMinutes(time);
    await _col.add({
      'title': title,
      'dayKey': dayKey(day),
      'startMinutes': start,
      'endMinutes': resolveEndMinutes(start, endTime != null ? timeToMinutes(endTime) : null),
      'location': location,
      'subjectId': subjectId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addRecurringEvent({
    required int weekday, // 1=Mon, 7=Sun
    required String title,
    required TimeOfDay time,
    TimeOfDay? endTime,
    String? location,
    String? subjectId,
  }) async {
    final start = timeToMinutes(time);
    await _recurringCol.add({
      'title': title,
      'weekday': weekday,
      'startMinutes': start,
      'endMinutes': resolveEndMinutes(start, endTime != null ? timeToMinutes(endTime) : null),
      'location': location,
      'subjectId': subjectId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addRecurringEventsBatch(
    List<
            ({
              int weekday,
              String title,
              TimeOfDay time,
              TimeOfDay? endTime,
              String? location,
              String? subjectId
            })>
        items,
  ) async {
    if (items.isEmpty) return;
    var batch = _db.batch();
    var ops = 0;
    for (final item in items) {
      final start = timeToMinutes(item.time);
      final ref = _recurringCol.doc();
      batch.set(ref, {
        'title': item.title,
        'weekday': item.weekday,
        'startMinutes': start,
        'endMinutes': resolveEndMinutes(
          start,
          item.endTime != null ? timeToMinutes(item.endTime!) : null,
        ),
        'location': item.location,
        'subjectId': item.subjectId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      ops++;
      if (ops >= 400) {
        await batch.commit();
        batch = _db.batch();
        ops = 0;
      }
    }
    if (ops > 0) await batch.commit();
  }

  Future<void> updateEvent({
    required String id,
    required DateTime day,
    required String title,
    required TimeOfDay time,
    TimeOfDay? endTime,
    String? location,
    String? subjectId,
  }) async {
    final start = timeToMinutes(time);
    await _col.doc(id).update({
      'title': title,
      'dayKey': dayKey(day),
      'startMinutes': start,
      'endMinutes': resolveEndMinutes(start, endTime != null ? timeToMinutes(endTime) : null),
      'location': location,
      'subjectId': subjectId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateRecurringEvent({
    required String id,
    required int weekday,
    required String title,
    required TimeOfDay time,
    TimeOfDay? endTime,
    String? location,
    String? subjectId,
  }) async {
    final start = timeToMinutes(time);
    await _recurringCol.doc(id).update({
      'title': title,
      'weekday': weekday,
      'startMinutes': start,
      'endMinutes': resolveEndMinutes(start, endTime != null ? timeToMinutes(endTime) : null),
      'location': location,
      'subjectId': subjectId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateEventOrRecurring({
    required AppEvent event,
    required DateTime day,
    required String title,
    required TimeOfDay time,
    TimeOfDay? endTime,
    String? location,
    String? subjectId,
  }) async {
    if (event.isRecurring || event.id.startsWith('recur_')) {
      final rawId =
          event.id.startsWith('recur_') ? event.id.substring(6) : event.id;
      await updateRecurringEvent(
        id: rawId,
        weekday: day.weekday,
        title: title,
        time: time,
        endTime: endTime,
        location: location,
        subjectId: subjectId,
      );
    } else {
      await updateEvent(
        id: event.id,
        day: day,
        title: title,
        time: time,
        endTime: endTime,
        location: location,
        subjectId: subjectId,
      );
    }
  }

  Future<void> deleteEvent(String id) async {
    await _col.doc(id).delete();
  }

  Future<void> deleteRecurringEvent(String id) async {
    await _recurringCol.doc(id).delete();
  }

  /// Use for events with id starting with 'recur_'
  Future<void> deleteEventOrRecurring(String id) async {
    if (id.startsWith('recur_')) {
      await deleteRecurringEvent(id.substring(6));
    } else {
      await deleteEvent(id);
    }
  }
}
