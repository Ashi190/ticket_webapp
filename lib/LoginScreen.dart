
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';
import 'package:provider/provider.dart';
import 'AuthProvider.dart';
import 'OtpService.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  final OtpService otpService = OtpService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();


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

  // Method to send OTP
 /* Future<void> _sendOtp() async {
    String email = _emailController.text;
    if (email.isNotEmpty) {
      final otp = _generateOtp(); // Generate OTP
      await _sendOtpEmail(email, otp); // Send OTP to the user's email
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OTP sent to $email')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid email')),
      );
    }
  }*/
  // Generate a 6-digit OTP
 /* String _generateOtp() {
    final random = Random();
    String otp = '';
    for (int i = 0; i < 6; i++) {
      otp += random.nextInt(10).toString(); // Generate random number between 0-9
    }
    return otp;
  }*/
/*  Future<void> _sendOtpEmail(String email, String otp) async {
    // Using Gmail's SMTP server
    final smtpServer = gmail('yourEmail@gmail.com', 'yourPassword'); // Use an App Password if 2FA is enabled

    final message = Message()
      ..from = Address('yourEmail@gmail.com', 'Your App Name') // Sender email
      ..recipients.add(email)  // Recipient email
      ..subject = 'Your OTP Code'
      ..text = 'Your OTP code is: $otp';  // OTP content

    try {
      final sendReport = await send(message, smtpServer);
      print('Message sent: ' + sendReport.toString());
    } on MailerException catch (e) {
      print('Message not sent. $e');
      for (var p in e.problems) {
        print('Problem: ${p.code}: ${p.msg}');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send OTP. Please try again.')),
      );
    }
  }*/
  // Dialog to show for entering email and sending OTP
/*  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Forgot Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Enter your email',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _sendOtp(); // Call the OTP sending function
                Navigator.of(context).pop(); // Close dialog after sending OTP
              },
              child: Text('Send OTP'),
            ),
          ],
        );
      },
    );
  }*/
// Show Reset Password Dialog after OTP verification
 /* void _showResetPasswordDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Reset Password'),
        content: TextFormField(
          decoration: InputDecoration(
            labelText: 'Enter your new password',
          ),
          controller: _newPasswordController,
          obscureText: true,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              // Implement your password reset logic here
              // For example, if you're using Firebase:
              User? user = FirebaseAuth.instance.currentUser;

              try {
                await user?.updatePassword(_newPasswordController.text);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Password reset successfully')),
                );
                Navigator.pop(context);  // Close reset password dialog
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to reset password. Please try again.')),
                );
              }
            },
            child: Text('Reset Password'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);  // Close dialog
            },
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }*/
  // Method to send password reset email using Firebase
  Future<void> _sendPasswordResetEmail(String email) async {
    String email = _emailController.text;

    if (email.isNotEmpty) {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password reset email sent. Check your email inbox.')),
        );
      } on FirebaseAuthException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send password reset email: ${e.message}')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid email address')),
      );
    }
  }

  // Show Forgot Password Dialog
  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Forgot Password'),
          content: TextField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'Enter your email',
              border: OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_emailController.text.isNotEmpty) {
                  _sendPasswordResetEmail(_emailController.text);
                  Navigator.of(context).pop(); // Close dialog after sending email
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please enter a valid email address')),
                  );
                }
              },
              child: Text('Send Reset Link'),
            ),
          ],
        );
      },
    );
  }



  @override
  Widget build(BuildContext context) {


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
                        onSubmitted: (_) {
                          _triggerSignIn();  // Trigger sign-in when "Enter" is pressed
                        },
              ),
            ),
                    SizedBox(height: 40),
                    // Sign In Button with Animation and Authentication Logic
                    _isLoading
                        ? CircularProgressIndicator()
                        : ElevatedButton(
                      onPressed: () async {
                        _triggerSignIn();
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
                       _showForgotPasswordDialog(); // Open dialog to input email and send OTP
                      },
                      child: Text(
                        'Forgot Password?',
                        style: TextStyle(color: Color(0xFF6E7C56), fontSize: 16),
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

  // Helper method to trigger sign-in
  void _triggerSignIn() async {
    final authProvider = Provider.of<AuthhProvider>(context, listen: false);  // Fetch AuthProvider here

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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
