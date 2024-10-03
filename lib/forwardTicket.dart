import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> forwardTicket(String ticketId, String newDepartment) async {
  try {
    await FirebaseFirestore.instance.collection('tickets').doc(ticketId).update({
      'assignedDepartment': newDepartment,
      'status': 'Forwarded',
    });
    print("Ticket forwarded to $newDepartment");
  } catch (e) {
    print("Error forwarding ticket: $e");
  }
}
