import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

class TaskService {
  TaskService(this.uid);

  final String uid;
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(uid).collection('tasks');

  Stream<List<TaskItem>> streamTasks() {
    return _col.orderBy('createdAt', descending: false).snapshots().map((snap) {
      return snap.docs.map((d) {
        final data = d.data();
        return TaskItem(
          id: d.id,
          title: (data['title'] as String?) ?? '',
          done: (data['done'] as bool?) ?? false,
        );
      }).toList();
    });
  }

  Future<void> addTask(String title) async {
    await _col.add({
      'title': title,
      'done': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleDone(String id, bool done) async {
    await _col.doc(id).update({'done': done});
  }

  Future<void> deleteTask(String id) async {
    await _col.doc(id).delete();
  }
}