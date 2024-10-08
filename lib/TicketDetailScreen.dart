import 'dart:io';
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'FullScreenImage.dart';

class TicketDetailScreen extends StatefulWidget {
  final String ticketId;

  TicketDetailScreen({required this.ticketId});

  @override
  _TicketDetailScreenState createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  PlatformFile? _image;
  String? _uploadedImageUrl;
  String? _savedImageUrl;
  String? userRole; // Made nullable
  String? userDepartment;

  // final ImagePicker _picker = ImagePicker();
  // final TextEditingController _nameController = TextEditingController();
  final TextEditingController _replyController = TextEditingController();
  late AnimationController _animationController;
  final TextEditingController _questionnaireController = TextEditingController();
  final TextEditingController _followUpQuestionController = TextEditingController();

  bool _isLoading = true;
  String _currentStatus = 'Open';
  Map<String, dynamic>? _ticketData;
  bool _isUserListInitialized = false; // Flag to check if user list is initialized
  String? _selectedUser;
  late List<Map<String, dynamic>> _users = []; // Store both name and email
  @override
  void initState() {
    super.initState();
    _fetchTicketData();
  }

  Future<void> _fetchTicketData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Fetch the current user's role and department
    userRole = await _getUserRole(user.email!);
    userDepartment = await _getUserDepartment(user.email!);
    _initializeUserList();

    // Fetch the ticket data from Firestore
    final ticketDoc = await FirebaseFirestore.instance
        .collection('tickets')
        .doc(widget.ticketId)
        .get();

