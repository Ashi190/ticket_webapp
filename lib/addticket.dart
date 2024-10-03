import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> addTicket(String title, String description) async {
  try {
    final firestore = FirebaseFirestore.instance;
    await firestore.collection('tickets').add({
      'title': title,
      'description': description,
      'created_at': Timestamp.now(),
    });
  } catch (e) {
    print("Error adding ticket: $e");
  }
}
