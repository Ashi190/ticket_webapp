import 'package:cloud_firestore/cloud_firestore.dart';

class Ticket {
  String id;
  String issueDescription;
  String assignedDepartment;
  String status;
  String raisedBy;
  String forwardedBy;
  String forwardedTo;
  String assignedTo; // User to whom the ticket is assigned
  Timestamp createdDate;  // Add createdDate field

  Ticket({
    required this.id,
    required this.issueDescription,
    required this.assignedDepartment,
    required this.status,
    required this.raisedBy,
    this.forwardedBy = '',
    this.forwardedTo = '',
    required this.assignedTo, // Add assignedTo in constructor
    required this.createdDate, // Initialize in constructor
  });

  // Factory method to create Ticket object from Firestore data
  factory Ticket.fromFirestore(Map<String, dynamic> data, String id) {
    return Ticket(
      id: id,
      issueDescription: data['issueDescription'] ?? '',
      assignedDepartment: data['assignedDepartment'] ?? '',
      status: data['status'] ?? 'Open',
      raisedBy: data['raisedBy'] ?? '',
      forwardedBy: data['forwardedBy'] ?? '',
      forwardedTo: data['forwardedTo'] ?? '',
      assignedTo: data['assigned_to'] ?? '', // Fetch from Firestore
      createdDate: data['date_created'] ?? Timestamp.now(), // Default to current time if not available
    );
  }

  // Convert Ticket object to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'issueDescription': issueDescription,
      'assignedDepartment': assignedDepartment,
      'status': status,
      'raisedBy': raisedBy,
      'forwardedBy': forwardedBy,
      'forwardedTo': forwardedTo,
     // 'assigned_to': assignedTo, // Include assigned_to in Firestore format
      'date_created': createdDate, // Add date_created field
    };
  }
}
