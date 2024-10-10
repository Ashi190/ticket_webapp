import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Firebase Firestore for ticket data
import 'TicketStatusScreen.dart'; // Import the new screen

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // List of possible ticket statuses
  final List<String> _ticketStatuses = [
    'Open',
    'Closed',
    'Reassigned',
    'Reassigned to Support',
    'Under Progress',
    'In Progress',
  ];

  // List of departments based on your provided department codes
  final List<String> _departments = [
    'All',
    'Marketing',
    'Development',
    'Sales',
    'Support',
    'BA',
    'Accounts',
    'Outbound',
    'Dispatch'
  ];

  // Store the selected department
  String _selectedDepartment = 'All';

  // Store the ticket counts for each status
  Map<String, int> _ticketCounts = {
    'Open': 0,
    'Closed': 0,
    'Reassigned': 0,
    'Reassigned to Support': 0,
    'Under Progress': 0,
    'In Progress': 0,
  };

  bool _isLoading = true;
  String? _userDepartment; // This will store the user's department
  String? _userRole;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _fetchUserDetails();
    _fetchTicketCounts(); // Initially fetch all tickets
  }

  Future<void> _fetchUserDetails() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.email).get();
        if (userDoc.exists) {
          setState(() {
            _userRole = userDoc.data()?['role'] ?? '';
            _userDepartment = userDoc.data()?['department'] ?? '';
            _userEmail = user.email ?? '';
            print('User Role: $_userRole');
            print('User Department: $_userDepartment');
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
  // Fetch ticket counts from Firestore for each status based on user role and department
  Future<void> _fetchTicketCounts() async {
    setState(() {
      _isLoading = true;
    });

    Query query = FirebaseFirestore.instance.collection('tickets');

    QuerySnapshot querySnapshot = await query.get();

    // Initialize ticket counts for each status
    Map<String, int> ticketCounts = {
      'Open': 0,
      'Closed': 0,
      'Reassigned': 0,
      'Reassigned to Support': 0,
      'Under Progress': 0,
      'In Progress': 0,
    };

    // Count tickets by status
    for (var doc in querySnapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      String status = data['status'] ?? 'Unknown';
      String department = data['department'];
      if(_userDepartment == "Admin" || _userDepartment == "Support"){
        if (ticketCounts.containsKey(status)) {
          ticketCounts[status] = ticketCounts[status]! + 1;
        }
      }else{
        if (ticketCounts.containsKey(status)&& department == _userDepartment) {
          ticketCounts[status] = ticketCounts[status]! + 1;
        }
      }

    }

    setState(() {
      _ticketCounts = ticketCounts;
      print(ticketCounts);
      _isLoading = false;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Overview Dashboard",
          style: TextStyle(fontSize: 20),
        ),
        backgroundColor: Colors.white54,
        automaticallyImplyLeading: false, // This removes the back button
        actions: [
          if (_userDepartment == 'Admin' || _userDepartment == 'Support')
            IconButton(
              icon: Icon(Icons.filter_list),
              onPressed: () {
                _showFilterDialog(context);
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 16),
            Text(
              "Tickets List",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('tickets').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                // Initialize counts for each status
                Map<String, int> ticketCounts = {
                  'Open': 0,
                  'Closed': 0,
                  'Reassigned': 0,
                  'Reassigned to Support': 0,
                  'Under Progress': 0,
                  'In Progress': 0,
                };

                // Loop through each ticket and count the statuses
                snapshot.data!.docs.forEach((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  String status = data['status'] ?? 'Unknown';
                  String department = data['department'] ?? 'Unknown';

                  // Count based on user role and department
                  if (_userDepartment == "Admin" || _userDepartment == "Support") {
                    // Admin and Support can see all tickets
                    if (ticketCounts.containsKey(status)) {
                      ticketCounts[status] = ticketCounts[status]! + 1;
                    }
                  } else if (ticketCounts.containsKey(status) && department == _userDepartment) {
                    // Non-admin users only see tickets from their own department
                    ticketCounts[status] = ticketCounts[status]! + 1;
                  }
                });

                // Display the TicketCards with up-to-date counts
                return Container(
                  height: 180,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _ticketStatuses.length,
                    itemBuilder: (context, index) {
                      String status = _ticketStatuses[index];
                      int count = ticketCounts[status] ?? 0;

                      return Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TicketStatusScreen(
                                  status: _ticketStatuses[index],
                                ),
                              ),
                            );
                          },
                          child: TicketCard(
                            ticketTitle: _ticketStatuses[index],
                            ticketSubtitle: '$count tickets',
                            status: _ticketStatuses[index],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }


  // Method to show department filter dialog with predefined departments
  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Filter by Departments'),
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
                _selectedDepartment = value!;
              });
              _fetchTicketCounts(); // Update the counts based on the selected department
              Navigator.pop(context); // Close the dialog after selection
            },
          ),
        );
      },
    );
  }

}

// TicketCard widget (same as before)
class TicketCard extends StatelessWidget {
  final String ticketTitle;
  final String ticketSubtitle;
  final String status;

  TicketCard({
    required this.ticketTitle,
    required this.ticketSubtitle,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250, // Reduced width for better spacing and more compact cards
      margin: EdgeInsets.only(right: 8), // Reduced space between cards
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 14), // Padding adjusted inside card
      decoration: BoxDecoration(
        color: Colors.white, // Solid white background
        borderRadius: BorderRadius.circular(12), // More rounded corners
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8.0, // Softer shadow for a raised effect
            spreadRadius: 1.0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ticketTitle, // Displaying status as title
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16, // Slightly smaller font size for better spacing
              color: Colors.black87,
            ),
            overflow: TextOverflow.ellipsis, // Truncate long text
            maxLines: 1, // Limit to one line
          ),
          SizedBox(height: 8),
          Text(
            ticketSubtitle, // Showing count of tickets
            style: TextStyle(
              fontSize: 13, // Slightly smaller font size for subtitles
              color: Colors.grey[600],
            ),
            overflow: TextOverflow.ellipsis, // Truncate long text
            maxLines: 2, // Limit to two lines
          ),
          Spacer(), // Pushes the status at the bottom
          Container(
            padding: EdgeInsets.symmetric(vertical: 6, horizontal: 10), // Smaller padding for status
            decoration: BoxDecoration(
              color: statusColor(status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor(status),
                fontWeight: FontWeight.bold,
                fontSize: 13, // Slightly smaller font size for status text
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Method to define status color
  Color statusColor(String status) {
    switch (status) {
      case 'Open':
        return Colors.red;
      case 'In Progress':
        return Colors.orange;
      case 'Closed':
        return Colors.green;
      case 'Reassigned to Support':
        return Colors.grey;
      case 'Under Progress':
        return Colors.blue;
      case 'Reassigned':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
