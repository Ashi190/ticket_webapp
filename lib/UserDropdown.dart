import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserDropdown extends StatefulWidget {
  final String userDepartment;

  UserDropdown({required this.userDepartment});

  @override
  _UserDropdownState createState() => _UserDropdownState();
}

class _UserDropdownState extends State<UserDropdown> {
  List<Map<String, dynamic>> users = [];
  String? selectedUser;

  @override
  void initState() {
    super.initState();
    fetchUsers();
  }

  // Fetch users from Firestore based on the department
  Future<void> fetchUsers() async {
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('department', isEqualTo: widget.userDepartment)
          .get();

      setState(() {
        users = querySnapshot.docs.map((doc) {
          return {
            'userId': doc['userId'],
            'name': doc['name'],
          };
        }).toList();
      });
    } catch (e) {
      print('Error fetching users: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: selectedUser,
      hint: Text('Select User'),
      items: users.map((user) {
        return DropdownMenuItem<String>(
          value: user['userId'],
          child: Text(user['name']),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          selectedUser = value;
        });
      },
    );
  }
}
