import 'package:cloud_firestore/cloud_firestore.dart';

class TicketService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ** TICKET MANAGEMENT **

  // Fetch tickets based on user role
  Future<List<Map<String, dynamic>>> fetchTickets(String userId, String role, String department) async {
    List<Map<String, dynamic>> tickets = [];

    if (role == 'admin' || role == 'support') {
      // Admin can view all tickets
      QuerySnapshot ticketSnapshot = await _firestore.collection('tickets').get();
      tickets = ticketSnapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    } else if (role == 'department_head' ) {
      // Department head can view tickets in their department
      QuerySnapshot ticketSnapshot = await _firestore.collection('tickets').where('department', isEqualTo: department).get();
      tickets = ticketSnapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    } else if (role == 'member') {
      // Users can only view tickets assigned to them
      QuerySnapshot ticketSnapshot = await _firestore.collection('tickets').where('assignedTo', isEqualTo: userId).get();
      tickets = ticketSnapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    }

    return tickets;
  }

  // Create a new ticket
  Future<void> createTicket(Map<String, dynamic> ticketData) async {
    final newTicketId = await generateTicketID(); // Generate new ticket ID
    final ticketWithID = {
      ...ticketData,
      'ticketId': newTicketId, // Add the generated ID to ticket data
    };
    await _firestore.collection('tickets').doc(newTicketId).set(ticketWithID);
  }

  // Route a ticket to the support department
  Future<void> routeTicketToSupport(String ticketId) async {
    await _firestore.collection('tickets').doc(ticketId).update({
      'department': 'Support',
    });
  }

  // Batch update tickets with new keys and updated data
  Future<void> batchUpdateTickets(Map<String, String> keyMap, Map<String, dynamic> updatedData) async {
    final batch = _firestore.batch();

    for (var entry in keyMap.entries) {
      String oldKey = entry.key;
      String newKey = entry.value;

      // Reference to the old document
      final oldTicketDoc = _firestore.collection('tickets').doc(oldKey);

      // Reference to the new document
      final newTicketDoc = _firestore.collection('tickets').doc(newKey);

      // Set the data to the new document
      batch.set(newTicketDoc, updatedData);

      // Delete the old document
      batch.delete(oldTicketDoc);
    }

    // Commit the batch
    await batch.commit();
  }

  // Transactional update for tickets with new keys and updated data
  Future<void> transactionUpdateTickets(Map<String, String> keyMap, Map<String, dynamic> updatedData) async {
    await _firestore.runTransaction((transaction) async {
      for (var entry in keyMap.entries) {
        String oldKey = entry.key;
        String newKey = entry.value;

        // Reference to the old document
        final oldTicketDoc = _firestore.collection('tickets').doc(oldKey);

        // Get the old document data
        final oldTicketSnapshot = await transaction.get(oldTicketDoc);
        if (oldTicketSnapshot.exists) {
          // Set the data to the new document
          final newTicketDoc = _firestore.collection('tickets').doc(newKey);
          transaction.set(newTicketDoc, updatedData);

          // Delete the old document
          transaction.delete(oldTicketDoc);
        }
      }
    });
  }

  // Update ticket keys while preserving data
  Future<void> updateTicketKeys(Map<String, String> keyMap) async {
    final batch = _firestore.batch();

    for (var entry in keyMap.entries) {
      String oldKey = entry.key;
      String newKey = entry.value;

      final oldTicketDoc = _firestore.collection('tickets').doc(oldKey);
      final newTicketDoc = _firestore.collection('tickets').doc(newKey);

      // Get the old document data
      final oldTicketSnapshot = await oldTicketDoc.get();
      if (oldTicketSnapshot.exists) {
        // Set the data to the new document
        batch.set(newTicketDoc, oldTicketSnapshot.data()!);

        // Delete the old document
        batch.delete(oldTicketDoc);
      }
    }

    // Commit the batch
    await batch.commit();
  }

  // ** USER MANAGEMENT **

  // Create a new user with auto-generated user ID
  Future<void> createUser(String name, String email) async {
    try {
      // Generate a new user ID
      String userId = await generateUserID();

      // Create a new user document in Firestore
      await _firestore.collection('users').doc(userId).set({
        'userId': userId,
        'name': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('User created with ID: $userId');
    } catch (e) {
      print('Error creating user: $e');
    }
  }

  // Generate a unique user ID (e.g., USER-1001)
  Future<String> generateUserID() async {
    try {
      final snapshot = await _firestore.collection('users').orderBy('userId').get();

      int newId = snapshot.docs.isNotEmpty
          ? int.parse(snapshot.docs.last['userId'].split('-')[1]) + 1
          : 1001;

      final newUserId = 'USER-$newId';

      print('Generated User ID: $newUserId');
      return newUserId;
    } catch (e) {
      print('Error generating user ID: $e');
      throw e;
    }
  }

  // ** ROLE-BASED USER FILTERING **

  // Get POC members for DepartmentHead
  Stream<QuerySnapshot> getPOCForDepartmentHead(String department) {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'POC')  // Filter by POC
        .where('department', isEqualTo: department)  // Filter by department
        .snapshots();
  }

  // Get Department Heads for Admin/Support
  Stream<QuerySnapshot> getDepartmentHeadsForAdminSupport() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'DepartmentHead')  // Filter by Department Head
        .snapshots();
  }

  // ** TICKET ID GENERATION **

  // Generate a unique ticket ID (e.g., KO-1001)
  Future<String> generateTicketID() async {
    try {
      final snapshot = await _firestore.collection('tickets').orderBy('ticketId').get();

      int newId = snapshot.docs.isNotEmpty
          ? int.parse(snapshot.docs.last['ticketId'].split('-')[1]) + 1
          : 1001;

      final newTicketId = 'KO-$newId';

      print('Generated Ticket ID: $newTicketId');
      return newTicketId;
    } catch (e) {
      print('Error generating ticket ID: $e');
      throw e;
    }
  }
}
