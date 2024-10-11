import 'dart:io';
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';

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

bool _isEmojiVisible = false; // To track if the emoji picker is visible
FocusNode _focusNode = FocusNode(); // To handle keyboard focus

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
// Hide the emoji picker when the user starts typing
_focusNode.addListener(() {
if (_focusNode.hasFocus) {
setState(() {
_isEmojiVisible = false;
});
}
});
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
String ticketCreator = ticketData['agent_email'] ?? 'Unknown'; // Email of the user who created the ticket
String ticketQuestionnaire = ticketData['questionnaire'] ?? 'No questionnaire provided'; // Default message if null
String ticketFollowUpQuestion = ticketData['follow_up_question'] ?? 'No follow-up question provided'; // Default message if null

// Role-based filtering logic
if (userDepartment == 'Admin' || userDepartment == 'Support') {
// Admin and Support can view all tickets without restriction
setState(() {
_ticketData = ticketData;
_questionnaireController.text = ticketQuestionnaire; // Use null-safe value
_followUpQuestionController.text = ticketFollowUpQuestion; // Use null-safe value
_currentStatus = ticketData['status'] ?? 'Unknown'; // Default to 'Unknown' if status is null
_isLoading = false;
});
} else if (userRole == 'DepartmentHead') {
// Department Head can only see tickets for their department, tickets they created, or tickets assigned to them
if (userDepartment == ticketDepartment || ticketCreator == user.email || assignedTo == user.email) {
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
// Members can see only tickets assigned to them or tickets they created
if (assignedTo == user.email || ticketCreator == user.email) {
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

// Update status if the ticket is 'Open'
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

// If the current user is Admin or Support, only fetch Department Heads
if (userDepartment == 'Admin' || userDepartment == 'Support') {
usersSnapshot = await FirebaseFirestore.instance
    .collection('users')
    .where('role', isEqualTo: 'DepartmentHead') // Fetch only users with the role 'DepartmentHead'
    .get();

// After fetching, filter out users with the role 'Admin' or 'Support'
setState(() {
_users = usersSnapshot.docs.map((doc) {
final userData = doc.data() as Map<String, dynamic>;
// Filter out 'Admin' and 'Support' users
if (userData['department'] != 'Admin' && userData['department'] != 'Support') {
return {
'name': userData['name'],
'email': userData['email'],
};
}
return null;
}).where((user) => user != null).cast<Map<String, dynamic>>().toList();
});
} else if (userRole == 'DepartmentHead') {
// Fetch all users in the same department for Department Heads
usersSnapshot = await FirebaseFirestore.instance
    .collection('users')
    .where('department', isEqualTo: userDepartment)
    .get();

// Populate the _users list with the fetched data
setState(() {
_users = usersSnapshot.docs.map((doc) {
final userData = doc.data() as Map<String, dynamic>;
return {
'name': userData['name'],
'email': userData['email'],
};
}).cast<Map<String, dynamic>>().toList();
});
} else {
// If the user is a member, they should not see any dropdown options
setState(() {
_users = []; // No users available for members
});
return;
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
backgroundColor: Colors.white38,
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
            Center(
              child: Text(
                'TICKET ID : ${widget.ticketId}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal.shade800,
                ),
              ),
            ),
            Divider(thickness: 1.5),
            _buildDetailSectionTitle('Ticket Id Details'),
            _buildDetailsTable(),
            SizedBox(height: 20),
            _buildStatusRow(),
          ],
        ),
      ),
    );
  }

// Function to build the table of ticket details
  Widget _buildDetailsTable() {
    return Table(
      columnWidths: {
        0: FlexColumnWidth(3), // Title column takes up 3 parts
        1: FlexColumnWidth(4), // Value column takes up 4 parts
      },
      border: TableBorder(
        horizontalInside: BorderSide(
          width: 1,
          color: Colors.grey.shade300, // Light grey for the horizontal border
        ),
      ),
      children: [
        _buildTableRow('Agent Name', _ticketData?['agent_name']),
        _buildTableRow('Agent Email', _ticketData?['agent_email']),
        _buildTableRow('Subject', _ticketData?['subject']),
        _buildTableRow('Description', _ticketData?['description']),
        _buildTableRow('Department', _ticketData?['department']),
        _buildTableRow('Questionnaire', _ticketData?['questionnaire']),
        _buildTableRow('Followup Question', _ticketData?['follow_up_question']),
      ],
    );
  }

// Function to create each row in the table
  TableRow _buildTableRow(String title, String? value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            '$title :',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.teal.shade800,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            value ?? 'N/A',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

// Function to display status row with a colored chip
  Widget _buildStatusRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'STATUS',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.teal.shade800,
            fontSize: 16,
          ),
        ),
        Chip(
          label: Text(
            _currentStatus.toUpperCase(),
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: _getStatusColor(),
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        ),
      ],
    );
  }

