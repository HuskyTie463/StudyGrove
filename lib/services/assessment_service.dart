import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

class AssessmentService {
  AssessmentService(this.uid);

  final String uid;
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(uid).collection('assessments');

  Assessment _fromDoc(String id, Map<String, dynamic> data) {
    final due = (data['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now();

    final rawSubs = (data['subtasks'] as List?) ?? const [];
    final subs = rawSubs.map((x) {
      final m = Map<String, dynamic>.from(x as Map);
      return AssessmentSubtask(
        title: (m['title'] as String?) ?? '',
        done: (m['done'] as bool?) ?? false,
      );
    }).toList();

    final rawTopics = (data['linkedTopicIds'] as List?) ?? const [];
    final rawLinks = (data['fileLinks'] as List?) ?? const [];

    double? weight;
    final rawWeight = data['weightPercent'];
    if (rawWeight is num) weight = rawWeight.toDouble();

    int? prep;
    final rawPrep = data['estimatedPrepMinutes'];
    if (rawPrep is num) prep = rawPrep.round();

    double? confidence;
    final rawConf = data['confidence'];
    if (rawConf is num) {
      final v = rawConf.toDouble();
      // Unset unreliable out-of-range values rather than invent.
      if (v >= 0 && v <= 1) confidence = v;
    }

    return Assessment(
      id: id,
      title: (data['title'] as String?) ?? '',
      course: (data['course'] as String?) ?? '',
      dueDate: due,
      subtasks: subs,
      subjectId: data['subjectId'] as String?,
      type: AssessmentTypeX.fromStorage(data['type'] as String?),
      weightPercent: weight,
      estimatedPrepMinutes: prep,
      confidence: confidence,
      linkedTopicIds: rawTopics.map((e) => e.toString()).toList(),
      notes: data['notes'] as String?,
      fileLinks: rawLinks.map((e) => e.toString()).toList(),
      completed: (data['completed'] as bool?) ?? false,
      archived: (data['archived'] as bool?) ?? false,
      resultReflection: data['resultReflection'] as String?,
      timeZoneId: data['timeZoneId'] as String?,
    );
  }

  Stream<List<Assessment>> streamAssessments() {
    return _col.orderBy('dueDate', descending: false).snapshots().map((snap) {
      return snap.docs.map((d) => _fromDoc(d.id, d.data())).toList();
    });
  }

  Stream<Assessment?> streamAssessment(String id) {
    return _col.doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return _fromDoc(doc.id, doc.data()!);
    });
  }

  Future<void> addAssessment({
    required String course,
    required String title,
    required DateTime dueDate,
    String? subjectId,
    AssessmentType type = AssessmentType.other,
    double? weightPercent,
    int? estimatedPrepMinutes,
    String? timeZoneId,
  }) async {
    await _col.add({
      'course': course,
      'title': title,
      'dueDate': Timestamp.fromDate(dueDate),
      'subjectId': subjectId,
      'type': type.storage,
      if (weightPercent != null) 'weightPercent': weightPercent,
      if (estimatedPrepMinutes != null)
        'estimatedPrepMinutes': estimatedPrepMinutes,
      'timeZoneId': timeZoneId ?? DateTime.now().timeZoneName,
      'subtasks': <Map<String, dynamic>>[],
      'linkedTopicIds': <String>[],
      'fileLinks': <String>[],
      'completed': false,
      'archived': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateAssessment(Assessment a) async {
    await _col.doc(a.id).set({
      'course': a.course,
      'title': a.title,
      'dueDate': Timestamp.fromDate(a.dueDate),
      'subjectId': a.subjectId,
      'type': a.type.storage,
      'weightPercent': a.weightPercent,
      'estimatedPrepMinutes': a.estimatedPrepMinutes,
      'confidence': a.confidence,
      'linkedTopicIds': a.linkedTopicIds,
      'notes': a.notes,
      'fileLinks': a.fileLinks,
      'completed': a.completed,
      'archived': a.archived,
      'resultReflection': a.resultReflection,
      'timeZoneId': a.timeZoneId,
      'subtasks': a.subtasks.map((s) => s.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteAssessment(String id) async {
    await _col.doc(id).delete();
  }

  Future<void> completeAssessment(
    String id, {
    String? reflection,
    bool archive = true,
  }) async {
    await _col.doc(id).set({
      'completed': true,
      'archived': archive,
      if (reflection != null) 'resultReflection': reflection,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> addSubtask(String assessmentId, String subtaskTitle) async {
    final ref = _col.doc(assessmentId);
    final snap = await ref.get();
    final data = snap.data();
    if (data == null) return;

    final raw = (data['subtasks'] as List?) ?? [];
    final list = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    list.add({'title': subtaskTitle, 'done': false});
    await ref.update({'subtasks': list});
  }

  Future<void> toggleSubtask(
    String assessmentId,
    int index,
    bool newDone,
  ) async {
    final ref = _col.doc(assessmentId);
    final snap = await ref.get();
    final data = snap.data();
    if (data == null) return;

    final raw = (data['subtasks'] as List?) ?? [];
    if (index < 0 || index >= raw.length) return;

    final list = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    list[index]['done'] = newDone;

    await ref.update({'subtasks': list});
  }
}
