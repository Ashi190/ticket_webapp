import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'TicketDetailScreen.dart';

class TicketListScreen extends StatefulWidget {
  @override
  _TicketListScreenState createState() => _TicketListScreenState();
}

class _TicketListScreenState extends State<TicketListScreen> {
  String userRole = '';
  String userDepartment = '';
  String userEmail = ''; // To store current user's email
  List<Timer?> _timers = []; // Store timers for each ticket
  Map<String, int> remainingTimes = {}; // Store remaining times for each ticket

  @override
  void initState() {
    super.initState();
    _fetchUserDetails(); // Fetch user details to determine role, department, and email
  }

  @override
  void dispose() {
    // Cancel all timers when the widget is disposed
    for (Timer? timer in _timers) {
      timer?.cancel();
    }
    super.dispose();
  }

  Future<void> _fetchUserDetails() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.email).get();
        if (userDoc.exists && mounted) { // Ensure mounted before setState
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



  Stream<List<DocumentSnapshot>> _getTicketsStream() {
    // If the user is Admin or Support, they can see all tickets
    if (userDepartment == 'Admin' || userDepartment == 'Support') {
      Stream<QuerySnapshot> allTicketsStream = FirebaseFirestore.instance
          .collection('tickets')
          .snapshots();

      return allTicketsStream.map((snapshot) {
        return snapshot.docs; // Directly return all tickets
      });
    }

    // For Department Heads, they can see:
    // 1. Tickets assigned to them
    // 2. Tickets they created
    // 3. Tickets of their department
    if (userRole == 'DepartmentHead') {
      // Stream for tickets assigned to the Department Head
      Stream<QuerySnapshot> assignedTicketsStream = FirebaseFirestore.instance
          .collection('tickets')
          .where('assignedTo', isEqualTo: userEmail)
          .snapshots();

      // Stream for tickets created by the Department Head (agent_email matches userEmail)
      Stream<QuerySnapshot> raisedTicketsStream = FirebaseFirestore.instance
          .collection('tickets')
          .where('agent_email', isEqualTo: userEmail)
          .snapshots();

      // Stream for tickets from the same department
      Stream<QuerySnapshot> departmentTicketsStream = FirebaseFirestore.instance
          .collection('tickets')
          .where('department', isEqualTo: userDepartment)
          .snapshots();

      // Combine all three streams and return
      return CombineLatestStream.list([assignedTicketsStream, raisedTicketsStream, departmentTicketsStream]).map((snapshots) {
        final List<DocumentSnapshot> combinedTickets = [];

        for (var snapshot in snapshots) {
          combinedTickets.addAll(snapshot.docs);
        }

        // Use a Set to remove duplicates
        return combinedTickets.toSet().toList();
      });
    }

    // For Members, show tickets assigned to them or created by them
    Stream<QuerySnapshot> assignedTicketsStream = FirebaseFirestore.instance
        .collection('tickets')
        .where('assignedTo', isEqualTo: userEmail)
        .snapshots();

    Stream<QuerySnapshot> raisedTicketsStream = FirebaseFirestore.instance
        .collection('tickets')
        .where('agent_email', isEqualTo: userEmail)
        .snapshots();

    return CombineLatestStream.list([assignedTicketsStream, raisedTicketsStream]).map((snapshots) {
      final List<DocumentSnapshot> combinedTickets = [];

      for (var snapshot in snapshots) {
        combinedTickets.addAll(snapshot.docs);
      }

      return combinedTickets.toSet().toList();
    });
  }





  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('My Tickets'),
        automaticallyImplyLeading: false, // This removes the back button
      ),
        body: StreamBuilder<List<DocumentSnapshot>>(
          stream: _getTicketsStream(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Center(child: CircularProgressIndicator());
            }

            final tickets = snapshot.data!; // This is a combined list of raised and assigned tickets

            if (tickets.isEmpty) {
              return Center(child: Text('No tickets available.'));
            }

            // List to store tickets and their remaining time
            List<Map<String, dynamic>> ticketsWithRemainingTime = [];

            for (var ticketDoc in tickets) {
              final ticket = ticketDoc.data() as Map<String, dynamic>;

              if (ticket['timeline_start'] != null && ticket['timeline_duration'] != null) {
                final Timestamp timelineStartTimestamp = ticket['timeline_start'];
                final DateTime timelineStart = timelineStartTimestamp.toDate();
                final int timelineDuration = ticket['timeline_duration'];

                final int remainingTime = _getUpdatedRemainingTime(timelineStart, timelineDuration);

                ticketsWithRemainingTime.add({
                  'ticket': ticket,
                  'ticketId': ticketDoc.id,
                  'remainingTime': remainingTime,
                  'timelineDuration': timelineDuration,
                  'color': _getTimelineColor(remainingTime, timelineDuration),
                });

                if (!remainingTimes.containsKey(ticketDoc.id)) {
                  remainingTimes[ticketDoc.id] = remainingTime;
                  _startTimer(ticketDoc.id, remainingTime);
                }
              }
            }

            ticketsWithRemainingTime.sort((a, b) {
              int colorWeightA = _getColorWeight(a['color']);
              int colorWeightB = _getColorWeight(b['color']);

              if (colorWeightA != colorWeightB) {
                return colorWeightA.compareTo(colorWeightB);
              } else {
                return a['remainingTime'].compareTo(b['remainingTime']);
              }
            });

            return ListView.builder(
              itemCount: ticketsWithRemainingTime.length,
              itemBuilder: (context, index) {
                final ticketData = ticketsWithRemainingTime[index];
                final ticket = ticketData['ticket'];
                final int remainingTime = remainingTimes[ticketData['ticketId']] ?? ticketData['remainingTime'];
                final int timelineDuration = ticketData['timelineDuration'];
                final Color color = ticketData['color'];

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
                          builder: (context) => TicketDetailScreen(ticketId: ticketData['ticketId']),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        )

    );
  }

  // Start a Timer to update the remaining time
  void _startTimer(String ticketId, int remainingTime) {
    Timer? timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (remainingTimes[ticketId]! > 0) {
            remainingTimes[ticketId] = remainingTimes[ticketId]! - 1;
          } else {
            timer.cancel();
          }
        });
      } else {
        timer.cancel();
      }
    });

    _timers.add(timer); // Store the timer for cleanup
  }

  // Function to calculate the remaining time by subtracting the elapsed time from the total timeline duration
  int _getUpdatedRemainingTime(DateTime timelineStart, int timelineDuration) {
    final DateTime now = DateTime.now();
    final int elapsedTime = now.difference(timelineStart).inSeconds;
    return (timelineDuration - elapsedTime).clamp(0, timelineDuration); // Prevent negative values
  }

  // Widget to build the timeline status UI
  Widget _buildTimelineStatus(int remainingTime, int totalTime) {
    double timeFraction = remainingTime / totalTime;

    if (remainingTime <= 0) {
      return Row(
        children: [
          Icon(Icons.warning, color: Colors.red),
          SizedBox(width: 8),
          Text(
            'Time is up!',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
        ],
      );
    }

    Color timelineColor = _getTimelineColor(remainingTime, totalTime);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Time remaining: ${remainingTime ~/ 3600}h ${(remainingTime % 3600) ~/ 60}m',
          style: TextStyle(color: timelineColor, fontWeight: FontWeight.bold),
        ),
        LinearProgressIndicator(
          value: remainingTime.isNegative
              ? 0.0
              : (remainingTime / totalTime).clamp(0.0, 1.0),
          color: timelineColor,
          backgroundColor: Colors.grey[200],
        ),
      ],
    );
  }

  // Function to get color based on the remaining time
  Color _getTimelineColor(int remainingTime, int totalTime) {
    double timeFraction = remainingTime / totalTime;
    if (timeFraction > 0.5) {
      return Colors.green; // More than 50% of the time left
    } else if (timeFraction > 0.25) {
      return Colors.orangeAccent; // Between 25% and 50% of the time left
    } else {
      return Colors.red; // Less than 25% of the time left
    }
  }

  // Helper function to get a weight based on color
  int _getColorWeight(Color color) {
    if (color == Colors.red) {
      return 1;
    } else if (color == Colors.yellow) {
      return 2;
    } else {
      return 3; // Green
    }
  }
}
