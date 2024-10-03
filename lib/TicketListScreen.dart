import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'TicketDetailScreen.dart';

class TicketListScreen extends StatefulWidget {
  @override
  _TicketListScreenState createState() => _TicketListScreenState();
}

class _TicketListScreenState extends State<TicketListScreen> {
  String userRole = '';
  String userDepartment = '';
  String userEmail = ''; // To store current user's email
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchUserDetails(); // Fetch user details to determine role, department, and email
  }

  @override
  void dispose() {
    _timer?.cancel(); // Cancel the timer when the widget is disposed
    super.dispose();
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
    if (userDepartment == 'Admin' || userDepartment == 'Support') {
      return FirebaseFirestore.instance.collection('tickets').snapshots();
    } else if (userRole == 'DepartmentHead') {
      return FirebaseFirestore.instance
          .collection('tickets')
          .where('department', isEqualTo: userDepartment)
          .snapshots();
    } else {
      return FirebaseFirestore.instance
          .collection('tickets')
          .where('assignedTo', isEqualTo: userEmail)
          .snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('My Tickets')),
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

          // List to store tickets and their remaining time
          List<Map<String, dynamic>> ticketsWithRemainingTime = [];

          // Loop through each ticket and calculate remaining time
          for (var ticketDoc in tickets) {
            final ticket = ticketDoc.data() as Map<String, dynamic>;

            // **Check if timeline_start and timeline_duration exist and are not null**
            if (ticket['timeline_start'] != null && ticket['timeline_duration'] != null) {
              // **Convert the timeline_start to a DateTime using .toDate()**
              final Timestamp timelineStartTimestamp = ticket['timeline_start'];
              final DateTime timelineStart = timelineStartTimestamp.toDate();
              final int timelineDuration = ticket['timeline_duration']; // Total time in seconds

              // **Calculate the remaining time dynamically**
              final int remainingTime = _getUpdatedRemainingTime(timelineStart, timelineDuration);

              // Add the ticket data and remaining time to the list
              ticketsWithRemainingTime.add({
                'ticket': ticket,
                'ticketId': ticketDoc.id,
                'remainingTime': remainingTime,
                'timelineDuration': timelineDuration,
              });
            }
          }

          // Sort tickets based on remaining time (ascending order)
          ticketsWithRemainingTime.sort((a, b) => a['remainingTime'].compareTo(b['remainingTime']));

          return ListView.builder(
            itemCount: ticketsWithRemainingTime.length,
            itemBuilder: (context, index) {
              final ticketData = ticketsWithRemainingTime[index];
              final ticket = ticketData['ticket'];
              final int timelineDuration = ticketData['timelineDuration'];

              return StatefulBuilder(
                builder: (context, setState) {
                  int remainingTime = ticketData['remainingTime'];

                  // Start a periodic timer to update the remaining time
                  Timer.periodic(Duration(seconds: 1), (timer) {
                    setState(() {
                      if (remainingTime > 0) {
                        remainingTime--; // Decrement the remaining time every second
                      } else {
                        timer.cancel(); // Stop the timer when the time reaches zero
                      }
                    });
                  });

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
                          Text('Ticket ID: ${ticketData['ticketId']}'),
                          _buildTimelineStatus(remainingTime, timelineDuration),
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
                            builder: (context) =>
                                TicketDetailScreen(ticketId: ticketData['ticketId']),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }






  // Start a Timer to update the remaining time every second
  void _startTimer(String ticketId, int remainingTime) {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (remainingTime > 0) {
        setState(() {
          remainingTime--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  // Function to calculate the remaining time by subtracting the elapsed time from the total timeline duration
  int _getUpdatedRemainingTime(DateTime timelineStart, int timelineDuration) {
    final DateTime now = DateTime.now();
    final int elapsedTime = now.difference(timelineStart).inSeconds;
    return (timelineDuration - elapsedTime).clamp(0, timelineDuration); // Prevent negative values
  }

  // Widget to build the timeline status UI (display countdown)
  Widget _buildTimelineStatus(int remainingTime, int totalTime) {
    // Calculate the percentage of remaining time
    double timeFraction = remainingTime / totalTime;

// If time is up (remainingTime is zero or negative), show alert icon
    if (remainingTime <= 0) {
      return Row(
        children: [
          Icon(Icons.warning, color: Colors.red), // Alert icon
          SizedBox(width: 8),
          Text(
            'Time is up!',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
        ],
      );
    }

    Color timelineColor;

    if (timeFraction > 0.5) {
      timelineColor = Colors.green; // More than 50% of the time left
    } else if (timeFraction > 0.25) {
      timelineColor = Colors.yellow; // Between 25% and 50% of the time left
    } else {
      timelineColor = Colors.red; // Less than 25% of the time left
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Time remaining: ${remainingTime ~/ 3600}h ${(remainingTime % 3600) ~/ 60}m',
          style: TextStyle(color: timelineColor, fontWeight: FontWeight.bold),
        ),
        LinearProgressIndicator(
          value: remainingTime.isNegative
              ? 0.0 // If time has passed, show an empty bar
              : (remainingTime / totalTime).clamp(0.0, 1.0), // Progress bar based on the remaining time
          color: timelineColor,
          backgroundColor: Colors.grey[200],
        ),
      ],
    );
  }

}
