import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Firebase Auth for user info
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'TicketListScreen.dart';

class AddTicketScreen extends StatefulWidget {
  @override
  _AddTicketScreenState createState() => _AddTicketScreenState();
}

class _AddTicketScreenState extends State<AddTicketScreen> {
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _agentNameController = TextEditingController(); // For agent name (auto-filled)
  final TextEditingController _agentEmailController = TextEditingController();
  String _selectedQuestionnaire = ''; // Independent questionnaire value
  String _selectedFollowUpQuestion = ''; // Follow-up question value
  String _selectedDepartment = ''; // Auto-selected department based on questionnaire
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _questionnaireError; // Error message for questionnaire validation
  String? _followUpQuestionError; // Error message for follow-up question validation

  PlatformFile? _selectedImageFile; // Store the selected image
  String? _uploadedImageUrl; // Store the uploaded image URL
  PlatformFile? _image;

  List<dynamic> _questionnaireOptions =[];
   Map<String, String> _questionnaireToDepartment = {};
  Map<String, List<dynamic>> _followUpQuestions = {};


  @override
  void initState() {
    super.initState();
    _fetchUserDetails(); // Fetch logged-in user details on initialization
    _fetchQuestionnaireData();
  }

  // Fetch questionnaire, follow-up questions, and departments from Firestore
  Future<void> _fetchQuestionnaireData() async {
    try {
      // Fetch the followUpQuestions document
      final questionnaireOptions = await _firestore.collection('questions').doc('questionnaireOptions').get();
      final followUpQuestionsSnapshot = await _firestore.collection('questions').doc('followUpQuestions').get();
      final questionnaireToDepartmentSnapshot = await _firestore.collection('questions').doc('questionnaireToDepartment').get();

      if (followUpQuestionsSnapshot.exists && followUpQuestionsSnapshot.data() != null) {
        // Safely cast each field's value to List<dynamic>
        Map<String, List<dynamic>> followUpQuestionsMap = {};

        followUpQuestionsSnapshot.data()!.forEach((key, value) {
          followUpQuestionsMap[key] = List<dynamic>.from(value); // Cast each value to List<dynamic>
        });

        // Print the follow-up questions for debugging
        print("Follow-up Questions: ${followUpQuestionsMap.toString()}");

        // Update the state with the fetched follow-up questions
        setState(() {

          _questionnaireOptions = questionnaireOptions.data()?['questionnaireOptions'];
          _followUpQuestions = followUpQuestionsMap;
          _questionnaireToDepartment = Map<String, String>.from(questionnaireToDepartmentSnapshot.data() ?? {});
        });
      } else {
        print("No follow-up questions found.");
      }
    } catch (e) {
      print('Error fetching follow-up questions data: $e');
    }
  }


