import 'package:cloud_firestore/cloud_firestore.dart';

import 'forwardTicket.dart';

Future<void> routeTicket(String ticketId) async {
  try {
    DocumentSnapshot ticketDoc = await FirebaseFirestore.instance.collection('tickets').doc(ticketId).get();
    String assignedDepartment = ticketDoc['assignedDepartment'];
    String status = ticketDoc['status'];

    if (assignedDepartment.isEmpty) {
      await forwardTicket(ticketId, 'Support');
    } else if (assignedDepartment != 'Support') {
      await forwardTicket(ticketId, assignedDepartment);
    }
  } catch (e) {
    print("Error routing ticket: $e");
  }
}
