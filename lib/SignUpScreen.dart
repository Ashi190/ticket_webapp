import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SignUpScreen extends StatefulWidget {
  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailController = TextEditingController();
  final _nameController = TextEditingController(); // Name controller
  final _passwordController = TextEditingController();

  // For Role dropdown
  String _selectedRole = 'Member'; // Default role

  // For Department dropdown
  String _selectedDepartment = 'Admin'; // Default department

  final List<String> _roles = ['Member', 'DepartmentHead']; // Roles options
  final List<String> _departments = [
    'Admin',
    'Support',
    'Development',
    'Sales',
    'Marketing',
    'BA',
    'Accounts',
    'Outbound',
    'Dispatch'
  ];

  Future<String> generateUserID() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('userId')
          .get();

      int newId;
      if (snapshot.docs.isNotEmpty) {
        final lastUserId = snapshot.docs.last['userId'];
        newId = int.parse(lastUserId.split('-')[1]) + 1;
      } else {
        newId = 1001; // Start from 1001 if no users exist
      }

      final newUserId = 'USER-$newId';

      print('Generated User ID: $newUserId');

      return newUserId;
    } catch (e) {
      print('Error generating user ID: $e');
      throw e;
    }
  }

  Future<void> createUser(Map<String, dynamic> userData) async {
    final newUserId = await generateUserID(); // Generate new user ID
    final userWithID = {
      ...userData,
      'userId': newUserId, // Add the generated ID to user data
    };
    await FirebaseFirestore.instance.collection('users').doc(_emailController.text).set(userWithID);
  }

  Future<void> _register() async {
    final email = _emailController.text;
    final name = _nameController.text;
    final password = _passwordController.text;
    final role = _selectedRole; // Use selected role from the dropdown
    final department = _selectedDepartment;

    try {
      // Register user with Firebase Authentication
      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Prepare user data
      Map<String, dynamic> userData = {
        'name': name,
        'email': email,
        'role': role,
        'department': department,
      };

      // Save user data to Firestore
      await createUser(userData);

      // Navigate to login screen
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      print(e); // Handle errors
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Registration failed'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Name TextField
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.8),
                labelText: 'Name',
                labelStyle: TextStyle(color: Colors.blue),
                prefixIcon: Icon(Icons.person, color: Colors.blue),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: 20),

            // Email TextField
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.8),
                labelText: 'Email',
                labelStyle: TextStyle(color: Colors.blue),
                prefixIcon: Icon(Icons.email, color: Colors.blue),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: 20),

            // Password TextField
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.8),
                labelText: 'Password',
                labelStyle: TextStyle(color: Colors.blue),
                prefixIcon: Icon(Icons.lock, color: Colors.blue),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: 20),

            // Role Dropdown
            DropdownButtonFormField<String>(
              value: _selectedRole,
              items: _roles.map((role) {
                return DropdownMenuItem<String>(
                  value: role,
                  child: Text(role),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedRole = newValue!; // Update selected role
                });
              },
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.8),
                labelText: 'Select Role',
                labelStyle: TextStyle(color: Colors.blue),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: 20),

            // Department Dropdown
            DropdownButtonFormField<String>(
              value: _selectedDepartment,
              items: _departments.map((department) {
                return DropdownMenuItem<String>(
                  value: department,
                  child: Text(department),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedDepartment = newValue!; // Update selected department
                });
              },
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.8),
                labelText: 'Select Department',
                labelStyle: TextStyle(color: Colors.blue),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: 40),

            // Sign Up Button
            ElevatedButton(
              onPressed: _register,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 80, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                backgroundColor: Colors.blueAccent,
              ),
              child: Text(
                'Sign Up',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