// Helper to dynamically color status chip
  Color _getStatusColor() {
    switch (_currentStatus) {
      case 'In Progress':
        return Colors.blueAccent;
      case 'Under Progress':
        return Colors.green;
      case 'Reassigned':
        return Colors.lime;
      case 'Closed':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }


// Helper to create the section title, as in the screenshot
  Widget _buildDetailSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.teal.shade600,
        ),
      ),
    );
  }




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
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.blue, // Blue header background
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundImage: AssetImage('assets/images/chat_support.webp'), // Use AssetImage for local image
                    radius: 25,
                  ),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chat Bot',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Welcome to sahayog!',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  Spacer(),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: Colors.grey.shade300),

            // Scrollable area for both ticket details and messages
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('tickets')
                    .doc(widget.ticketId)
                    .collection('messages')
                    .orderBy('timestamp', descending: false) // Sorting by timestamp (oldest to newest)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }

                  final messages = snapshot.data!.docs;

                  // Combine ticket details with chat messages in the same ListView
                  return ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: messages.length + 1, // Add 1 for the ticket details
                    itemBuilder: (context, index) {
                      // Show ticket details at the top (first item)
                      if (index == 0) {
                        return _ticketData != null
                            ? _buildTicketCreationDetails(_ticketData!)
                            : SizedBox.shrink();
                      }
                      // Show chat messages below the ticket details
                      final message = messages[index - 1].data() as Map<String, dynamic>;
                      return _buildChatBubble(message);
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


// Function to display the ticket creation details (subject, description, image) at the top of the chat
Widget _buildTicketCreationDetails(Map<String, dynamic> ticketData) {
return Container(
margin: EdgeInsets.symmetric(vertical: 5),
padding: EdgeInsets.all(10),
decoration: BoxDecoration(
color: Colors.grey.shade200,
borderRadius: BorderRadius.circular(10),
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
// Show subject if available
if (ticketData['subject'] != null && ticketData['subject'].isNotEmpty)
Text(
'Subject: ${ticketData['subject']}',
style: TextStyle(
fontWeight: FontWeight.bold,
color: Colors.black,
),
),
SizedBox(height: 5),

// Show description if available
if (ticketData['description'] != null && ticketData['description'].isNotEmpty)
Text(
'Description: ${ticketData['description']}',
style: TextStyle(color: Colors.black),
),
SizedBox(height: 5),

// Show image if available
if (ticketData['image_url'] != null && ticketData['image_url'].isNotEmpty)
GestureDetector(
onTap: () {
Navigator.push(
context,
MaterialPageRoute(
builder: (context) => FullScreenImage(
imageUrl: ticketData['image_url'],
),
),
);
},
child: Image.network(
ticketData['image_url'],
height: 200, // Adjust as needed
width: 200,
fit: BoxFit.cover,
),
),
],
),
);
}


Widget _buildChatBubble(Map<String, dynamic> message) {
bool isMe = message['sender'] == FirebaseAuth.instance.currentUser?.email;

// Extract timestamp and handle null case
Timestamp? timestamp = message['timestamp'];
String formattedTime = '';

// Check if timestamp is not null, then format it
if (timestamp != null) {
DateTime dateTime = timestamp.toDate(); // Convert Firestore Timestamp to DateTime
formattedTime = DateFormat('hh:mm a').format(dateTime); // Format the time as hh:mm AM/PM
} else {
formattedTime = 'No time available'; // Placeholder for missing timestamps
}

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
crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
children: [
// Display the sender's email or 'System' for the image_url
Text(
message['name'] ?? 'Unknown name',
style: TextStyle(
fontWeight: FontWeight.bold,
color: isMe ? Colors.white : Colors.black,
),
),
SizedBox(height: 5), // Spacing between sender and message

// Show the message text, if available
if (message['message'] != null && message['message'].isNotEmpty)
Text(
message['message'],
style: TextStyle(
color: isMe ? Colors.white : Colors.black,
),
),
SizedBox(height: 5),

// Display the image if the imageUrl is available
if (message['imageUrl'] != null && message['imageUrl'].isNotEmpty)
GestureDetector(
onTap: () {
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
width: 200,
fit: BoxFit.cover,
),
),
SizedBox(height: 5),

// Display the time below the message
Text(
formattedTime, // Show formatted time
style: TextStyle(
fontSize: 12,
color: isMe ? Colors.white70 : Colors.black54,
),
),
],
),
),
);
}

