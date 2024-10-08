import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/scheduler.dart';
import 'AuthProvider.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Set up animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _controller.forward(); // Start the animation
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthhProvider>(context);

    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Row(
          children: <Widget>[
            // Left Side - Background Image
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/background.jpeg'), // Your background image
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      'Sign In To',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF5B4636), // A brownish color to match the text in the image
                        letterSpacing: 2.0,
                      ),
                    ),
                    SizedBox(height: 40),
                    // Username TextField with Shadow
                    Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Color(0xFFF7F5F2), // A very light beige color for the field background
                          labelText: 'Email address',
                          labelStyle: TextStyle(color: Color(0xFF6E7C56)), // A greenish tone for labels
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30.0),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    // Password TextField with Shadow
                    Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Color(0xFFF7F5F2), // Matching the username field's background
                          labelText: 'Password',
                          labelStyle: TextStyle(color: Color(0xFF6E7C56)), // Same greenish label color
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30.0),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 40),
                    // Sign In Button with Animation and Authentication Logic
                    _isLoading
                        ? CircularProgressIndicator()
                        : ElevatedButton(
                      onPressed: () async {
                        setState(() {
                          _isLoading = true;
                        });

                        String username = _usernameController.text;
                        String password = _passwordController.text;

                        if (username.isNotEmpty && password.isNotEmpty) {
                          await authProvider.login(username, password, context);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Please enter valid credentials'),
                            ),
                          );
                        }

                        setState(() {
                          _isLoading = false;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 80, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        backgroundColor: Color(0xFF5B4636), // Brown color matching the logo's text
                        shadowColor: Colors.black26,
                      ),
                      child: Text(
                        'SIGN IN',
                        style: TextStyle(
                            fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(height: 20),
                    // Forgot Password
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/forgot-password');
                      },
                      child: Text(
                        'Forgot Password?',
                        style: TextStyle(color: Color(0xFF6E7C56), fontSize: 16), // Greenish tone for the link
                      ),
                    ),
                    SizedBox(height: 10),
                    // Signup Suggestion Text
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Don’t have an account? ',
                          style: TextStyle(fontSize: 16, color: Color(0xFF8C847B)), // Neutral beige/brown tone
                        ),
                        // Clickable Sign Up Text
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/signup');
                          },
                          child: Text(
                            'Sign Up',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF6E7C56), // Matching greenish tone for the clickable link
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),



          ],
        ),
      ),
    );
  }


  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