    if (!ticketDoc.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ticket not found.')),
      );
      Navigator.pop(context);
      return;
    }

    // Safely get the data from the document snapshot
    final ticketData = ticketDoc.data();

    // Check if ticketData is null
    if (ticketData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No ticket data found.')),
      );
      Navigator.pop(context);
      return;
    }

    // Safely extract values with null-aware operators
    String ticketDepartment = ticketData['department'] ?? 'Unknown'; // Default to 'Unknown' if null
    String assignedTo = ticketData['assignedTo'] ?? 'Unassigned'; // Handle null assignment
    String ticketQuestionnaire = ticketData['questionnaire'] ?? 'No questionnaire provided'; // Default message if null
    String ticketFollowUpQuestion = ticketData['follow_up_question'] ?? 'No follow-up question provided'; // Default message if null

    // Role-based filtering logic
    if (userDepartment == 'Admin' || userDepartment == 'Support') {
      // Admin and Support can view all tickets
      setState(() {
        _ticketData = ticketData;
        _questionnaireController.text = ticketQuestionnaire; // Use null-safe value
        _followUpQuestionController.text = ticketFollowUpQuestion; // Use null-safe value
        _currentStatus = ticketData['status'] ?? 'Unknown'; // Default to 'Unknown' if status is null
        _isLoading = false;
      });
    } else if (userRole == 'DepartmentHead') {
      // Department Head can only see tickets for their department
      if (userDepartment == ticketDepartment) {
        setState(() {
          _ticketData = ticketData;
          _currentStatus = ticketData['status'] ?? 'Unknown'; // Handle null status
          _isLoading = false;
        });

        _initializeUserList();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You are not authorized to view this ticket.')),
        );
        Navigator.pop(context);
      }
    } else if (userRole == 'Member') {
      // Member can only see tickets assigned to them
      if (assignedTo == user.email) {
        setState(() {
          _ticketData = ticketData;
          _currentStatus = ticketData['status'] ?? 'Unknown'; // Handle null status
          _isLoading = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You are not authorized to view this ticket.')),
        );
        Navigator.pop(context);
      }
    }

    // Update status if ticket is 'Open'
    if (_currentStatus == 'Open') {
      _updateTicketStatus('In Progress');
    }
  }

  Future<void> _initializeUserList() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      print('No user logged in.');
      return;
    }

    QuerySnapshot usersSnapshot;

    if (userDepartment == 'Admin' || userDepartment == 'Support') {
      usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
    } else if (userRole == 'DepartmentHead') {
      usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('department', isEqualTo: userDepartment)
          .get();
    } else {
      // Members should not see any users
      setState(() {
        _users = [];
        _isUserListInitialized = true;
      });
      return;
    }

    if (usersSnapshot.docs.isEmpty) {
      print('No users found in Firestore for this role.');
    } else {
      setState(() {
        _users = usersSnapshot.docs.map((doc) {
          return {
            'name': doc['name'] ,
            'email': doc['email'],
          };
        }).cast<Map<String, dynamic>>().toList();
        _isUserListInitialized = true;
      });
    }
  }
  Future<String> _getUserRole(String email) async {
    final userQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .get();
    if (userQuery.docs.isNotEmpty) {
      return userQuery.docs.first['role'];
    }
    return userQuery.docs.isNotEmpty ? userQuery.docs.first['role'] : null;
  }

  Future<String> _getUserDepartment(String email) async {
    final userQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .get();
    if (userQuery.docs.isNotEmpty) {
      return userQuery.docs.first['department'];
    }
    return userQuery.docs.isNotEmpty ? userQuery.docs.first['department'] : null;;
  }

  Future<void> _updateTicketStatus(String status) async {
    try {
      // Ensure _ticketData is not null before accessing 'department'
      if (_ticketData != null) {
        // Update both 'department' and 'status' fields in Firestore
        await FirebaseFirestore.instance
            .collection('tickets')
            .doc(widget.ticketId)
            .update({
          'department': _ticketData!['department'] ?? 'Unknown', // Use null-aware operator to handle null
          'status': status, // Update status with the provided value
        });

        // Update local state to reflect the new status
        setState(() {
          _currentStatus = status;
        });

        // Optionally show a success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ticket status updated to $status')),
        );
      } else {
        // Handle case where _ticketData is null
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update ticket status: No ticket data available')),
        );
      }
    } catch (e) {
      // Handle potential errors (e.g., network issues, Firestore permission issues)
      print('Error updating ticket status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update ticket status')),
      );
    }
  }

  Future<void> _pickImage() async {
    // Check if an image is already selected
    if (_image != null) {
      print("Image already selected, skipping picker.");
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false, // Only allow single image selection
      );

      if (result != null && result.files.isNotEmpty) {
        final pickedFile = result.files.first;

        // Use bytes instead of path
        final bytes = pickedFile.bytes; // Get the bytes of the picked file
        if (bytes != null) {
          setState(() {
            _image = pickedFile; // Store the picked file
          });
          print("Picked image bytes: ${bytes.length} bytes");
        } else {
          print("No bytes found in the picked file.");
        }
      } else {
        print("No image selected.");
      }
    } catch (e) {
      print("Error picking image: ${e.toString()}");
    }
  }

  Future<String?> _uploadImage() async {
    try {
      // Ensure there's an image to upload
      if (_image == null) {
        print("No image selected for upload.");
        return null;
      }

      // Create a reference to the Firebase Storage
      final storageRef = FirebaseStorage.instance.ref().child('images/${_image!.name}');

      // Upload the image bytes
      final Uint8List? imageBytes = _image!.bytes;
      if (imageBytes != null) {
        await storageRef.putData(imageBytes);

        // Get the download URL
        final downloadUrl = await storageRef.getDownloadURL();
        print('Image uploaded: $downloadUrl');
        return downloadUrl;
      } else {
        print('Image bytes not found.');
        return null;
      }
    } catch (error) {
      print('Error uploading image: $error');
      return null; // Return null on error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ticket Details'),
        backgroundColor: Colors.teal.shade800,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            // Left Column for Ticket Details
            Expanded(
              flex: 1,
              child: _buildTicketDetailsBox(),
            ),

            SizedBox(width: 20),

            // Right Column for Chat and Actions
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  _buildChatSection(),
                  SizedBox(height: 20),
                  _buildMessageInputSection(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActionBar(),
    );
  }

  Widget _buildTicketDetailsBox() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TICKET ID : ${widget.ticketId}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.teal.shade800,
              ),
            ),
            Divider(),
            // _buildDetailRow('Contact Name', _ticketData?['agent_name']),
            //  _buildDetailRow('Email', _ticketData?['email']),
            //  _buildDetailRow('Phone', _ticketData?['phone']),
            //  _buildDetailRow('Account Name', _ticketData?['account_name']),

            _buildDetailRow('Agent Name', _ticketData?['agent_name']),
            _buildDetailRow('Subject', _ticketData?['subject']),
            _buildDetailRow('Description', _ticketData?['description']),
            _buildDetailRow('Department', _ticketData?['department']),
            _buildDetailRow('Questionnaire', _ticketData?['questionnaire']),
            _buildDetailRow('Followup Question', _ticketData?['followup_question']),
            SizedBox(height: 20),
            Row(
              children: [
                Text(
                  'STATUS:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade800,
                  ),
                ),
                SizedBox(width: 10),
                Chip(
                  label: Text(_currentStatus),
                  backgroundColor: Colors.orangeAccent,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String title, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$title:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.teal.shade600,
            ),
          ),
          Text(
            value ?? 'N/A',
            style: TextStyle(color: Colors.black),
          ),
        ],
      ),
    );
  }

  // Chat Section UI with logic from backend and message retrieval.
  Widget _buildChatSection() {
    return Expanded(
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Chat header with user details
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundImage: NetworkImage(
                        'https://via.placeholder.com/150'), // Example Avatar, replace with actual image URL.
                    radius: 25,
                  ),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Chat Support',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            Divider(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('tickets')
                    .doc(widget.ticketId)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }

                  final messages = snapshot.data!.docs;

                  return ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message =
                      messages[index].data() as Map<String, dynamic>;
                      return _buildChatBubble(message as Map<String, dynamic>); // Pass the message map
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }


