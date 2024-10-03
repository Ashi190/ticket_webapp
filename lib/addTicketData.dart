import 'package:cloud_firestore/cloud_firestore.dart';

void addTicketData() {
  FirebaseFirestore.instance.collection('tickets').doc('ticket123').set({
    "ticket_id": "ticket123",
    "current_department": "Technical", // Current department handling the ticket
    "status": "In Progress",  // Ticket status
    "message_thread": [
      {
        "sender": "Support",
        "recipient": "Technical",
        "message": "Issue forwarded to Technical department.",
        "timestamp": "2024-09-18T10:00:00Z"
      },
      {
        "sender": "Technical",
        "recipient": "Support",
        "message": "Issue not for Technical, forwarding back to Support.",
        "timestamp": "2024-09-18T12:00:00Z"
      }
    ],
    "history": ["Support", "Technical"] // Departments that have handled the ticket
  }).then((_) {
    print("Ticket added successfully!");
  }).catchError((error) {
    print("Failed to add ticket: $error");
  });
}