// Input section with send message functionality
Widget _buildMessageInputSection() {
return Column(
children: [
Card(
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

// Emoji Icon
IconButton(
icon: Icon(Icons.emoji_emotions, color: Colors.teal.shade800),
onPressed: () {
setState(() {
_isEmojiVisible = !_isEmojiVisible; // Toggle emoji visibility
if (_isEmojiVisible) {
FocusScope.of(context).unfocus(); // Hide the keyboard if the emoji picker is opened
} else {
_focusNode.requestFocus(); // Bring back the keyboard if emoji picker is closed
}
});
},
),
SizedBox(width: 10),

// Text Input for message
Expanded(
child: TextField(
controller: _replyController,
focusNode: _focusNode, // Assign the focus node to the text field
decoration: InputDecoration(
hintText: 'Enter Your Message...',
border: InputBorder.none,
),

  // Handle pressing the Enter key
  onSubmitted: (value) async {
    if (value.isNotEmpty || _image != null) {
      await _sendMessage(); // Reuse the same logic for sending the message
    }
  },
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
),

// Emoji picker widget
Offstage(
offstage: !_isEmojiVisible, // Show/Hide based on _isEmojiVisible
child: SizedBox(
height: 250,
child: EmojiPicker(
onEmojiSelected: (category, emoji) {
_replyController.text += emoji.emoji; // Add the selected emoji to the text field
},
config: Config(
columns: 7,
emojiSizeMax: 32.0, // Adjust emoji size
verticalSpacing: 0,
horizontalSpacing: 0,
initCategory: Category.SMILEYS,
bgColor: const Color(0xFFF2F2F2),
indicatorColor: Colors.teal.shade800,
iconColor: Colors.grey,
iconColorSelected: Colors.teal.shade800,
backspaceColor: Colors.teal.shade800,
),
),
),
),
],
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

  // Fetch the user's name from Firestore using their email
  DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.email)
      .get();

  String userName = userSnapshot.exists ? userSnapshot['name'] : 'Unknown User'; // Use 'name' field or default to 'Unknown User'

// Ensure the reply field is not empty
if (_replyController.text.isNotEmpty || _image != null) {
String? downloadUrl; // This will store the image URL if an image is uploaded

// Upload the image if one has been selected
if (_image != null) {
downloadUrl = await _uploadImage(); // Upload image and get the download URL
}
// Include the subject and description from the ticket
String subject = _ticketData?['subject'] ?? 'No subject';
String description = _ticketData?['description'] ?? 'No description';

// Send the reply message along with the image URL (if any)
await FirebaseFirestore.instance
    .collection('tickets')
    .doc(widget.ticketId)
    .collection('messages')
    .add({
'sender': user.email, // Send the email of the logged-in user
  'name': userName,
  'message': _replyController.text,
'timestamp': FieldValue.serverTimestamp(),
'imageUrl': downloadUrl ?? '', // Include the image URL if an image was uploaded
'questionnaire': questionnaireText,
'follow_up_question': followUpQuestionText,
'image_url': TicketdownloadUrl ?? '',
'subject': subject, // Include subject
'description': description, // Include description
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
// Reassign Ticket button
TextButton.icon(
onPressed: () async {
await _reassignTicket(); // Trigger the reassignment when the button is clicked
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
child: Text('${user['name']}'),
);
}).toList(),
onChanged: (value) {
setState(() {
_selectedUser = value; // Update the selected user
});
},
value: _selectedUser, // Show selected value in dropdown
),

// Support Icon (Visible to everyone except Admin and Support)
if (userDepartment != 'Admin' && userDepartment != 'Support')   // Ensure it's hidden only for Admin and Support

  GestureDetector(
    onTap: () {
      _showRouteToSupportDialog();  // Show dialog when icon is clicked
    },
    child: Icon(
      Icons.support_agent, // Icon for support
      color: Colors.teal.shade800, // Match the icon color with the theme
      size: 30, // Adjust size if needed
    ),
  ),

// Under Progress button
ElevatedButton(
onPressed: () async {
await _updateTicketStatus('Under Progress'); // Update the status to 'Under Progress'
},
style: ElevatedButton.styleFrom(
backgroundColor: Colors.white38, // Button background color matching the theme
),
child: Text(
'Under Progress',
style: TextStyle(color: Colors.black),
),
),

// Close button (Visible only to Admin and Support)
if (userDepartment == 'Admin' || userDepartment == 'Support') // Visible only for Admin and Support
ElevatedButton(
onPressed: () async {
await _updateTicketStatus('Closed'); // Update the status to 'Close'
},
style: ElevatedButton.styleFrom(
backgroundColor: Colors.white38, // Button background color matching the theme
),
child: Text(
'Closed',
style: TextStyle(color: Colors.black),
),
),
],
),
);
}

// Method to show the dialog
  void _showRouteToSupportDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Route to Support'),
          content: Text('Do you really want to route this ticket to support?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();  // Close dialog if "No" is pressed
              },
              child: Text('No'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();  // Close dialog before reassigning ticket
                await _assignTicketToSupport();  // Reassign ticket to support
                Navigator.pop(context);  // Remove the ticket from the screen
              },
              child: Text('Yes'),
            ),
          ],
        );
      },
    );
  }

// Method to assign the ticket to Support
Future<void> _assignTicketToSupport() async {
try {
await FirebaseFirestore.instance
    .collection('tickets')
    .doc(widget.ticketId)
    .update({
'assignedTo': 'support@company.com', // Assign to the support team's email
'status': 'Reassigned to Support',
});

ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text('Ticket successfully reassigned to Support.')),
);

// Refresh the ticket list to remove the reassigned ticket from the user's screen
await _fetchTicketData();  // Refresh the ticket list after reassigning
  // Navigate back to the ticket list screen if needed
  Navigator.pop(context);  // Close the ticket detail screen
} catch (error) {
print('Error reassigning to support: $error');
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text('Failed to reassign the ticket to Support.')),
);
}
}


}