import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../utils/datetime_utils.dart';

class StudyTimeService extends ChangeNotifier with WidgetsBindingObserver {
  StudyTimeService(this.uid) {
    _loadGoal();
    WidgetsBinding.instance.addObserver(this);
    _recoverUnfinishedAssessmentSession();
  }

  final String uid;
  final _db = FirebaseFirestore.instance;
  static const _goalPrefsKey = 'study_week_goal_hours';
  static const _assessmentSessionPrefsKey = 'assessment_live_session';

  /// Fallback weekly hours when a subject has no goal of its own. Defaults to 10.
  int weekGoalHours = 10;

  int get weekGoalMinutes => weekGoalHours * 60;

  int goalHoursFor(Subject subject) =>
      resolveWeekGoalHours(subject.weekGoalHours, weekGoalHours);

  int goalMinutesFor(Subject subject) => goalHoursFor(subject) * 60;

  int combinedGoalHours(Iterable<Subject> subjects) =>
      combinedWeekGoalHours(
        subjects.map((s) => s.weekGoalHours),
        weekGoalHours,
      );

  int combinedGoalMinutes(Iterable<Subject> subjects) =>
      combinedGoalHours(subjects) * 60;

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
  String? activeAssessmentId;
  DateTime? activeStartedAt;
  Timer? _tick;
  bool _stopping = false;

  bool get isLive =>
      activeStartedAt != null &&
      activeSubjectId != null &&
      activeAssessmentId == null;

  bool get isAssessmentLive =>
      activeStartedAt != null && activeAssessmentId != null;

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
    if (activeAssessmentId == null &&
        activeSubjectId == subjectId &&
        activeStartedAt != null) {
      return;
    }
    await stopLive();
    activeSubjectId = subjectId;
    activeAssessmentId = null;
    activeStartedAt = DateTime.now();
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> startAssessmentSession({
    required String assessmentId,
    String? subjectId,
  }) async {
    if (assessmentId.isEmpty) return;
    if (activeAssessmentId == assessmentId && activeStartedAt != null) {
      return;
    }
    await stopLive();
    activeAssessmentId = assessmentId;
    activeSubjectId =
        (subjectId != null && subjectId.isNotEmpty) ? subjectId : null;
    activeStartedAt = DateTime.now();
    await _persistAssessmentSession();
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });
    notifyListeners();
  }

  /// Point a running assessment session at a newly picked subject.
  Future<void> retargetAssessmentSessionSubject(String? subjectId) async {
    if (activeAssessmentId == null) return;
    final next = (subjectId != null && subjectId.isNotEmpty) ? subjectId : null;
    if (activeSubjectId == next) return;
    activeSubjectId = next;
    await _persistAssessmentSession();
    notifyListeners();
  }

  Future<void> stopLive() async {
    if (activeAssessmentId != null) {
      await stopAssessmentSession();
      return;
    }
    final started = activeStartedAt;
    final subject = activeSubjectId;
    _tick?.cancel();
    _tick = null;
    activeStartedAt = null;
    activeSubjectId = null;
    if (started != null && subject != null) {
      final secs = DateTime.now().difference(started).inSeconds;
      final mins = subjectMinutesFromSession(secs);
      if (mins >= 1) {
        await addMinutes(subjectId: subject, minutes: mins, source: 'live');
      }
    }
    notifyListeners();
  }

  /// Stops the assessment timer, saves seconds on the assessment, and
  /// adds rounded minutes to that subject's Time log when a subject is linked.
  Future<int> stopAssessmentSession() async {
    if (_stopping) return 0;
    final started = activeStartedAt;
    final assessmentId = activeAssessmentId;
    if (assessmentId == null || started == null) return 0;
    _stopping = true;
    final subject = activeSubjectId;
    _tick?.cancel();
    _tick = null;
    activeStartedAt = null;
    activeSubjectId = null;
    activeAssessmentId = null;
    await _clearPersistedAssessmentSession();
    final secs = DateTime.now().difference(started).inSeconds;
    try {
      if (secs >= 1) {
        await _incrementAssessmentSpent(assessmentId, secs);
        final mins = subjectMinutesFromSession(secs);
        if (mins >= 1 && subject != null && subject.isNotEmpty) {
          await addMinutes(
            subjectId: subject,
            minutes: mins,
            source: 'assessment',
          );
        }
      }
      notifyListeners();
      return secs >= 1 ? secs : 0;
    } finally {
      _stopping = false;
    }
  }

  CollectionReference<Map<String, dynamic>> get _assessments =>
      _db.collection('users').doc(uid).collection('assessments');

  Future<void> _incrementAssessmentSpent(String assessmentId, int seconds) {
    return _assessments.doc(assessmentId).set({
      'spentSeconds': FieldValue.increment(seconds),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String get _sessionPrefsKey => '${_assessmentSessionPrefsKey}_$uid';

  Future<void> _persistAssessmentSession() async {
    final started = activeStartedAt;
    final assessmentId = activeAssessmentId;
    if (started == null || assessmentId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_sessionPrefsKey, [
      assessmentId,
      activeSubjectId ?? '',
      started.millisecondsSinceEpoch.toString(),
    ]);
  }

  Future<void> _clearPersistedAssessmentSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionPrefsKey);
  }

  Future<void> _recoverUnfinishedAssessmentSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_sessionPrefsKey);
      if (raw == null || raw.length < 3) return;
      await prefs.remove(_sessionPrefsKey);
      final assessmentId = raw[0];
      final subjectId = raw[1];
      final startedMs = int.tryParse(raw[2]);
      if (assessmentId.isEmpty || startedMs == null) return;
      final started = DateTime.fromMillisecondsSinceEpoch(startedMs);
      final secs = DateTime.now().difference(started).inSeconds;
      if (secs < 1) return;
      await _incrementAssessmentSpent(assessmentId, secs);
      final mins = subjectMinutesFromSession(secs);
      if (mins >= 1 && subjectId.isNotEmpty) {
        await addMinutes(
          subjectId: subjectId,
          minutes: mins,
          source: 'assessment',
        );
      }
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      if (isAssessmentLive) {
        unawaited(stopAssessmentSession());
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    super.dispose();
  }
}

