import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Import this for date formatting
import 'TicketDetailScreen.dart';

class TicketStatusScreen extends StatefulWidget {
  final String status; // Add status parameter to filter tickets

  TicketStatusScreen({required this.status}); // Pass status when navigating to this screen

  @override
  _TicketStatusScreenState createState() => _TicketStatusScreenState();
}

class _TicketStatusScreenState extends State<TicketStatusScreen> {
  String userRole = '';
  String userDepartment = '';
  String userEmail = ''; // To store current user's email
  String? _selectedDepartment; // For department filter dropdown

  // List of predefined departments
  final List<String> _departments = [
    'Marketing',
    'Development',
    'Sales',
    'Support',
    'BA',
    'Accounts',
    'Outbound',
    'Dispatch',
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserDetails(); // Fetch user details to determine role, department, and email
  }

  Future<void> _fetchUserDetails() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.email).get();
        if (userDoc.exists) {
          setState(() {
            userRole = userDoc.data()?['role'] ?? '';
            userDepartment = userDoc.data()?['department'] ?? '';
            userEmail = user.email ?? '';
            print('User Role: $userRole');
            print('User Department: $userDepartment');
          });
        } else {
          print('User document does not exist');
        }
      } else {
        print('No user is currently logged in');
      }
    } catch (e) {
      print('Error fetching user details: $e');
    }
  }

  Stream<QuerySnapshot> _getTicketsStream() {
    print('Current User Role: $userRole');
    print('Current User Department: $userDepartment');
    print('Current User Email: $userEmail');

    if (userDepartment == 'Admin' || userDepartment == 'Support') {
      // Admin and Support can see all tickets with the selected status
      Query query = FirebaseFirestore.instance
          .collection('tickets')
          .where('status', isEqualTo: widget.status); // Filter by the passed status

      if (_selectedDepartment != null && _selectedDepartment!.isNotEmpty) {
        query = query.where('department', isEqualTo: _selectedDepartment); // Filter by department
      }
      return query.snapshots();
    } else if (userRole == 'DepartmentHead') {
      // DepartmentHead can see only their department's tickets with the selected status
      return FirebaseFirestore.instance
          .collection('tickets')
          .where('department', isEqualTo: userDepartment)
          .where('status', isEqualTo: widget.status) // Filter by the passed status
          .snapshots();
    } else {
      // Members can only see tickets assigned to them with the selected status
      return FirebaseFirestore.instance
          .collection('tickets')
          .where('assignedTo', isEqualTo: userEmail)
          .where('status', isEqualTo: widget.status) // Filter by the passed status
          .snapshots();
    }
  }

  // Function to format the timestamp into a readable string
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp != null) {
      DateTime dateTime = timestamp.toDate();
      return DateFormat('yyyy-MM-dd – HH:mm').format(dateTime);
    }
    return 'Unknown time'; // Return this if timestamp is null
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.status} Tickets'),
        backgroundColor: Colors.white54,
        actions: [
          // Show filter icon only for Admin and Support roles
          if (userDepartment == 'Admin' || userDepartment == 'Support')
            IconButton(
              icon: Icon(Icons.filter_list),
              onPressed: () {
                // Show department filter dropdown in a modal dialog
                _showFilterDialog(context);
              },
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getTicketsStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          final tickets = snapshot.data!.docs;
          if (tickets.isEmpty) {
            return Center(child: Text('No tickets available.'));
          }
          return ListView.builder(
            itemCount: tickets.length,
            itemBuilder: (context, index) {
              final ticket = tickets[index].data() as Map<String, dynamic>;

              // Ensure the 'date_created' field exists and is not null
              final Timestamp? ticketTimestamp = ticket['date_created'] as Timestamp?;
              final String formattedDate = _formatTimestamp(ticketTimestamp);

              return Card(
                elevation: 2,
                margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: ListTile(
                  leading: Icon(Icons.receipt, color: Colors.teal),
                  title: Text(ticket['subject'], style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Department: ${ticket['department']}'),
                      Text('Ticket ID: ${tickets[index].id}'),
                      Text(
                        'Created At: $formattedDate', // Display formatted date
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  trailing: Container(
                    padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    decoration: BoxDecoration(
                      color: ticket['status'] == 'Open' ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      ticket['status'],
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TicketDetailScreen(ticketId: tickets[index].id),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Method to show department filter dialog with predefined departments
  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Filter by Department'),
          content: DropdownButton<String>(
            value: _selectedDepartment,
            isExpanded: true,
            hint: Text('Select Department'),
            items: _departments.map((department) {
              return DropdownMenuItem<String>(
                value: department,
                child: Text(department),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedDepartment = value;
              });
              Navigator.pop(context); // Close the dialog after selection
            },
          ),
        );
      },
    );
  }
}
