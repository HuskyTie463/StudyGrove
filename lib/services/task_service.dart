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
      final tasks = snap.docs.map((d) {
        final data = d.data();
        return TaskItem(
          id: d.id,
          title: (data['title'] as String?) ?? '',
          done: (data['done'] as bool?) ?? false,
          urgency: TaskUrgencyX.fromStorage(data['urgency'] as String?),
          subjectId: data['subjectId'] as String?,
        );
      }).toList();
      tasks.sort((a, b) {
        if (a.done != b.done) return a.done ? 1 : -1;
        if (a.isUrgent != b.isUrgent) return a.isUrgent ? -1 : 1;
        return 0;
      });
      return tasks;
    });
  }

  Future<void> addTask(
    String title, {
    TaskUrgency urgency = TaskUrgency.normal,
    String? subjectId,
  }) async {
    await _col.add({
      'title': title,
      'done': false,
      'urgency': urgency.storage,
      if (subjectId != null && subjectId.isNotEmpty) 'subjectId': subjectId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleDone(String id, bool done) async {
    await _col.doc(id).update({'done': done});
  }

  Future<void> setUrgency(String id, TaskUrgency urgency) async {
    await _col.doc(id).update({'urgency': urgency.storage});
  }

  Future<void> deleteTask(String id) async {
    await _col.doc(id).delete();
  }
}