int resolveWeekGoalHours(int? subjectHours, int fallbackHours) {
  return (subjectHours ?? fallbackHours).clamp(1, 40);
}

int combinedWeekGoalHours(Iterable<int?> subjectHours, int fallbackHours) {
  final list = subjectHours.toList();
  if (list.isEmpty) return fallbackHours.clamp(1, 40);
  return list.fold(0, (n, hours) => n + resolveWeekGoalHours(hours, fallbackHours));
}

int subjectMinutesFromSession(int seconds) {
  if (seconds <= 0) return 0;
  return (seconds / 60).round();
}

String formatElapsedClock(Duration elapsed) {
  final total = elapsed.inSeconds < 0 ? 0 : elapsed.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  if (h > 0) return '$h:$mm:$ss';
  return '$mm:$ss';
}

String formatAssessmentSpentLabel(int seconds) {
  if (seconds <= 0) return 'No time on this assessment yet';
  if (seconds < 60) return '${seconds}s on this assessment';
  return '${formatStudyMinutes(seconds ~/ 60)} on this assessment';
}

String formatStudyMinutes(int minutes) {
  if (minutes < 60) return '${minutes}m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

/// Storage stays in minutes; Time graph Y values are hours.
double studyMinutesToHours(int minutes) => minutes / 60.0;

/// Nice Y-axis ceiling so ticks land on 0.5 / 1 / 2h steps.
double studyTimeChartMaxHours(double maxHours, {double cap = 24}) {
  if (maxHours <= 0) return 1;
  if (maxHours <= 1) return 1;
  if (maxHours <= 2) return 2;
  if (maxHours <= 3) return 3;
  if (maxHours <= 4) return 4;
  if (maxHours <= 6) return 6;
  if (maxHours <= 8) return 8;
  if (maxHours <= 12) return 12;
  if (maxHours <= 16) return 16;
  if (maxHours <= 24) return 24;
  if (maxHours <= 32) return 32;
  if (maxHours <= 40) return 40;
  return maxHours.ceilToDouble().clamp(1, cap);
}

double studyTimeChartHourInterval(double maxY) {
  if (maxY <= 2) return 0.5;
  if (maxY <= 6) return 1;
  if (maxY <= 12) return 2;
  if (maxY <= 24) return 4;
  return 8;
}

/// Axis / tooltip labels: 0, 1h, 2h, 0.5h, 0.25h.
String formatStudyChartHours(double hours) {
  if (hours <= 0.001) return '0';
  final rounded = (hours * 100).round() / 100.0;
  if ((rounded - rounded.roundToDouble()).abs() < 0.001) {
    return '${rounded.round()}h';
  }
  final one = (rounded * 10).round() / 10.0;
  if ((rounded - one).abs() < 0.001) {
    return '${one.toStringAsFixed(1)}h';
  }
  return '${rounded.toStringAsFixed(2)}h';
}

/// Hours + leftover minutes typed on Time. Null when nothing valid to log.
int? parseManualStudyMinutes({required int hours, required int minutes}) {
  if (hours < 0 || minutes < 0) return null;
  final total = hours * 60 + minutes;
  if (total < 1) return null;
  return total.clamp(1, 24 * 60);
}

/// Logged minutes ÷ weekly goal. Unclamped so overtime can exceed 1.0.
double studyGoalRatio(int minutes, int targetMinutes) {
  if (targetMinutes <= 0 || minutes <= 0) return 0;
  return minutes / targetMinutes;
}

/// Sweep fractions (0–1) for each ring lap. Index 0 is the first, current-colour lap.
List<double> studyRingLapSweeps(double ratio, {int maxLaps = 4}) {
  if (ratio <= 0 || maxLaps <= 0) return const [];
  final laps = <double>[];
  var remaining = ratio;
  while (remaining > 0 && laps.length < maxLaps) {
    laps.add(remaining >= 1 ? 1.0 : remaining);
    remaining -= 1;
  }
  return laps;
}

/// Same hue, a shade darker on each extra lap. Never shifts toward red.
Color studyRingLapColor(Color base, int lap) {
  if (lap <= 0) return base;
  final factor = (1.0 - 0.18 * lap).clamp(0.38, 1.0);
  return Color.from(
    alpha: base.a,
    red: (base.r * factor).clamp(0.0, 1.0),
    green: (base.g * factor).clamp(0.0, 1.0),
    blue: (base.b * factor).clamp(0.0, 1.0),
  );
}
