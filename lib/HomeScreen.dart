import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'DashboardScreen.dart';
import 'AddTicketScreen.dart';
import 'AuthProvider.dart';
import 'ProfileScreen.dart';
import 'TicketListScreen.dart';
import 'TicketListScreen.dart' as TicketList;

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late PageController _pageController; // Add a PageController

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: Duration(seconds: 1),
      vsync: this,
    )..forward();

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(begin: Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _pageController = PageController(); // Initialize the PageController
  }

  @override
  void dispose() {
    _controller.dispose();
    _pageController.dispose(); // Dispose of the PageController
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Ticket System"),
        actions: [
          IconButton(
            icon: Icon(Icons.account_circle, size: 50),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: Consumer<AuthhProvider>(
        builder: (context, authProvider, child) {
          if (!authProvider.isAuthenticated) {
            return Center(
              child: Text(
                'User not authenticated',
                style: TextStyle(fontSize: 18, color: Colors.red),
              ),
            );
          } else {
            return Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.teal.shade600, Colors.tealAccent.shade100],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: SlideTransition(
                                    position: _slideAnimation,
                                    child: Text(
                                      'Welcome to the Ticket System',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 10),
                                FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: SlideTransition(
                                    position: _slideAnimation,
                                    child: Text(
                                      'What would you like to do?',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white70,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 20),
                                FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: SlideTransition(
                                    position: _slideAnimation,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        _pageController.jumpToPage(1); // Navigate to AddTicketScreen
                                      },
                                      style: ElevatedButton.styleFrom(
                                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(30),
                                        ),
                                        backgroundColor: Colors.teal.shade700,
                                      ),
                                      child: Text(
                                        'Add New Ticket',
                                        style: TextStyle(fontSize: 12, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 10),
                                FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: SlideTransition(
                                    position: _slideAnimation,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        _pageController.jumpToPage(2); // Navigate to TicketListScreen
                                      },
                                      style: ElevatedButton.styleFrom(
                                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(30),
                                        ),
                                        backgroundColor: Colors.teal.shade600,
                                      ),
                                      child: Text(
                                        'View Tickets',
                                        style: TextStyle(fontSize: 12, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 10),
                                FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: SlideTransition(
                                    position: _slideAnimation,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        _pageController.jumpToPage(3); // Navigate to DashboardScreen
                                      },
                                      style: ElevatedButton.styleFrom(
                                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(30),
                                        ),
                                        backgroundColor: Colors.teal.shade800,
                                      ),
                                      child: Text(
                                        'View Dashboard',
                                        style: TextStyle(fontSize: 12, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 4, // Take up more space
                        child: Container(
                          padding: EdgeInsets.all(8),
                          child: PageView(
                            controller: _pageController, // Use the PageController
                            children: [
                              Center(child: Text("Welcome Screen")), // Placeholder for HomeScreen content
                              AddTicketScreen(), // AddTicketScreen
                              TicketListScreen(), // TicketListScreen
                              DashboardScreen(), // DashboardScreen
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }
}
