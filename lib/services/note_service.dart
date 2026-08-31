import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

class NoteService {
  NoteService(this.uid);

  final String uid;
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(uid).collection('notes');

  Stream<List<NoteItem>> streamNotes() {
    return _col.orderBy('updatedAt', descending: true).snapshots().map((snap) {
      return snap.docs.map((d) {
        final data = d.data();
        return NoteItem(
          id: d.id,
          title: (data['title'] as String?) ?? '',
          body: (data['body'] as String?) ?? '',
          updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
          subjectId: data['subjectId'] as String?,
        );
      }).toList();
    });
  }

  Future<void> upsert({
    String? id,
    required String title,
    required String body,
    String? subjectId,
  }) async {
    final payload = {
      'title': title.trim(),
      'body': body.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (subjectId != null) 'subjectId': subjectId,
    };
    if (id == null) {
      await _col.add({
        ...payload,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return;
    }
    await _col.doc(id).set(payload, SetOptions(merge: true));
  }

  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}
