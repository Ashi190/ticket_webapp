import 'package:cloud_firestore/cloud_firestore.dart';
import 'Ticket.dart';


Future<void> createTicket(Ticket ticket) async {
  try {
    CollectionReference tickets = FirebaseFirestore.instance.collection('tickets');
    await tickets.add(ticket.toFirestore());
    print("Ticket created successfully");
  } catch (e) {
    print("Error creating ticket: $e");
  }
}
