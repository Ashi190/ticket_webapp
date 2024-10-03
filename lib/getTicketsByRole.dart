import 'package:cloud_firestore/cloud_firestore.dart';
import 'Ticket.dart';


Future<List<Ticket>> getTicketsByRole(String userId) async {
  try {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    String role = userDoc['role'];
    String department = userDoc['department'];

    QuerySnapshot querySnapshot;

    if (role == 'admin') {
      querySnapshot = await FirebaseFirestore.instance.collection('tickets').get();
    } else if (role == 'department_head') {
      querySnapshot = await FirebaseFirestore.instance.collection('tickets').where('assignedDepartment', isEqualTo: department).get();
    } else if (role == 'support') {
      querySnapshot = await FirebaseFirestore.instance.collection('tickets').where('assignedDepartment', isEqualTo: 'Support').get();
    } else if (role == 'member') {
      querySnapshot = await FirebaseFirestore.instance.collection('tickets').where('raisedBy', isEqualTo: userId).get();
    } else {
      return [];
    }

    List<Ticket> tickets = querySnapshot.docs.map((doc) {
      return Ticket.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
    }).toList();

    return tickets;
  } catch (e) {
    print("Error fetching tickets: $e");
    return [];
  }
}
