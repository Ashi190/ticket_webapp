import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; // For the graph
import 'package:cloud_firestore/cloud_firestore.dart'; // Firebase Firestore for ticket data
import 'package:intl/intl.dart';
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
  // Define the available filter options
  final List<String> _dateFilterOptions = [
    'Last 30 days',
    'Last 10 days',
    'Last Year',
    'Yesterday',
    'Today',
    'Last 15 days',
  ];

  // Variable to hold the selected filter option
  String _selectedFilter = 'Last 30 days';

  // List of possible ticket statuses
  final List<String> _ticketStatuses = [
    'Open',
    'Closed',
    'Assigned',
    'Unassigned',
    'Under Progress',
    'In Progress',
    'Due',
    'Overdue'
  ];

  // Store the ticket counts for each status
  Map<String, int> _ticketCounts = {
    'Open': 0,
    'Closed': 0,
    'Assigned': 0,
    'Unassigned': 0,
    'Under Progress': 0,
    'In Progress': 0,
    'Due': 0,
    'Overdue': 0,
  };

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTicketCounts();
  }

  // Fetch ticket counts from Firestore for each status
  Future<void> _fetchTicketCounts() async {
    setState(() {
      _isLoading = true;
    });

    QuerySnapshot querySnapshot = await FirebaseFirestore.instance.collection('tickets').get();

    Map<String, int> ticketCounts = {
      'Open': 0,
      'Closed': 0,
      'Assigned': 0,
      'Unassigned': 0,
      'Under Progress': 0,
      'In Progress': 0,
      'Due': 0,
      'Overdue': 0,
    };

    List<DateTime> dates = [];

    for (var doc in querySnapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      String status = data['status'] ?? 'Unknown';
      if (ticketCounts.containsKey(status)) {
        ticketCounts[status] = ticketCounts[status]! + 1;
      }

      // Assuming you have a 'timestamp' field in Firestore
      Timestamp timestamp = data['timestamp'] ?? Timestamp.now();
      dates.add(timestamp.toDate());
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
          IconButton(icon: Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dropdown for date filter
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                DropdownButton<String>(
                  value: _selectedFilter, // Currently selected filter
                  items: _dateFilterOptions.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _selectedFilter = newValue!;
                    });
                    _fetchTicketCounts(); // Fetch data for the new range
                  },
                ),
              ],
            ),
            SizedBox(height: 16),

            // Section 1: Tickets List
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

            // Section 2: Ticket Stats Graph
            Text(
              "Tickets Stats",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),

            // Show graph or loading spinner
            _isLoading
                ? Center(child: CircularProgressIndicator())
                : _buildTicketLineChart(),
          ],
        ),
      ),
    );
  }

  // Method to build the Line Chart for ticket stats
  Widget _buildTicketLineChart() {
    List<FlSpot> spots = [];
    List<DateTime> dates = [];
    int index = 0;

    // Simulate dates based on your data (in this case using the _ticketCounts map)
    _ticketCounts.forEach((status, count) {
      // Convert to double, ensuring valid count
      double validCount = count.isNaN ? 0.0 : count.toDouble();

      // Example: Calculate the date for the x-axis
      DateTime date = DateTime.now().subtract(Duration(days: index * 2)); // You can adjust this based on real data
      dates.add(date);

      // Adding to spots: the x-axis value is the index (as fl_chart needs numbers), y-axis is the ticket count
      spots.add(FlSpot(index.toDouble(), validCount));

      index++;
    });

    return AspectRatio(
      aspectRatio: 2.0,
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              colors: [Colors.blue],
              barWidth: 3,
              belowBarData: BarAreaData(
                show: true,
                colors: [Colors.blue.withOpacity(0.3)],
              ),
            ),
          ],
          titlesData: FlTitlesData(
            leftTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTextStyles: (context, value) =>
              const TextStyle(color: Colors.black87, fontSize: 12),
            ),
            bottomTitles: SideTitles(
              showTitles: true,
              getTitles: (value) {
                // Use the value as an index to retrieve the corresponding date
                if (value.toInt() >= 0 && value.toInt() < dates.length) {
                  DateTime date = dates[value.toInt()];
                  return DateFormat('MM/dd').format(date); // Format the date as MM/dd
                }
                return '';
              },
              getTextStyles: (context, value) =>
              const TextStyle(color: Colors.black87, fontSize: 10),
            ),
          ),
          gridData: FlGridData(show: true),
          borderData: FlBorderData(show: true),
        ),
      ),
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
      case 'Unassigned':
        return Colors.grey;
      case 'Under Progress':
        return Colors.blue;
      case 'Assigned':
        return Colors.purple;
      case 'Due':
        return Colors.teal;
      case 'Overdue':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }
}
