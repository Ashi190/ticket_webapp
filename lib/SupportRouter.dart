import 'package:cloud_firestore/cloud_firestore.dart';

class SupportRouter {
  final String ticketId;

  SupportRouter({required this.ticketId});

  Future<void> _routeToSupport() async {
    try {
      // Update the department to 'Support'
      await FirebaseFirestore.instance.collection('tickets').doc(ticketId).update({
        'department': 'Support',
      });

      // Send a message to indicate that the ticket was routed to Support
      await FirebaseFirestore.instance.collection('tickets').doc(ticketId).collection('messages').add({
        'sender': 'System',
        'message': 'This ticket has been routed to the Support department.',
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('Ticket routed to Support successfully.');
    } catch (e) {
      print('Error routing to Support: $e');
    }
  }
}
