import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  PlatformFile? _selectedImageFile; // Store the selected image
  String? _uploadedImageUrl; // Store the uploaded image URL
  String? _savedImageUrl; // Store the profile image URL fetched from Firestore

  @override
  void initState() {
    super.initState();
    _fetchProfileImage(); // Fetch the profile image when the screen loads
  }

  // Function to fetch the profile image URL from Firestore
  Future<void> _fetchProfileImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.email).get();
      if (doc.exists) {
        setState(() {
          _savedImageUrl = doc['profileImageUrl']; // Fetch the saved image URL from Firestore
        });
      }
    }
  }

  // Function to pick an image
  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final pickedFile = result.files.first;
        setState(() {
          _selectedImageFile = pickedFile; // Store selected image
        });
        _uploadImage(pickedFile); // Upload the image
      }
    } catch (e) {
      print("Error picking image: ${e.toString()}");
    }
  }

  // Function to upload image to Firebase Storage and save the URL in Firestore
  Future<void> _uploadImage(PlatformFile pickedFile) async {
    try {
      if (pickedFile.bytes == null) return;

      final user = FirebaseAuth.instance.currentUser;
      final storageRef = FirebaseStorage.instance.ref().child('user_profiles/${user!.uid}/${pickedFile.name}');
      UploadTask uploadTask = storageRef.putData(pickedFile.bytes!);

      TaskSnapshot snapshot = await uploadTask.whenComplete(() {});
      String downloadUrl = await snapshot.ref.getDownloadURL(); // Get download URL of uploaded image

      // Save the image URL in Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.email).update({
        'profileImageUrl': downloadUrl,
      });

      setState(() {
        _uploadedImageUrl = downloadUrl; // Update UI with the new image URL
        _savedImageUrl = downloadUrl; // Persist the image URL
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Profile image updated successfully!')));
    } catch (e) {
      print("Error uploading image: $e");
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
                    child: Stack(
                      children: [
                        // CircleAvatar with the user's profile picture
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey.shade200, // Optional: to add a background color to CircleAvatar
                          child: ClipOval(
                            child: _savedImageUrl != null
                                ? Image.network(
                              _savedImageUrl!,
                              fit: BoxFit.cover,
                              width: 100,
                              height: 100,
                              errorBuilder: (context, error, stackTrace) {
                                return Image.asset('assets/images/default_avatar.gif',
                                  fit: BoxFit.cover,
                                  width: 100,
                                  height: 100,
                                );
                              },
                            )
                                : Image.asset('assets/images/default_avatar.gif',
                              fit: BoxFit.cover,
                              width: 100,
                              height: 100,
                            ),
                          ),
                        ),
                        // Camera icon positioned at the bottom-right of the CircleAvatar
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () {
                              _pickImage(); // Pick image from the gallery
                            },
                            child: CircleAvatar(
                              radius: 15,
                              backgroundColor: Colors.white,
                              child: Icon(Icons.camera_alt, color: Colors.blueAccent, size: 18),
                            ),
                          ),
                        ),
                      ],
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
                        //  _buildProfileInfo('Phone No.', userData['phone'] ?? '0000000000'),
                        SizedBox(height: 20),
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [

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
