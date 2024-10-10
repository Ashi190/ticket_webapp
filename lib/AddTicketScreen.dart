import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Firebase Auth for user info
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.blue,
        textTheme: TextTheme(
          bodyMedium: TextStyle(fontSize: 16, color: Colors.black87),
        ),
      ),
      home: AddTicketScreen(),
    );
  }
}

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

  final  List<String> _questionnaireOptions = [

      'Order ID',
      'Order placed date',
      'Order Stage',
      'Regarding order confirmation',
      'Order booking & tracking link',
      'Regarding order Dispatch',
      'Delivery related Issue',
      'Lead requirement Related',
      'Interact not working',
      'Micro dealership related',
      'Kylas related',
      'Banner & Labels',
      'Website issue',
      'Pricing related',
      'Template related',
      'App task and others',
      ' Order ID is not visible to me in the sales app',
      'Share any other information such as customer name , number, products',
      ' Sales app not working',
      'Call not sync in sales app',
      ' Unable to place orders',
      ' Sales app showing incorrect Data',
      ' Customer not showing in sales app',
      'Invoice',
      'Order confirmation',
      'Invoice correction',
      'Documents if any',
      'Micro dealer statement',
      'Sales sheet not working',
      'Order ID is not visible in sales sheet',
      'Add P number in price confirmation sheet',
      'Price confirmation entries are not visible to support',
      'Price related',
      'Need material or packaging image',
      'Special price confirmation',
      'Order cancellation',
      'Document Related',
      'Lead follow-up',
      'New customer acquisition',
      'others',
  ];

  // Map to automatically select department based on the selected questionnaire
  final Map<String, String> _questionnaireToDepartment = {
    'Order ID': 'Dispatch',
    'Order placed date':'Dispatch',
    'Order Stage':'Dispatch',
    'Regarding order confirmation':'Dispatch',
    'Order booking & tracking link':'Dispatch',
    'Regarding order Dispatch':'Dispatch',
    'Delivery related Issue':'Dispatch',
    'Lead requirement Related':'Marketing',
    'Interact not working':'Marketing',
    'Micro dealership related':'Marketing',
    'Kylas related':'Marketing',
    'Banner & Labels':'Marketing',
    'Website issue':'Marketing',
    'Pricing related':'Marketing',
    'Template related':'Marketing',
    'App task and others':'Marketing',
    ' Order ID is not visible to me in the sales app':'Development',
    'Share any other information such as customer name , number, products':'Development',
    ' Sales app not working':'Development',
    'Call not sync in sales app':'Development',
    ' Unable to place orders':'Development',
    ' Sales app showing incorrect Data':'Development',
    ' Customer not showing in sales app':'Development',
    'Invoice':'Accounts',
    'Order confirmation':'Accounts',
    'Invoice correction':'Accounts',
    'Documents if any':'Accounts',
    'Micro dealer statement':'Accounts',
    'Sales sheet not working':'BA',
    'Order ID is not visible in sales sheet':'BA',
    'Add P number in price confirmation sheet':'BA',
    'Price confirmation entries are not visible to support':'BA',
    'Price related':'BA',
    'Need material or packaging image':'Support',
    'Special price confirmation':'Support',
    'Order cancellation':'Support',
    'Document Related':'Support',
    'Lead follow-up':'Sales',
    'New customer acquisition':'Sales',
    'others':'Sales',
  };

  // Load the follow-up questions for a particular main question
  Map<String, List<String>> _followUpQuestions = {
    'Regarding order confirmation': [
      'Order not confirmed',
      'Product Availability confirmation',
      'Order is verified',
      'Customised confirmation',
      'Others',
    ],
    'Order booking & tracking link': [
      'Need tracking link',
      'Order confirmed but not booked ',
      'Pin Code not serviceable',
      'Others',
    ],
    'Regarding order Dispatch': [
      'When will my order be dispatched?',
      'Others',
    ],

    'Delivery related Issue': [
      'Order dispatched date (select date)',
      'Customer not getting any call for delivery ',
      'Delivery boy asked for OTP ',
      'Tracking shows out for delivery but order not delivered',
      'Others',
    ],

    // Development
    'Order ID is not visible to me in the sales app': [
      ' the order is recently placed',
      ' you have tried refreshing or syncing the sales app',
      ' the order is visible on other platforms (e.g., web, admin panel)',
      ' the order go through successfully or is it still pending',
      ' you are using the correct filter/search options for Order ID',
      ' there are error message or warning related to the missing order',
      ' there have  been any recent updates or changes to the sales app',
      'Others',
    ],
    'Share any other information such as customer name, number, products': [
      ' the customer new or existing',
      ' the customer’s contact information up-to-date',
      ' you have the correct customer ID or reference number',
      ' there are any specific product details or issues to share',
      ' the customer is waiting for product delivery or support',
      'the customer is facing any technical issues while accessing product information',
      ' you have the order number related to the customer’s query',
      'there are any issues with the customer’s contact preferences (SMS, call, email)',
      ' you have tried reaching the customer multiple times without success',
      'Others',
    ],
    'Sales app not working': [
      'the app is crashing immediately or freezing on a specific screen',
      'you recently updated the app',
      'there is an error message when the app stops working',
      'you tried reinstalling the app',
      'other users are facing the same issue',
      'the app fail to load or get stuck during login',
      'you tried clearing the app cache or data',
      'other apps are on your device working correctly',
      'last action you performed before the app stopped working',
      'Others',
    ],
    'Call not sync in sales app': [
      'the issue is affecting all calls or specific ones',
      'you checked your internet connection during the sync',
      'the sales app is updated to the latest version',
      'other features are of the app syncing correctly',
      'you cleared the app cache or data recently',
      'there is any error message shown during the sync process',
      'you tried logging out and logging back into the app',
      'calls are recorded correctly, but not syncing to the server',
      'other users are facing the same issue',
      'Others',
    ],
    'Unable to place orders': [
      'there an error message when trying to place the order',
      'you tried placing an order with different products or customers',
      'the app crash or freeze during the order placement process',
      'your internet connection is stable while placing the order',
      'you were able to successfully place orders before',
      'the payment section is not working or getting stuck',
      'the issue is happening with specific products or all products',
      'there is a delay in adding products to the cart',
      'other users are able to place orders using the app',
      'Others',
    ],
    'Sales app showing incorrect Data': [
      'specific data appears to be incorrect',
      'the data is showing outdated information or wrong values',
      'the issue is happening only with certain customers or products',
      'the app has been synced recently to fetch new data',
      'refreshing or reloading the data resolve the issue',
      'there have been any recent changes in the product/customer database',
      'other users are facing the same issue',
      'you tried logging out and logging back in to refresh the data',
      'the incorrect data is appearing across all sections or only in a specific one',
      'Others',
    ],
    'Customer not showing in sales app': [
      'this is a new customer or an existing one',
      'the customer’s data been synced to the app',
      'other customers are showing correctly in the app',
      'the customer recently registered or updated their details',
      'the app been synced recently to pull new customer data',
      'refreshing or reloading the customer list resolve the issue',
      'the customer is missing only in a specific section of the app',
      'other users are experiencing the same issue with missing customers',
      'you tried searching the customer by ID or contact number',
      'Others',
    ],
    // Marketing
    'Lead requirement Related': [
      'type of leads are you looking for (e.g., industry, region)',
      'these are leads for a specific campaign or product',
      'you have a target number of leads in mind',
      'there is any specific timeframe for generating these leads',
      'there are specific criteria (e.g., job title, company size) for the leads',
      'this is request for B2B or B2C leads',
      'you need cold leads or nurtured leads',
      'Others',
    ],
    'Interact not working': [
      'the issue is with the entire platform or a specific feature',
      'the issue start after a recent update',
      'you tried clearing your cache or refreshing the page',
      'other team members are experiencing the same issue',
      'the platform display an error message',
      'there is a delay or is it completely unresponsive',
      'you tried accessing the platform from a different device or browser',
      'Others',
    ],
    'Micro dealership related': [
      'this is for a new micro dealership or an existing one',
      'you are facing issues with registration or account activation',
      'you need assistance with setting up marketing materials',
      'there is a problem with receiving products or services for the dealership',
      'you are experiencing delays in lead generation for the micro dealership',
      'you need help managing dealership finances or accounts',
      'Others',
    ],
    'Kylas related': [
      'there is a specific feature in Kylas that’s not working',
      'the issue occur after a software update',
      'you tried reloading or resetting the Kylas app',
      'you are facing login issues or access problems',
      'Kylas is showing any error message or code',
      'you experienced delays in syncing data from Kylas',
      'you are facing problems with the Kylas mobile app or desktop version',
      'Others',
    ],
    'Banner & Labels': [
      'this is a request for new banner designs or labels',
      'you need updates or corrections on existing banners or labels',
      'What size or specifications are required for the banner or label',
      'you have the content ready for the banners or labels',
      'this is a one-time request or ongoing for a campaign',
      'you need printed labels or digital versions',
      'this is related to specific products or campaigns',
      'Others',
    ],
    'Website issue': [
      'the website is not loading or showing errors',
      'you are experiencing issues with the checkout process',
      'the website is displaying broken links or missing content',
      'images or banners are not displaying correctly on the website',
      'the website is running slower than usual',
      'you checked if the website is up to date with the latest version',
      'Are any third-party integrations (e.g., payment gateways) not working',
      'Others',
    ],
    'Pricing related': [
      'the displayed price is incorrect',
      'you are facing issues with discounts or promotions',
      'there is a mismatch between the cart total and product prices',
      'the price is different across regions or locations',
      'there are currency conversion issues',
      'there is a problem with bulk pricing or quantity discounts',
      'you applied any coupons that are not reflecting',
      'Others',
    ],
    'Template related': [
      'you need help with creating a new template',
      'the issue is related to a formatting or layout error in the template',
      'you require specific design elements to be added to the template',
      'you are facing issues with text or image alignment',
      'you need a template for a specific campaign or product',
      'there are issues with saving or reusing the template',
      'you need assistance with uploading or sharing the template',
      'Others',
    ],
    'App task and others': [
      'there is a specific app feature you are facing issues with',
      'you need help completing a specific task within the app',
      'there are any app performance issues (e.g., crashes, slow response)',
      'the app is failing to sync or save data properly',
      'you are looking for assistance with app integration or plugins',
      'you need help with app customization for a campaign or project',
      'you have encountered any bugs or glitches in the app',
      'Others',
    ],
    // Accounts
    'Invoice': [
      'Invoice not received yet',
      'Invoice received but incorrect',
      'Need a duplicate invoice',
      'Invoice does not match purchase order',
      'Payment details missing from invoice',
      'Incorrect tax or VAT applied',
      'Need a breakdown of charges on the invoice',
      'Others',
    ],
    'Order confirmation': [
      'Confirmation email not received',
      'Order confirmed but incorrect',
      'Need confirmation of payment',
      'Order confirmed but delayed',
      'Need changes after order confirmation',
      'Need shipping details after confirmation',
      'Order confirmation pending for approval',
      'Others',
    ],
    'Invoice correction': [
      'Correction needed for the invoice amount',
      'Correction needed for product details',
      'Correction needed for tax or VAT applied',
      'Need a corrected invoice with new terms',
      'Incorrect billing address',
      'Incorrect delivery address',
      'Correction required for discount or promotions',
      'Others',
    ],
    'Documents if any': [
      'Need order-related documents',
      'Need shipment-related documents',
      'Need billing-related documents',
      'Need proof of payment',
      'Documents missing from the package',
      'Incorrect documents received',
      'Documents needed for customs or export',
      'Others',
    ],
    'Micro dealer statement': [
      'Need an updated dealer statement',
      'Discrepancies found in the dealer statement',
      'Missing transaction details in the statement',
      'Incorrect commission or rebate details in the statement',
      'Statement not received',
      'Issues with the dealer account summary',
      'Need tax-related details in the statement',
      'Others',
    ],

    // BA
    'Sales sheet not working': [
      'Sheet not loading at all',
      'Data missing from the sheet',
      'Sheet freezing or crashing',
      'Data not updating in real-time',
      'Incorrect calculations in the sheet',
      'Permissions issue (unable to access)',
      'Others',
    ],
    'Order ID is not visible in sales sheet': [
      'Order ID missing for certain entries',
      'Order ID not generated',
      'Order ID not synced from the system',
      'System lag causing order IDs to disappear',
      'Order ID mismatch with another entry',
      'Others',
    ],
    'Add P number in price confirmation sheet': [
      'P number field not available',
      'Error when adding P number',
      'P number not saving correctly',
      'System not allowing the addition of a P number',
      'Incorrect format for P number',
      'Others',
    ],
    'Price confirmation entries are not visible to support': [
      'Price entries not synced with support system',
      'Price entries visible to other departments but not support',
      'Permissions issue for support team',
      'Price entries missing in the support dashboard',
      'System lag causing delayed price entry visibility',
      'Others',
    ],
    'Price related': [
      'Price not updated on the system',
      'Incorrect price for specific products',
      'Pricing discrepancies across platforms',
      'Discounts or offers not applied',
      'Price missing from the order entry',
      'Incorrect tax or VAT calculation on price',
      'Others',
    ],


    // Support
    'Need material or packaging image': [
      'Material image is missing',
      'Packaging image is missing',
      'Need updated material image',
      'Need updated packaging image',
      'Incorrect image uploaded',
      'Others',
    ],
    'Special price confirmation': [
      'Special price not applied',
      'Special price approval pending',
      'Special price denied',
      'Price discrepancy in the final order',
      'Special price applied to the wrong product',
      'Others',
    ],
    'Order cancellation': [
      'Cancellation request pending approval',
      'Cancellation denied',
      'Refund for canceled order not received',
      'Order cancellation in progress',
      'Partial cancellation required',
      'Cancellation request not processed',
      'Others',
    ],
    'Document Related': [
      'Missing invoice document',
      'Incorrect document attached',
      'Document not uploaded to the system',
      'Need document reissue',
      'Document approval pending',
      'Others',
    ],
    'Others': [
      'General inquiry',
      'System-related issues',
      'Clarification needed for order status',
      'Others',
    ],
  };


  @override
  void initState() {
    super.initState();
    _fetchUserDetails(); // Fetch logged-in user details on initialization
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ticket submitted successfully')),
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
          child: DropdownButton<String>(
            value: _selectedQuestionnaire.isNotEmpty ? _selectedQuestionnaire : null,
            hint: Text('Select Questionnaire'),
            isExpanded: true, // Ensures the dropdown takes up full width
            underline: SizedBox(), // Removes the default underline
            icon: Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF5B4636)), // Modern icon
            onChanged: (String? newValue) {
              setState(() {
                _selectedQuestionnaire = newValue!;
                _selectedDepartment = _questionnaireToDepartment[_selectedQuestionnaire] ?? 'Unknown';
              });
            },
            items: _questionnaireOptions.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
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
                .map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          ),
        ),
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
                await _addImageUrlToDescription();
              },
            ),
          ),
          onSubmitted: (value) {
            _triggerSubmit();  // Submit form when "Enter" is pressed
          },
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


}
