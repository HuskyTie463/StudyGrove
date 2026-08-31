import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../utils/datetime_utils.dart';

class StudyTimeService extends ChangeNotifier {
  StudyTimeService(this.uid) {
    _loadGoal();
  }

  final String uid;
  final _db = FirebaseFirestore.instance;
  static const _goalPrefsKey = 'study_week_goal_hours';

  /// Weekly hours each subject ring fills toward. Defaults to 10.
  int weekGoalHours = 10;

  int get weekGoalMinutes => weekGoalHours * 60;

  Future<void> _loadGoal() async {
    final prefs = await SharedPreferences.getInstance();
    weekGoalHours = (prefs.getInt('${_goalPrefsKey}_$uid') ?? 10).clamp(1, 40);
    notifyListeners();
  }

  Future<void> setWeekGoalHours(int hours) async {
    weekGoalHours = hours.clamp(1, 40);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${_goalPrefsKey}_$uid', weekGoalHours);
    notifyListeners();
  }

  CollectionReference<Map<String, dynamic>> get _daily =>
      _db.collection('users').doc(uid).collection('study_daily');

  String? activeSubjectId;
  DateTime? activeStartedAt;
  Timer? _tick;

  bool get isLive => activeStartedAt != null && activeSubjectId != null;

  Duration get liveElapsed {
    final started = activeStartedAt;
    if (started == null) return Duration.zero;
    return DateTime.now().difference(started);
  }

  Stream<List<StudyDayTotal>> streamTotals() {
    return _daily.snapshots().map((snap) {
      return snap.docs.map((d) {
        final data = d.data();
        return StudyDayTotal(
          subjectId: (data['subjectId'] as String?) ?? '',
          dayKey: (data['dayKey'] as String?) ?? '',
          minutes: (data['minutes'] as num?)?.toInt() ?? 0,
        );
      }).toList();
    });
  }

  Future<void> addMinutes({
    required String subjectId,
    required int minutes,
    required String source,
  }) async {
    if (minutes <= 0 || subjectId.isEmpty) return;
    final key = dayKey(DateTime.now());
    await _daily.doc('${key}_$subjectId').set({
      'subjectId': subjectId,
      'dayKey': key,
      'minutes': FieldValue.increment(minutes),
      'lastSource': source,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> startLive(String subjectId) async {
    if (subjectId.isEmpty) return;
    if (activeSubjectId == subjectId && activeStartedAt != null) return;
    await stopLive();
    activeSubjectId = subjectId;
    activeStartedAt = DateTime.now();
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> stopLive() async {
    final started = activeStartedAt;
    final subject = activeSubjectId;
    _tick?.cancel();
    _tick = null;
    activeStartedAt = null;
    activeSubjectId = null;
    if (started != null && subject != null) {
      final secs = DateTime.now().difference(started).inSeconds;
      final mins = (secs / 60).round();
      if (mins >= 1) {
        await addMinutes(subjectId: subject, minutes: mins, source: 'live');
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }
}

String formatStudyMinutes(int minutes) {
  if (minutes < 60) return '${minutes}m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}
