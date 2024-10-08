import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as Path;

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  File? _imageFile;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Function to pick an image from the gallery or camera
  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
      _uploadImage();
    }
  }

  // Function to upload image to Firebase Storage and save URL in Firestore
  Future<void> _uploadImage() async {
    if (_imageFile == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      final fileName = Path.basename(_imageFile!.path);
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('user_profiles/${user!.uid}/$fileName');

      // Upload image
      await storageRef.putFile(_imageFile!);

      // Get the download URL
      final downloadUrl = await storageRef.getDownloadURL();

      // Update Firestore with the image URL
      await FirebaseFirestore.instance.collection('users').doc(user.email).update({
        'profileImageUrl': downloadUrl,
      });

      setState(() {
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Profile image updated successfully!')));
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload image: $e')));
    }
  }

  // Function to handle logout
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/login'); // Navigate back to the login screen
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('User Profile'),
          backgroundColor: Colors.teal.shade800,
        ),
        body: Center(child: Text('No user found. Please log in again.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Profile', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(user.email).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('User data not found in Firestore.'));
          }

          var userData = snapshot.data!.data() as Map<String, dynamic>;

          return Column(
            children: [
              // Profile Header with Cover Image
              Stack(
                children: [
                  // Cover Image Section
                  Container(
                    height: 250, // Adjust the height to the desired cover size
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/images/Rectangle128.jpg'), // Path to your cover image
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  // Profile Picture & Name
                  Positioned(
                    top: 110, // This ensures the profile picture overlaps with the cover
                    left: 20,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: _imageFile != null
                          ? FileImage(_imageFile!)
                          : userData['profileImageUrl'] != null
                          ? NetworkImage(userData['profileImageUrl'])
                          : AssetImage('assets/images/default_avatar.gif') as ImageProvider,
                    ),
                  ),
                  Positioned(
                    top: 160, // Adjusted to be below the avatar
                    left: 150, // Adjust according to your layout
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userData['name'] ?? 'N/A',
                          style: TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Developer',
                          style: TextStyle(fontSize: 18, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 60), // Adjust the spacing to fit content below the header
              // My Profile Section
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('My Profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        SizedBox(height: 16),
                        _buildProfileInfo('User Id', userData['userId'] ?? '000000000'),
                        _buildProfileInfo('Role', userData['role'] ?? '000000000'),
                        _buildProfileInfo('Email', userData['email'] ?? 'example@example.com'),
                        _buildProfileInfo('Phone No.', userData['phone'] ?? '0000000000'),
                        SizedBox(height: 20),
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Edit Button
                              // Edit Button
                              ElevatedButton(
                                onPressed: () {},
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                    side: BorderSide(color: Colors.blueAccent), // Add border to match the color
                                  ),
                                  backgroundColor: Colors.transparent, // Background matching with normal background
                                  elevation: 0, // Remove shadow
                                ),
                                child: Text(
                                  'Edit',
                                  style: TextStyle(fontSize: 18, color: Colors.blueAccent),
                                ),
                              ),
                              SizedBox(width: 10),
                              // Logout Button with Confirmation Dialog
                              ElevatedButton(
                                onPressed: () => _showLogoutConfirmationDialog(context), // Trigger the confirmation dialog
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                    side: BorderSide(color: Colors.blueAccent), // Add border to match the color
                                  ),
                                  backgroundColor: Colors.transparent, // Background matching with normal background
                                  elevation: 0, // Remove shadow
                                ),
                                child: Text(
                                  'Logout',
                                  style: TextStyle(fontSize: 18, color: Colors.blueAccent),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
  // Function to show the logout confirmation dialog
  void _showLogoutConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Logout Confirmation'),
          content: Text('Do you really want to exit?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog and do nothing
              },
              child: Text('No', style: TextStyle(color: Colors.blueAccent)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                _logout(); // Call the logout function
              },
              child: Text('Logout', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );
  }



  Widget _buildProfileInfo(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
