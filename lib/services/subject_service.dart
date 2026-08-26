import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

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
        );
      }).toList();
    });
  }

  Future<String> addSubject({
    required String name,
    String? code,
    required int colorValue,
  }) async {
    final doc = await _col.add({
      'name': name.trim(),
      'code': code?.trim().isEmpty == true ? null : code?.trim(),
      'colorValue': colorValue,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> updateSubject({
    required String id,
    required String name,
    String? code,
    required int colorValue,
  }) async {
    await _col.doc(id).update({
      'name': name.trim(),
      'code': code?.trim().isEmpty == true ? null : code?.trim(),
      'colorValue': colorValue,
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