// Function to build chat bubble with styling
  Widget _buildChatBubble(Map<String, dynamic> message) {
    bool isMe = message['sender'] == 'email'; // Logic for identifying sender

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 5),
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment:
          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Display the message text if available
            if (message['message'] != null && message['message'].isNotEmpty)
              Text(
                message['message'],
                style: TextStyle(
                    color: isMe ? Colors.white : Colors.black),
              ),
            SizedBox(height: 5),

            // Display the image if the imageUrl is available
            if (message['imageUrl'] != null && message['imageUrl'].isNotEmpty)
              GestureDetector(
                onTap: () {
                  // Optional: Display the image in full-screen view
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FullScreenImage(
                        imageUrl: message['imageUrl'],
                      ),
                    ),
                  );
                },
                child: Image.network(
                  message['imageUrl'],
                  height: 200, // Adjust the height as needed
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
          ],
        ),
      ),
    );
  }


// Input section with send message functionality
  Widget _buildMessageInputSection() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            // Pin Icon for attaching images
            IconButton(
              icon: Icon(Icons.attach_file, color: Colors.teal.shade800),
              onPressed: () async {
                await _pickImage(); // Open the image picker when pin is clicked
              },
            ),
            SizedBox(width: 10),

            Icon(Icons.emoji_emotions, color: Colors.teal.shade800),
            SizedBox(width: 10),

            // Text Input for message
            Expanded(
              child: TextField(
                controller: _replyController,
                decoration: InputDecoration(
                  hintText: 'Enter Your Message...',
                  border: InputBorder.none,
                ),
              ),
            ),

            // Send Button
            IconButton(
              onPressed: () async {
                if (_replyController.text.isNotEmpty || _image != null) {
                  await _sendMessage(); // Send message with text and image if available
                }
              },
              icon: Icon(Icons.send, color: Colors.blueAccent),
            ),
          ],
        ),
      ),
    );
  }



  Future<void> _sendMessage() async {
    String questionnaireText = _questionnaireController.text;
    String followUpQuestionText = _followUpQuestionController.text;

    // Fetch the ticket's image URL from the tickets collection (if applicable)
    String? TicketdownloadUrl;
    String? ticketQuestionnaire;
    String? ticketFollowUpQuestion;

    DocumentSnapshot ticketSnapshot = await FirebaseFirestore.instance
        .collection('tickets')
        .doc(widget.ticketId)
        .get();

    // Check if the document exists and get the image URL from it
    if (ticketSnapshot.exists) {
      TicketdownloadUrl = ticketSnapshot['image_url']; // Assuming 'image_url' was used when creating the ticket
      ticketQuestionnaire = ticketSnapshot['questionnaire']; // Fetch ticket questionnaire
      ticketFollowUpQuestion = ticketSnapshot['follow_up_question']; // Fetch ticket follow-up question
    }

    // Use the questionnaire and follow-up question from the original ticket if they are empty in the current reply
    questionnaireText = questionnaireText.isNotEmpty ? questionnaireText : (ticketQuestionnaire ?? 'No questionnaire provided');
    followUpQuestionText = followUpQuestionText.isNotEmpty ? followUpQuestionText : (ticketFollowUpQuestion ?? 'No follow-up question provided');

    final user = FirebaseAuth.instance.currentUser; // Get the current user
    if (user == null) return; // Exit if no user is logged in

    // Ensure the reply field is not empty
    if (_replyController.text.isNotEmpty || _image != null) {
      String? downloadUrl; // This will store the image URL if an image is uploaded

      // Upload the image if one has been selected
      if (_image != null) {
        downloadUrl = await _uploadImage(); // Upload image and get the download URL
      }

      // Send the reply message along with the image URL (if any)
      await FirebaseFirestore.instance
          .collection('tickets')
          .doc(widget.ticketId)
          .collection('messages')
          .add({
        'sender': user.email, // Send the email of the logged-in user
        'message': _replyController.text,
        'timestamp': FieldValue.serverTimestamp(),
        'imageUrl': downloadUrl ?? '', // Include the image URL if an image was uploaded
        'questionnaire': questionnaireText,
        'follow_up_question': followUpQuestionText,
        'image_url': TicketdownloadUrl ?? '',
      });

      // Clear input fields after sending the message
      _replyController.clear();
      _questionnaireController.clear(); // Clear questionnaire after sending
      _followUpQuestionController.clear(); // Clear follow-up question after sending
      _image = null; // Reset the image after message is sent
    } else {
      // Show an error if the reply field is empty
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter your reply or select an image')),
      );
    }
  }


  Future<void> _reassignTicket() async {
    if (_selectedUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a user to assign the ticket to.')),
      );
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('tickets')
          .doc(widget.ticketId)
          .update({
        'assignedTo': _selectedUser,  // Use email stored in _selectedUser
        'status': 'Reassigned',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ticket successfully reassigned to $_selectedUser.')),
      );

      Navigator.pop(context);
    } catch (error) {
      print('Error updating Firestore: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reassign the ticket. Please try again.')),
      );
    }
  }


  Widget _buildBottomActionBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            onPressed: () async {
              await _reassignTicket(); // Trigger the reassignment when button is clicked
            },
            icon: Icon(Icons.person_add_alt, color: Colors.green),
            label: Text(
              'Reassign Ticket',
              style: TextStyle(color: Colors.green),
            ),
          ),

          // Dropdown to select user to reassign the ticket
          DropdownButton<String>(
            hint: Text(_selectedUser != null ? 'Assigned to $_selectedUser' : 'Select a user'), // Show selected user
            items: _users.map<DropdownMenuItem<String>>((user) {
              return DropdownMenuItem<String>(
                value: user['email'],
                child: Text('${user['name']} (${user['email']})'),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedUser = value; // Update the selected user
              });
            },
            value: _selectedUser, // Show selected value in dropdown
          ),
        ],
      ),
    );
  }

}
