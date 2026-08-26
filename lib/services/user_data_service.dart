import 'package:cloud_firestore/cloud_firestore.dart';

class UserDataService {
  UserDataService(this.uid);

  final String uid;
  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _userDoc => _db.collection('users').doc(uid);

  Future<void> deleteAllUserData() async {
    // For your app: these are the collections we’ll clear.
    await _deleteCollection(_userDoc.collection('tasks'));
    await _deleteCollection(_userDoc.collection('events'));
    await _deleteCollection(_userDoc.collection('recurring_events'));
    await _deleteCollection(_userDoc.collection('subjects'));
    await _deleteCollection(_userDoc.collection('agenda_weeks'));
    await _deleteCollection(_userDoc.collection('assessments'));
    await _deleteCollection(_userDoc.collection('lectures'));
    await _deleteCollection(_userDoc.collection('review_topics'));
    await _deleteCollection(_userDoc.collection('friction_signals'));
    await _deleteCollection(_userDoc.collection('metrics'));

    // Optional: delete the user doc itself (only if you store profile data there)
    await _userDoc.delete().catchError((_) {});
  }

  Future<void> _deleteCollection(CollectionReference col) async {
    const batchSize = 250;
    while (true) {
      final snap = await col.limit(batchSize).get();
      if (snap.docs.isEmpty) break;

      final batch = _db.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
  }
}