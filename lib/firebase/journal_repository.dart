import 'package:cloud_firestore/cloud_firestore.dart';

class JournalRepository {
  JournalRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<QuerySnapshot<Map<String, dynamic>>> watchEntries(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('journal_entries')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> addEntry({
    required String userId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }

    await _firestore.collection('users').doc(userId).collection('journal_entries').add({
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
