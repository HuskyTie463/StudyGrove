import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import 'assessment_attachment_store.dart';
import 'lecture_lab_service.dart';

class AssessmentService {
  AssessmentService(this.uid, {LectureLabService? lectureLab})
      : _lectureLab = lectureLab;

  final String uid;
  final LectureLabService? _lectureLab;
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
    final attachments = AssessmentAttachment.listFromAssessmentData(data);
    final rawLinks = (data['fileLinks'] as List?) ?? const [];
    final fileLinks = attachments
            .where((e) => e.isFile)
            .map((e) => e.absolutePath ?? e.relativePath ?? e.name)
            .toList();
    if (fileLinks.isEmpty) {
      fileLinks.addAll(rawLinks.map((e) => e.toString()));
    }

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
      fileLinks: fileLinks,
      attachments: attachments,
      completed: (data['completed'] as bool?) ?? false,
      archived: (data['archived'] as bool?) ?? false,
      resultReflection: data['resultReflection'] as String?,
      timeZoneId: data['timeZoneId'] as String?,
      spentSeconds: (data['spentSeconds'] as num?)?.toInt() ?? 0,
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

  Future<String> addAssessment({
    required String course,
    required String title,
    required DateTime dueDate,
    String? subjectId,
    AssessmentType type = AssessmentType.other,
    double? weightPercent,
    int? estimatedPrepMinutes,
    String? timeZoneId,
    List<AssessmentAttachment> attachments = const [],
  }) async {
    final ref = await _col.add({
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
      'fileLinks': _fileLinksOf(attachments),
      'attachments': attachments.map((e) => e.toMap()).toList(),
      'linkedLectureIds': _lectureIdsOf(attachments),
      'completed': false,
      'archived': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _syncLectureLinks(assessmentId: ref.id, attachments: attachments);
    return ref.id;
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
      'fileLinks': _fileLinksOf(a.attachments, fallback: a.fileLinks),
      'attachments': a.attachments.map((e) => e.toMap()).toList(),
      'linkedLectureIds': _lectureIdsOf(a.attachments),
      'completed': a.completed,
      'archived': a.archived,
      'resultReflection': a.resultReflection,
      'timeZoneId': a.timeZoneId,
      'subtasks': a.subtasks.map((s) => s.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> addSpentSeconds(String id, int seconds) async {
    if (seconds <= 0 || id.isEmpty) return;
    await _col.doc(id).set({
      'spentSeconds': FieldValue.increment(seconds),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteAssessment(String id) async {
    Assessment? existing;
    try {
      final snap = await _col.doc(id).get();
      final data = snap.data();
      if (data != null) existing = _fromDoc(id, data);
    } catch (_) {}
    await _col.doc(id).delete();
    if (existing != null) {
      await _syncLectureLinks(
        assessmentId: id,
        attachments: const [],
        previous: existing.attachments,
      );
    }
    await AssessmentAttachmentStore.deleteAssessmentFolder(
      uid: uid,
      assessmentId: id,
    );
  }

  Future<AssessmentAttachment> attachUploadedFile({
    required String assessmentId,
    required String filename,
    String? sourcePath,
    List<int>? bytes,
  }) async {
    final stored = await AssessmentAttachmentStore.saveUpload(
      uid: uid,
      assessmentId: assessmentId,
      filename: filename,
      sourcePath: sourcePath,
      bytes: bytes,
    );
    await _appendAttachments(assessmentId, [stored]);
    return stored;
  }

  Future<void> attachLinks(
    String assessmentId,
    List<AssessmentAttachment> links,
  ) async {
    if (links.isEmpty) return;
    await _appendAttachments(assessmentId, links);
  }

  Future<void> removeAttachment(
    String assessmentId,
    AssessmentAttachment att,
  ) async {
    final current = await _read(assessmentId);
    if (current == null) return;
    final next = current.attachments.where((e) => e.id != att.id).toList();
    await updateAssessment(current.copyWith(attachments: next));
    await _syncLectureLinks(
      assessmentId: assessmentId,
      attachments: next,
      previous: current.attachments,
    );
    await AssessmentAttachmentStore.deleteOwnedFile(
      assessmentId: assessmentId,
      att: att,
    );
  }

  Future<Assessment?> _read(String assessmentId) async {
    final snap = await _col.doc(assessmentId).get();
    final data = snap.data();
    if (!snap.exists || data == null) return null;
    return _fromDoc(assessmentId, data);
  }

  Future<void> _appendAttachments(
    String assessmentId,
    List<AssessmentAttachment> added,
  ) async {
    final current = await _read(assessmentId);
    if (current == null) return;
    final keys = current.attachments.map((e) => e.linkKey).toSet();
    final next = [...current.attachments];
    for (final att in added) {
      if (keys.add(att.linkKey)) next.add(att);
    }
    await updateAssessment(current.copyWith(attachments: next));
    await _syncLectureLinks(
      assessmentId: assessmentId,
      attachments: next,
      previous: current.attachments,
    );
  }

  static List<String> _fileLinksOf(
    List<AssessmentAttachment> attachments, {
    List<String>? fallback,
  }) {
    final links = attachments
        .where((e) => e.isFile)
        .map((e) => e.absolutePath ?? e.relativePath ?? e.name)
        .where((e) => e.trim().isNotEmpty)
        .toList();
    if (links.isNotEmpty) return links;
    return fallback ?? const [];
  }

  static List<String> _lectureIdsOf(List<AssessmentAttachment> attachments) {
    return attachments
        .where((e) => e.isLecture)
        .map((e) => e.lectureId)
        .whereType<String>()
        .where((e) => e.trim().isNotEmpty)
        .toList();
  }

  Future<void> _syncLectureLinks({
    required String assessmentId,
    required List<AssessmentAttachment> attachments,
    List<AssessmentAttachment>? previous,
  }) async {
    final lab = _lectureLab;
    if (lab == null) return;
    final next = _lectureIdsOf(attachments).toSet();
    final prev = previous == null
        ? <String>{}
        : _lectureIdsOf(previous).toSet();
    for (final id in next.difference(prev)) {
      await lab.linkAssessment(id, assessmentId);
    }
    for (final id in prev.difference(next)) {
      await lab.unlinkAssessment(id, assessmentId);
    }
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

  Future<void> restoreAssessment(String id) async {
    await _col.doc(id).set({
      'completed': false,
      'archived': false,
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
