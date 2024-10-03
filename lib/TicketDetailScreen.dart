
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'FullScreenImage.dart';



class TicketDetailScreen extends StatefulWidget {
  final String ticketId;

  TicketDetailScreen({required this.ticketId});

  @override
  _TicketDetailScreenState createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen>
    with SingleTickerProviderStateMixin {
  late Map<String, dynamic> _ticketData;
  String _currentStatus = 'Open';
  bool _isLoading = true;
  late String userEmail;
  String? userRole; // Made nullable
  String? userDepartment; // Made nullable
  late String userId; // Declare userId variable
  String? _fileName;
  PlatformFile? _image; // Replace this with your variable for storing the image
  // Add this variable to track if an image has been picked


 // final ImagePicker _picker = ImagePicker();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _replyController = TextEditingController();
  late AnimationController _animationController;

  String? _selectedUser;
  late List<Map<String, dynamic>> _users = []; // Store both name and email

  bool _isUserListInitialized = false; // Flag to check if user list is initialized

  @override
  void initState() {
    super.initState();
    _fetchTicketData();
    _initializeUserList();
    _animationController = AnimationController(
        vsync: this, duration: Duration(milliseconds: 300));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _fetchTicketData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Fetch the current user's role and department
    userRole = await _getUserRole(user.email!);
    userDepartment = await _getUserDepartment(user.email!);

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

    // Extract ticket data
    final ticketData = ticketDoc.data()!;
    final ticketDepartment = ticketData['department'];
    final assignedTo = ticketData['assignedTo'];

    // Role-based filtering logic
    if (userDepartment == 'Admin' || userDepartment == 'Support') {
      // Admin and Support can view all tickets
      setState(() {
        _ticketData = ticketData;
        _currentStatus = _ticketData['status'];
        _isLoading = false;
      });
    } else if (userRole == 'DepartmentHead') {
      // Department Head can only see tickets for their department
      if (userDepartment == ticketDepartment) {
        setState(() {
          _ticketData = ticketData;
          _currentStatus = _ticketData['status'];
          _isLoading = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You are not authorized to view this ticket.')),
        );
        Navigator.pop(context);
      }
    } else if (userRole == 'Member') {
      // POC (member) can only see tickets assigned to them
      if (assignedTo == user.email) {
        setState(() {
          _ticketData = ticketData;
          _currentStatus = _ticketData['status'];
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
    await FirebaseFirestore.instance
        .collection('tickets')
        .doc(widget.ticketId)
        .update({'status': status});
    setState(() {
      _currentStatus = status;
    });
  }

  Future<void> _sendMessage() async {
    if (_nameController.text.isNotEmpty && _replyController.text.isNotEmpty) {
      // Upload the image first and get the download URL (if any)

      String? downloadUrl = await _uploadImage();
      await FirebaseFirestore.instance
          .collection('tickets')
          .doc(widget.ticketId)
          .collection('messages')
          .add({
        'sender': _nameController.text,
        'message': _replyController.text,
        'timestamp': FieldValue.serverTimestamp(),
        'imageUrl': downloadUrl ?? '', // This will hold the URL of the uploaded image.
      });

      _nameController.clear();
      _replyController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter both name and reply')),
      );
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


  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp != null) {
      DateTime dateTime = timestamp.toDate();
      return DateFormat('yyyy-MM-dd – HH:mm').format(dateTime);
    }
    return 'Unknown time';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ticket Details'),
        elevation: 2.0,
        backgroundColor: Colors.white, // Changed to teal
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTicketDetailsBox(),
              SizedBox(height: 20),
              _buildMessageSection(),
              SizedBox(height: 20),
              _buildReplySection(),
              SizedBox(height: 20),
              _buildReassignSection(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomAppBar(),
    );
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false, // If you only want to allow single image selection
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
      // Create an HTML file input element
      final html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
      uploadInput.accept = 'image/*'; // Accept only image files
      uploadInput.click(); // Open the file picker dialog

      // Wait for the file to be selected
      final Completer<String?> completer = Completer();

      uploadInput.onChange.listen((e) async {
        final files = uploadInput.files;
        if (files!.isEmpty) {
          completer.complete(null); // No file selected
          return;
        }

        // Get the first file
        final file = files[0];
        final _fileName = file.name;

        // Create a reference to the Firebase Storage
        final storageRef = FirebaseStorage.instance.ref().child('images/$_fileName');

        // Read the file as a Blob
        final reader = html.FileReader();
        reader.readAsArrayBuffer(file); // Read as ArrayBuffer

        reader.onLoadEnd.listen((e) async {
          try {
            // Once the file is read, upload it
            final blob = reader.result as Uint8List; // Get the file data
            await storageRef.putData(blob); // Upload the file

            // Get the download URL
            final downloadUrl = await storageRef.getDownloadURL();

            // Return the download URL
            print('Image uploaded: $downloadUrl');
            completer.complete(downloadUrl); // Complete with the download URL
          } catch (uploadError) {
            print('Error uploading image: $uploadError');
            completer.completeError(uploadError); // Complete with error
          }
        });
      });

      // Await the completer to get the download URL
      return await completer.future;
    } catch (error) {
      print('Error selecting file: $error');
      return null; // Return null on error
    }
  }

  Widget _buildTicketDetailsBox() {
    return Card(
      elevation: 12.0, // Increased elevation for more prominence
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.shade100, Colors.white], // Teal and white gradient
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20.0), // Increased padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Ticket ID: ${widget.ticketId}',
                  style: TextStyle(
                    fontSize: 26, // Increased font size for visibility
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                Tooltip(
                  message: 'This is the unique identifier for the ticket.',
                  child: Icon(Icons.info_outline, color: Colors.teal),
                ),
              ],
            ),
            SizedBox(height: 16),
            Divider(color: Colors.teal.shade200), // Divider for separation
            SizedBox(height: 10),
            Text(
              'Ticket Details',
              style: TextStyle(
                fontSize: 22, // Increased font size for heading
                fontWeight: FontWeight.bold,
                color: Colors.teal.shade800,
              ),
            ),
            SizedBox(height: 10),
            _buildDetailRow('Email', _ticketData['email']),
            _buildDetailRow('Phone', _ticketData['phone']),
            _buildDetailRow('Subject', _ticketData['subject']),
            _buildDetailRow('Description', _ticketData['description']),
            _buildDetailRow('Department', _ticketData['department']),
            _buildDetailRow('sub_department', _ticketData['sub_department']),
            _buildDetailRow('Agent Name', _ticketData['agent_name']),
            _buildDetailRow('questionnaire', _ticketData['questionnaire']),
            _buildDetailRow('follow_up_question', _ticketData['follow_up_question']),
            SizedBox(height: 10),
            Divider(color: Colors.teal.shade200), // Divider for separation
            SizedBox(height: 10),
            _buildStatusChip('Status', _currentStatus), // Status chip
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String title, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0), // Reduced margin for closer rows
      decoration: BoxDecoration(
        color: Colors.teal.shade50, // Light background color for better visibility
        borderRadius: BorderRadius.circular(8.0), // Rounded corners
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2), // Subtle shadow for depth
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 2), // Changes the position of the shadow
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0), // Increased padding for comfort
        child: Row(
          children: [
            Expanded(
              flex: 2, // Allocate space proportionally for title
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.teal.shade600), // Icon for the title
                  SizedBox(width: 8), // Space between icon and text
                  Text(
                    '$title:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18, // Increased font size for title
                      color: Colors.teal.shade600, // Consistent color
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3, // Allocate more space for the value
              child: Text(
                value ?? 'N/A', // Default to 'N/A' if value is null
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87, // Darker color for better contrast
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String title, String status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0), // Increased vertical padding
      child: Row(
        children: [
          Text(
            '$title:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.teal.shade600, // Consistent teal color
            ),
          ),
          SizedBox(width: 10), // Space between title and chip
          Tooltip(
            message: 'Current ticket status: $status', // Tooltip message updated
            child: Chip(
              label: Text(
                status, // Use status parameter directly
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16, // Increased font size for better visibility
                  fontWeight: FontWeight.w500, // Slightly less bold for aesthetics
                ),
              ),
              backgroundColor: _getStatusColor(status), // Background color based on status
              elevation: 4, // Subtle shadow for depth
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Padding for chip
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12), // Rounded corners
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Open':
        return Colors.green;
      case 'In Progress':
        return Colors.orange;
      case 'Closed':
        return Colors.yellow;
      default:
        return Colors.grey; // Default color for unknown status
    }
  }

  Widget _buildMessageSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0), // Add padding for better spacing
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Messages',
            style: TextStyle(
              fontSize: 22, // Increased font size for better visibility
              fontWeight: FontWeight.bold,
              color: Colors.teal.shade800, // Darker shade for better contrast
            ),
          ),
          SizedBox(height: 12), // Increased spacing
          StreamBuilder<QuerySnapshot>(
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
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index].data() as Map<String, dynamic>;
                  return _buildMessageTile(message);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMessageTile(Map<String, dynamic> message) {
    // Replace 'userId' with the actual logic to get the current user's ID
    bool isSentByUser = message['sender'] == 'email'; // Replace 'userId' with your actual logged-in user ID.

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0), // Added padding for separation
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isSentByUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isSentByUser) // Display avatar only for other users
            CircleAvatar(
              backgroundColor: Colors.teal,
              child: Text(
                message['sender'][0].toUpperCase(),
                style: TextStyle(color: Colors.white),
              ),
            ),
          SizedBox(width: 10), // Space between avatar and message
          Flexible(
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSentByUser ? Colors.white : Colors.white70, // Color change based on sender
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment:
                isSentByUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // Sender and time
                  Row(
                    mainAxisAlignment: isSentByUser
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.spaceBetween,
                    children: [
                      if (!isSentByUser) // Display sender name for other users
                        Text(
                          message['sender'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.teal.shade800,
                          ),
                        ),
                      Text(
                        _formatTimestamp(message['timestamp']),
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),

                  // Cc section
                  if (message.containsKey('cc') && message['cc'].isNotEmpty)
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'cc: ',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                          TextSpan(
                            text: message['cc'], // Placeholder for cc names or user mentions
                            style: TextStyle(color: Colors.teal),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: 6),

                  // Main message content
                  Text(
                    message['message'] ?? 'No message',
                    style: TextStyle(
                      color: isSentByUser ? Colors.white : Colors.black, // Text color based on sender
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 6),

                  // Shipment numbers if any
                  if (message.containsKey('shipmentIds') && message['shipmentIds'].isNotEmpty)
                    Container(
                      padding: EdgeInsets.symmetric(vertical: 6.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: message['shipmentIds'].map<Widget>((id) {
                          return Text(
                            "#$id",
                            style: TextStyle(fontSize: 14, color: Colors.blueGrey),
                          );
                        }).toList(),
                      ),
                    ),

                  // Display image if imageUrl is present
                  if (message.containsKey('imageUrl') && message['imageUrl'] != '')
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FullScreenImage(imageUrl: message['imageUrl']),
                            ),
                          );
                        },
                        child: Image.network(
                          message['imageUrl'],
                          height: 200, // Adjust height as needed
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(child: CircularProgressIndicator());
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Text('Failed to load image');
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildReplySection() {
    return Card(
      elevation: 6.0, // Slightly increased elevation for a more pronounced effect
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), // More pronounced roundness
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0), // Increased padding around the card
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reply to Ticket',
              style: TextStyle(
                fontSize: 24, // Increased font size for better visibility
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            SizedBox(height: 16), // More spacing between title and fields
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Your Name',
                labelStyle: TextStyle(color: Colors.teal), // Change label color
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.teal), // Teal border
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.teal, width: 2), // Thicker teal border on focus
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey, width: 1), // Grey border
                ),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _replyController,
              maxLines: 4, // Allow more lines for reply
              decoration: InputDecoration(
                labelText: 'Your Reply',
                labelStyle: TextStyle(color: Colors.teal), // Change label color
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.teal), // Teal border
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.teal, width: 2), // Thicker teal border on focus
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey, width: 1), // Grey border
                ),
              ),
            ),
            SizedBox(height: 20), // More space before buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // Space out the buttons
              children: [
                ElevatedButton(
                  onPressed: () async {
                    // First, send the message
                    await _sendMessage(); // Call your send message logic here
                  },
                  child: Text('Send Reply'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal, // Changed to teal
                    padding: EdgeInsets.symmetric(vertical: 16, horizontal: 32), // Increased button padding
                    textStyle: TextStyle(fontSize: 18), // Increased font size for button text
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12), // Rounded button corners
                    ),
                  ),
                ),
                Tooltip(
                  message: 'Upload Photo', // Tooltip for the icon button
                  child: IconButton(
                    icon: Icon(Icons.photo),
                    color: Colors.teal,
                    onPressed: () async {
                      // Pick the image from gallery
                      await _pickImage(); // Call to pick image from gallery

                      // After the image is picked, upload it
                      if (_pickImage != null) {
                        await _uploadImage(); // Call to upload the image
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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

  Widget _buildReassignSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reassign Ticket',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.teal, // Keep this teal
          ),
        ),
        SizedBox(height: 10),
        DropdownButton<String>(
          value: _selectedUser,
          hint: Text('Select User'),
          onChanged: (newValue) {
            setState(() {
              _selectedUser = newValue; // Store the email of the selected user
            });
          },
          onTap: () {
            _initializeUserList(); // Populate _users when dropdown is opened
          },
          items: _users.isNotEmpty
              ? _users.map<DropdownMenuItem<String>>((user) {
            return DropdownMenuItem<String>(
              value: user['email'], // Save email as the value
              child: Text(
                user['name'], // Display name in the dropdown
                style: TextStyle(color: Colors.black), // Set text color to black
              ),
            );
          }).toList()
              : [
            DropdownMenuItem<String>(
              value: null,
              child: Text(
                'No users available',
                style: TextStyle(color: Colors.black), // Set fallback option text color to black
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        Tooltip(
          message: 'Reassign the ticket', // Tooltip message
          child: ElevatedButton(
            onPressed: () {
              _reassignTicket(); // Implement reassign functionality here
              if (_selectedUser != null) {
                print('Reassigning ticket to: $_selectedUser');
              } else {
                print('No user selected for reassignment.');
              }
            },
            child: Text(
              'Reassign Ticket',
              style: TextStyle(color: Colors.black), // Set button text color to black
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal, // Changed to teal
            ),
          ),
        ),
      ],
    );
  }



  Widget _buildBottomAppBar() {
    return BottomAppBar(
      elevation: 10,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Under Progress Button with Icon
            ElevatedButton.icon(
              onPressed: () {
                _updateTicketStatus('Under Progress');
              },
              icon: Icon(
                Icons.update, // Icon for under progress
                color: Colors.black,
              ),
              label: Text(
                'Under Progress',
                style: TextStyle(color: Colors.black),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
              ),
            ),
            // Close Ticket Button with Icon
            ElevatedButton.icon(
              onPressed: () {
                _updateTicketStatus('Closed');
              },
              icon: Icon(
                Icons.close, // Icon for closing the ticket
                color: Colors.black,
              ),
              label: Text(
                'Close Ticket',
                style: TextStyle(color: Colors.black),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
            ),
            // Show Support button only for Department Heads and Members
            if ((userRole == 'DepartmentHead' || userRole == 'Member') &&
                userDepartment != 'Admin' && userDepartment != 'Support')
              ElevatedButton.icon(
                onPressed: _openSupport, // Functionality for support button
                icon: Icon(
                  Icons.support_agent, // Support icon
                  color: Colors.black,
                ),
                label: Text(
                  'Support',
                  style: TextStyle(color: Colors.black),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                ),
              ),
          ],
        ),
      ),
    );
  }



  void _openSupport() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Support Options'),
          content: Text('Please select an option:'),
          actions: [
            TextButton(
              onPressed: () async {
                // Update the ticket in Firestore to route it to Support
                try {
                  await FirebaseFirestore.instance
                      .collection('tickets')
                      .doc(widget.ticketId) // Assuming widget.ticketId holds the ticket ID
                      .update({
                    'department': 'Support', // Reassign to Support department
                    'assignedTo': null, // Optionally, clear assigned user
                    'status': 'Reassigned to Support', // Update status
                  });

                  // Print log or perform additional logic if needed
                  print("Ticket reassigned to Support.");

                  // Remove the ticket from the user's screen by navigating back
                  Navigator.of(context).pop(); // Close the dialog
                  Navigator.of(context).pop(); // Navigate back to remove the ticket from view
                } catch (e) {
                  print("Failed to reassign ticket: $e");
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to submit request. Please try again.')),
                  );
                }
              },
              child: Text('Submit a Request'),
            ),
            TextButton(
              onPressed: () {
                print("FAQ opened");
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text('View FAQ'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
}
