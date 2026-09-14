import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import 'study_time_service.dart';

class SubjectService {
  SubjectService(this.uid);

  final String uid;
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(uid).collection('subjects');

  Stream<List<Subject>> streamSubjects() {
    return _col.orderBy('name').snapshots().map((snap) {
      return snap.docs.map((d) {
        final data = d.data();
        return Subject(
          id: d.id,
          name: (data['name'] as String?) ?? '',
          code: data['code'] as String?,
          colorValue: (data['colorValue'] as int?) ?? kSubjectColorPalette.first,
          kind: SubjectKind.fromStorage(data['kind'] as String?),
          weekGoalHours: (data['weekGoalHours'] as num?)?.toInt(),
          weekGoalMinutes: (data['weekGoalMinutes'] as num?)?.toInt(),
        );
      }).toList();
    });
  }

  Future<String> addSubject({
    required String name,
    String? code,
    required int colorValue,
    SubjectKind kind = SubjectKind.study,
    int? weekGoalHours,
  }) async {
    final payload = <String, dynamic>{
      'name': name.trim(),
      'code': code?.trim().isEmpty == true ? null : code?.trim(),
      'colorValue': colorValue,
      'kind': kind.name,
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (weekGoalHours != null) {
      payload['weekGoalHours'] = weekGoalHours.clamp(1, 40);
    }
    final doc = await _col.add(payload);
    return doc.id;
  }

  Future<void> updateSubject({
    required String id,
    required String name,
    String? code,
    required int colorValue,
    SubjectKind kind = SubjectKind.study,
  }) async {
    await _col.doc(id).update({
      'name': name.trim(),
      'code': code?.trim().isEmpty == true ? null : code?.trim(),
      'colorValue': colorValue,
      'kind': kind.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateWeekGoalHours({
    required String id,
    required int hours,
    int minutes = 0,
  }) async {
    final total = parseWeekGoalMinutes(hours: hours, minutes: minutes);
    if (total == null) return;
    await _col.doc(id).update({
      'weekGoalHours': (total ~/ 60).clamp(0, 40),
      'weekGoalMinutes': total,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteSubject(String id) async {
    await _col.doc(id).delete();
  }

  /// Match a free-text course/title hint to an existing subject.
  Subject? matchHint(List<Subject> subjects, String? hint) {
    if (hint == null || hint.trim().isEmpty) return null;
    final h = hint.trim().toLowerCase();
    for (final s in subjects) {
      final code = s.code?.trim().toLowerCase();
      if (code != null && code.isNotEmpty && (h == code || h.contains(code))) {
        return s;
      }
      if (s.name.trim().toLowerCase() == h) return s;
    }
    return null;
  }
}
