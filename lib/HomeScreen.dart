import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ticket_ui_test/LoginScreen.dart';
import 'package:ticket_ui_test/widgets/button_widget.dart';
import 'DashboardScreen.dart';
import 'AddTicketScreen.dart';
import 'AuthProvider.dart';
import 'ProfileScreen.dart';
import 'TicketListScreen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late PageController _pageController; // Add a PageController
  int _currentIndex = 0; // Track the current screen index

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

    _pageController = PageController(
      initialPage: _currentIndex, // Initialize with the current index
    );

    // Listen for page changes
    _pageController.addListener(() {
      setState(() {
        _currentIndex = _pageController.page?.round() ?? 0; // Update current index
      });
    });
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
                              colors: [
                                Colors.teal.shade800,
                                Colors.teal.shade600,
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(20), // Round the top-right corner
                              bottomRight: Radius.circular(20), // Round the bottom-right corner
                            ),
                          ),
                          padding: EdgeInsets.all(8.0),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              // mainAxisAlignment: MainAxisAlignment.center,
                              // crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                // Image in the center

                                const SizedBox(height: 40,),
                                Center(
                                  child: ClipOval(
                                    child: Container(
                                      height: 90, // Height for elliptical shape
                                      width: 270, // Width for elliptical shape
                                      decoration: BoxDecoration(
                                        shape: BoxShape.rectangle, // Set the shape to rectangle
                                        image: DecorationImage(
                                          image: AssetImage('assets/images/KOC.jpeg'),
                                          fit: BoxFit.cover, // Ensures image fits the oval shape
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                SizedBox(height: 100),

                                FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: SlideTransition(
                                    position: _slideAnimation,
                                    child: ButtonWidget(
                                      icon: Icon(Icons.dashboard, color: Colors.white),
                                      buttonText: 'View Dashboard',
                                      onPressed: () {
                                        _pageController.jumpToPage(0); // Navigate to DashboardScreen
                                      },
                                      buttonColor: _currentIndex == 0 ? Colors.red : Colors.teal.shade400, // Dynamic color based on current index
                                    ),
                                  ),
                                ),
                                SizedBox(height: 10),

                                FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: SlideTransition(
                                    position: _slideAnimation,
                                    child: ButtonWidget(
                                      buttonText: 'Add New Ticket',
                                      icon: Icon(Icons.add, color: Colors.white),
                                      onPressed: () {
                                        _pageController.jumpToPage(1); // Navigate to AddTicketScreen
                                      },
                                      buttonColor: Colors.teal.shade400, // Change button color
                                    ),
                                  ),
                                ),
                                SizedBox(height: 10),
                                FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: SlideTransition(
                                    position: _slideAnimation,
                                    child: ButtonWidget(
                                      buttonText: 'View Tickets',
                                      icon: Icon(Icons.panorama_fish_eye, color: Colors.white),
                                      onPressed: () {
                                        _pageController.jumpToPage(2); // Navigate to TicketListScreen
                                      },
                                      buttonColor: Colors.teal.shade400, // Change button color
                                    ),
                                  ),
                                ),
                                SizedBox(height: 10),

                                // Logout button
                                FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: SlideTransition(
                                    position: _slideAnimation,
                                    child: ButtonWidget(
                                      icon: Icon(Icons.logout_sharp, color: Colors.white),
                                      buttonText: 'Logout',
                                      onPressed: () {
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => LoginScreen(), // Replace with your LoginPage
                                          ),
                                        );
                                      },
                                      buttonColor: Colors.teal.shade400, // Logout button color
                                    ),
                                  ),
                                )
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
                            controller: _pageController,
                            // Use the PageController
                            children: [
                              DashboardScreen(),
                              // Open DashboardScreen as the first screen
                              AddTicketScreen(),
                              // AddTicketScreen
                              TicketListScreen(),
                              // TicketListScreen
                              // If needed, you can add more screens here
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