  Future<void> _fetchUserDetails() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.email)
            .get();

        if (userDoc.exists) {
          setState(() {
            _agentNameController.text = userDoc['name'] ?? 'Unknown User';
            _agentEmailController.text = userDoc['email'] ?? 'Unknown User';
          });
        }
      }
    } catch (e) {
      print('Error fetching user details: $e');
    }
  }

  Future<void> addTicket() async {
    if (_validateForm()) {
      final newTicketId = await generateTicketID();
      final DateTime now = DateTime.now();
      final Duration timelineDuration = _getTimelineDuration(_selectedQuestionnaire);

      if (_selectedImageFile != null) {
        _uploadedImageUrl = await _uploadImage(_selectedImageFile!);
      }

      if (_subjectController.text.isNotEmpty) {
        await FirebaseFirestore.instance.collection('tickets').doc(newTicketId).set({
          'subject': _subjectController.text,
          'description': _descriptionController.text,
          'questionnaire': _selectedQuestionnaire,
          'follow_up_question': _selectedFollowUpQuestion,
          'department': _selectedDepartment, // Auto-selected department
          'agent_name': _agentNameController.text,
          'agent_email': _agentEmailController.text,
          'status': 'Open',
          'date_created': Timestamp.now(),
          'ticketId': newTicketId,
          'timeline_start': Timestamp.now(),
          'timeline_duration': timelineDuration.inSeconds,
          'image_url': _uploadedImageUrl ?? '',
        });

        // Show success dialog
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Success'),
              content: Text('Ticket is being submitted.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close the dialog
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => TicketListScreen()), // Replace with your ticket list screen
                    );
                  },
                  child: Text('OK'),
                ),
              ],
            );
          },
        );

        setState(() {
          _subjectController.clear();
          _descriptionController.clear();
          _selectedQuestionnaire = '';
          _selectedFollowUpQuestion = '';
          _questionnaireError = null;
          _followUpQuestionError = null;
          _selectedImageFile = null;
          _uploadedImageUrl = null;
          _selectedDepartment = ''; // Clear auto-selected department
        });
      }
    }
  }

  Future<void> _pickImage() async {
    if (_image != null) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final pickedFile = result.files.first;
        final bytes = pickedFile.bytes;
        if (bytes != null) {
          setState(() {
            _image = pickedFile;
            _selectedImageFile = pickedFile;
          });
        }
      }
    } catch (e) {
      print("Error picking image: ${e.toString()}");
    }
  }

  Future<String?> _uploadImage(PlatformFile pickedFile) async {
    try {
      if (pickedFile.bytes == null) return null;

      final storageRef = FirebaseStorage.instance.ref().child('images/${pickedFile.name}');
      UploadTask uploadTask = storageRef.putData(pickedFile.bytes!);

      TaskSnapshot snapshot = await uploadTask.whenComplete(() {});
      String TicketdownloadUrl = await snapshot.ref.getDownloadURL();
      return TicketdownloadUrl;
    } catch (e) {
      print("Error uploading image: $e");
      return null;
    }
  }

  Duration _getTimelineDuration(String questionnaire) {
    // Define durations for each questionnaire option
    switch (questionnaire) {
      case 'Invoice':
      case 'Order ID is not visible to me in the sales app':
      case 'Sales app not working':
      case 'Call not sync in sales app':
      case 'Customer not showing in sales app':
      case 'Interact not working':
      case 'Kylas related':
      case 'Order confirmation':
      case 'Invoice correction ':
      case 'Sales sheet not working':
      case 'Order ID is not visible in sales sheet ':
      case 'Add P number in price confirmation sheet':
      case 'Price confirmation entries are not visible to support':
      case 'Template related':
      case 'Need tracking link':
      case 'Order not confirmed':
      case 'Order details Update':
        return Duration(hours: 2); // 2-hour timeline
      case 'Order is verified':
      case 'Packaging Image before dispatch':
      case 'Customer is not getting any call for delivery':
      case 'Delivery boy asked for OTP':
      case 'Need Hub address':
      case 'Delivery boy asked to come far away from delivery location':
      case 'Tracking is showing out for delivery but order is not getting delivered ':
      case 'Tracking is showing arriving today but customer is not getting any call':
      case 'Need to update customer mobile number':
      case 'Need to update payment mode':
      case 'Order is miss routed':
      case 'Not Attempted, marked in RTO ':
      case 'Sales app showing incorrect Data':
      case 'Lead requirement Related':
      case 'Website issue':
      case 'Pricing related':
      case 'Other Issue':
      case 'Documents if any':
      case 'Micro dealer statement':
      case 'Price related ':
      case 'Document Related':
        return Duration(hours: 24); // 24-hour timeline
      case 'Order cancellation':
      case'Unable to place orders':
      case'Order is confirmed not booked':
      case'Pin Code not serviceable':
        return Duration(hours: 1);// 1-hour timeline
      case'Product Availability confirmation':
      case'Product photo requirement for sales':
      case'Customised confirmation such as MRP, packaging Type':
      case'Micro dealership related':
      case'Banner & Labels':
      case'App task and others ':
      case'Need material or packaging image':
        return Duration(hours: 4);
      default:
        return Duration(hours: 2); // Default 2-hour for "Others"
    }
  }


  Future<String> generateTicketID() async {
    try {
      final snapshot = await _firestore.collection('tickets').orderBy('ticketId').get();
      int newId = snapshot.docs.isNotEmpty
          ? int.parse(snapshot.docs.last['ticketId'].split('-')[1]) + 1
          : 1001;
      return 'KO-$newId';
    } catch (e) {
      print('Error generating ticket ID: $e');
      throw e;
    }
  }

  bool _validateForm() {
    bool isValid = true;

    if (_selectedQuestionnaire.isEmpty) {
      setState(() {
        _questionnaireError = 'Please select a questionnaire option';
      });
      isValid = false;
    } else {
      setState(() {
        _questionnaireError = null;
      });
    }

    if (_followUpQuestions.containsKey(_selectedQuestionnaire) &&
        _selectedFollowUpQuestion.isEmpty) {
      setState(() {
        _followUpQuestionError = 'Please select a follow-up question';
      });
      isValid = false;
    } else {
      setState(() {
        _followUpQuestionError = null;
      });
    }

    return isValid;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Ticket', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false, // This removes the back button
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildOwnerSection(),
            SizedBox(height: 16),
            Divider(thickness: 1),
            _buildTicketInfoSection(),
            SizedBox(height: 16),
            SizedBox(height: 16),
            _buildButtons(context),
          ],
        ),
      ),
    );
  }


  Widget _buildOwnerSection() {
    return _buildCard(
      title: 'Ticket Owner',
      content: Column(
        children: [
          _buildTextField('Agent Name *', _agentNameController, 'Enter Agent Name', enabled: false),
          SizedBox(height: 16),
          _buildTextField('Agent Email *', _agentEmailController, 'Enter Agent Email', enabled: false),
        ],
      ),
    );
  }

  Widget _buildCard({required String title, required Widget content}) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.70, // Set width to 70% of the screen
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95), // Slightly increase opacity for better visibility
        borderRadius: BorderRadius.circular(15), // Rounded corners
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5), // Stronger shadow
            spreadRadius: 5, // Increase spread radius for the shadow effect
            blurRadius: 15, // More blur for softer shadow
            offset: Offset(0, 8), // Vertical offset for more depth
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 16), // Padding under the title for clean separation
            child: Text(
              title,
              style: TextStyle(
                fontSize: 20, // Slightly larger font for the title
                fontWeight: FontWeight.bold,
                color: Colors.teal.shade800,
                height: 1.5, // Increased line height for better readability
              ),
            ),
          ),
          content,
        ],
      ),
    );
  }


  Widget _buildTicketInfoSection() {
    return _buildCard(
      title: 'Ticket Information',
      content: Column(
        children: [
          _buildQuestionnaireDropdown(),  // Moved to the top
          if (_followUpQuestions.containsKey(_selectedQuestionnaire)) ...[
            SizedBox(height: 16),
            _buildFollowUpQuestionDropdown(),  // Moved to the top
          ],
          SizedBox(height: 16),
          _buildTextField('Subject *', _subjectController, 'Enter Subject'),  // Moved down
          SizedBox(height: 16),
          _buildDescriptionField(),  // Moved down
        ],
      ),
    );
  }



  Future<void> _addImageUrlToDescription() async {
    if (_descriptionController.text.isNotEmpty) {
      String? downloadUrl;

      if (_selectedImageFile != null) {
        downloadUrl = await _uploadImage(_selectedImageFile!);

        if (downloadUrl != null) {
          setState(() {
            _uploadedImageUrl = downloadUrl;
          });
        }
      }
    }
  }

  Widget _buildQuestionnaireDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Questionnaire', style: TextStyle(fontWeight: FontWeight.w500)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          decoration: BoxDecoration(
            color: Color(0xFFF7F5F2), // Matching the light beige background
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButton<dynamic>(
            value: _selectedQuestionnaire.isNotEmpty ? _selectedQuestionnaire : null,
            hint: Text('Select Questionnaire'),
            isExpanded: true, // Ensures the dropdown takes up full width
            underline: SizedBox(), // Removes the default underline
            icon: Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF5B4636)), // Modern icon
            onChanged: (dynamic? newValue) {
              setState(() {
                _selectedQuestionnaire = newValue!;
                _selectedDepartment = _questionnaireToDepartment[_selectedQuestionnaire] ?? 'Unknown';
                _selectedFollowUpQuestion = ''; // Reset follow-up question when questionnaire changes
              });
            },
            items: _questionnaireOptions.map<DropdownMenuItem<dynamic>>((dynamic value) {
              return DropdownMenuItem<dynamic>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          ),
        ),
        if (_questionnaireError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              _questionnaireError!,
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildFollowUpQuestionDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedQuestionnaire.isNotEmpty && _followUpQuestions.containsKey(_selectedQuestionnaire)) ...[
          SizedBox(height: 16),
          Text('Follow-up Question', style: TextStyle(fontWeight: FontWeight.w500)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            decoration: BoxDecoration(
              color: Color(0xFFF7F5F2), // Matching the light beige background
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButton<String>(
              value: _selectedFollowUpQuestion.isNotEmpty ? _selectedFollowUpQuestion : null,
              hint: Text('Select Follow-up Question'),
              isExpanded: true, // Ensures the dropdown takes up full width
              underline: SizedBox(), // Removes the default underline
              icon: Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF5B4636)), // Modern icon
              onChanged: (String? newValue) {
                setState(() {
                  _selectedFollowUpQuestion = newValue!;
                });
              },
              items: _followUpQuestions[_selectedQuestionnaire]!
                  .map<DropdownMenuItem<String>>((dynamic value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ),
        ],
        if (_followUpQuestionError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              _followUpQuestionError!,
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }

  // Helper function to trigger ticket submission
  void _triggerSubmit() {
    addTicket();  // Add your ticket submission logic here
  }

  Widget _buildTextField(String label, TextEditingController controller, String hintText, {bool enabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.w500)),
        TextField(
          controller: controller,
          enabled: enabled,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey.shade200,
            hintText: hintText,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (value) {
            _triggerSubmit();  // Submit form when "Enter" is pressed
          },
        ),
      ],
    );
  }
  // Function to lock the "Image Attached" text
  void _lockImageText() {
    // If the user tries to modify the "Image Attached" text, restore it
    final imageText = '[Image Attached]';
    if (_descriptionController.text.contains(imageText)) {
      final lastIndex = _descriptionController.text.indexOf(imageText);
      if (lastIndex != _descriptionController.selection.baseOffset) {
        // Reset the text to maintain the [Image Attached] marker
        _descriptionController.value = _descriptionController.value.copyWith(
          text: _descriptionController.text,
          selection: TextSelection.fromPosition(
            TextPosition(offset: _descriptionController.text.length),
          ),
        );
      }
    }
  }

  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Description', style: TextStyle(fontWeight: FontWeight.w500)),
        TextField(
          controller: _descriptionController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Enter Description',
            border: OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(Icons.screenshot),
              onPressed: () async {
                await _pickImage();
                if (_selectedImageFile != null) {
                  setState(() {
                    // Add a marker text indicating the image is attached
                    if (!_descriptionController.text.contains('[Image Attached]')) {
                      _descriptionController.text += "\n[Image Attached]";
                    }
                  });
                }
                await _addImageUrlToDescription();
              },
            ),
          ),
          onSubmitted: (value) {
            _triggerSubmit(); // Submit form when "Enter" is pressed
          },
        ),
        // Display the selected image if any
        if (_selectedImageFile != null)
          Column(
            children: [
              SizedBox(height: 10),
              Text(
                'Image Picked:',
                style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
              ),
              SizedBox(height: 5),
              Image.memory(
                _selectedImageFile!.bytes!, // Display the image bytes
                height: 100,
                width: 100,
                fit: BoxFit.cover,
              ),
              SizedBox(height: 10),
            ],
          ),
      ],
    );
  }

  Widget _buildButtons(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {
        _triggerSubmit();
      },
      icon: Icon(
        Icons.send_rounded,  // Use a more modern icon
        color: Colors.white,
      ),
      label: Text(
        'Submit',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 32),  // Increase padding for a modern look
        backgroundColor:  Colors.blueAccent,  // The brownish color for the button background
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),  // Increased rounding for a modern look
        ),
        elevation: 5,  // Add slight elevation for a 3D effect
        shadowColor: Colors.black26,  // Subtle shadow
      ),
    );
  }

  @override
  void dispose() {
    _descriptionController.removeListener(_lockImageText); // Remove listener to avoid memory leaks
    _descriptionController.dispose();
    super.dispose();
  }

}
