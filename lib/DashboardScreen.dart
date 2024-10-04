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


  @override
  void initState() {
    super.initState();
    _fetchTicketCounts(); // Initially fetch all tickets
  }

  // Fetch ticket counts from Firestore for each status based on selected department
  Future<void> _fetchTicketCounts() async {
    setState(() {
      _isLoading = true;
    });

    // Firestore query
    Query query = FirebaseFirestore.instance.collection('tickets');

    // Filter by department if a specific department is selected
    if (_selectedDepartment != 'All') {
      query = query.where('department', isEqualTo: _selectedDepartment);
    }

    QuerySnapshot querySnapshot = await query.get();

    Map<String, int> ticketCounts = {
      'Open': 0,
      'Closed': 0,
      'Reassigned': 0,
      'Reassigned to Support': 0,
      'Under Progress': 0,
      'In Progress': 0,
    };

    for (var doc in querySnapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      String status = data['status'] ?? 'Unknown';
      if (ticketCounts.containsKey(status)) {
        ticketCounts[status] = ticketCounts[status]! + 1;
      }
    }

    setState(() {
      _ticketCounts = ticketCounts;
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
        actions: [

          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: () {
              _showDepartmentFilterDialog(context); // Show department dropdown
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
            _isLoading
                ? Center(child: CircularProgressIndicator())
                : Container(
              height: 180, // Reduced height for more compact cards
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _ticketStatuses.length, // Number of TicketCards based on the status list
                itemBuilder: (context, index) {
                  String status = _ticketStatuses[index];
                  int count = _ticketCounts[status] ?? 0; // Get the count for this status
                  return Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TicketStatusScreen(
                              status: _ticketStatuses[index], // Pass status to the next screen
                            ),
                          ),
                        );
                      },
                      child: TicketCard(
                        ticketTitle: _ticketStatuses[index], // Assigning status to title
                        ticketSubtitle: '$count tickets', // Show ticket count
                        status: _ticketStatuses[index], // Assigning status to ticket
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 30), // Space between ticket list and graph
          ],
        ),
      ),
    );
  }

  // Show a dialog with a dropdown to select the department filter
  void _showDepartmentFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Filter by Department'),
          content: DropdownButton<String>(
            value: _selectedDepartment,
            onChanged: (String? newValue) {
              setState(() {
                _selectedDepartment = newValue!;
              });
              _fetchTicketCounts(); // Fetch the tickets for the selected department
              Navigator.of(context).pop(); // Close the dialog
            },
            items: _departments.map((String department) {
              return DropdownMenuItem<String>(
                value: department,
                child: Text(department),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              child: Text('Close'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
          ],
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
