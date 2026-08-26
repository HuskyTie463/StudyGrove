import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

class FrictionService {
  FrictionService(this.uid);
  final String uid;
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(uid).collection('friction_signals');

  DocumentReference<Map<String, dynamic>> get _prefs =>
      _db.collection('users').doc(uid);

  Future<void> log(FrictionReason reason, {String? sessionNote}) async {
    await _col.add({
      'reason': reason.storage,
      'sessionNote': sessionNote,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _prefs.set({
      'lastFriction': {
        'reason': reason.storage,
        'at': FieldValue.serverTimestamp(),
      },
    }, SetOptions(merge: true));
  }

  Stream<FrictionReason?> streamLastFriction() {
    return _prefs.snapshots().map((doc) {
      final raw = doc.data()?['lastFriction'] as Map<String, dynamic>?;
      if (raw == null) return null;
      return FrictionReasonX.fromStorage(raw['reason'] as String?);
    });
  }

  /// Adjust recommendation knobs without shame/streak punishment.
  StudyContextMode preferredMode(FrictionReason? reason) {
    return switch (reason) {
      FrictionReason.tooTired => StudyContextMode.lowEnergy,
      FrictionReason.travel => StudyContextMode.walking,
      FrictionReason.wrongEnvironment => StudyContextMode.walking,
      FrictionReason.tooLong => StudyContextMode.lowEnergy,
      FrictionReason.tooDifficult => StudyContextMode.balanced,
      FrictionReason.wrongTask => StudyContextMode.balanced,
      FrictionReason.somethingChanged => StudyContextMode.balanced,
      null => StudyContextMode.balanced,
    };
  }
}

class ProgressMetrics {
  const ProgressMetrics({
    required this.usefulGapSessions,
    required this.activeRecalls,
    required this.weakConceptsStrengthened,
    required this.minutesRecovered,
    required this.preparedSessionsAccepted,
    required this.reviewConsistencyDays,
    required this.readinessImprovedCount,
  });

  final int usefulGapSessions;
  final int activeRecalls;
  final int weakConceptsStrengthened;
  final int minutesRecovered;
  final int preparedSessionsAccepted;
  final int reviewConsistencyDays;
  final int readinessImprovedCount;
}

class ProgressMetricsService {
  ProgressMetricsService(this.uid);
  final String uid;
  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection('users').doc(uid).collection('metrics').doc('study');

  Future<void> increment({
    int gapSessions = 0,
    int recalls = 0,
    int strengthened = 0,
    int minutes = 0,
    int accepted = 0,
    int readinessImproved = 0,
  }) async {
    await _doc.set({
      if (gapSessions != 0)
        'usefulGapSessions': FieldValue.increment(gapSessions),
      if (recalls != 0) 'activeRecalls': FieldValue.increment(recalls),
      if (strengthened != 0)
        'weakConceptsStrengthened': FieldValue.increment(strengthened),
      if (minutes != 0) 'minutesRecovered': FieldValue.increment(minutes),
      if (accepted != 0)
        'preparedSessionsAccepted': FieldValue.increment(accepted),
      if (readinessImproved != 0)
        'readinessImprovedCount': FieldValue.increment(readinessImproved),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<ProgressMetrics> streamMetrics() {
    return _doc.snapshots().map((snap) {
      final d = snap.data() ?? {};
      return ProgressMetrics(
        usefulGapSessions: (d['usefulGapSessions'] as num?)?.toInt() ?? 0,
        activeRecalls: (d['activeRecalls'] as num?)?.toInt() ?? 0,
        weakConceptsStrengthened:
            (d['weakConceptsStrengthened'] as num?)?.toInt() ?? 0,
        minutesRecovered: (d['minutesRecovered'] as num?)?.toInt() ?? 0,
        preparedSessionsAccepted:
            (d['preparedSessionsAccepted'] as num?)?.toInt() ?? 0,
        reviewConsistencyDays:
            (d['reviewConsistencyDays'] as num?)?.toInt() ?? 0,
        readinessImprovedCount:
            (d['readinessImprovedCount'] as num?)?.toInt() ?? 0,
      );
    });
  }
}
