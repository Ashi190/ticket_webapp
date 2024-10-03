import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'Department.dart';


class TicketReassignmentScreen extends StatefulWidget {
  final String ticketId;

  TicketReassignmentScreen({required this.ticketId});

  @override
  _TicketReassignmentScreenState createState() => _TicketReassignmentScreenState();
}

class _TicketReassignmentScreenState extends State<TicketReassignmentScreen> {
  List<Department> _departments = Department.getDepartments();
  String? _currentDepartment;
  String? _assignedMember;
  List<String> _departmentMembers = [];

  get ticketId => null;

  @override
  void initState() {
    super.initState();
    _fetchTicketData();
  }

  Future<void> _fetchTicketData() async {
    var doc = await FirebaseFirestore.instance.collection('tickets').doc(widget.ticketId).get();
    if (doc.exists) {
      var data = doc.data();
      setState(() {
        _currentDepartment = data?['department'];
        _assignedMember = data?['assigned_member'];
        _departmentMembers = _departments
            .firstWhere((dept) => dept.name == _currentDepartment)
            .members;
      });
    }
  }

  Widget _buildReassignDepartmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reassign Department', style: TextStyle(fontWeight: FontWeight.bold)),
        DropdownButton<String>(
          value: _currentDepartment,
          onChanged: (String? newDepartment) {
            setState(() {
              _currentDepartment = newDepartment;
              _departmentMembers = _departments
                  .firstWhere((dept) => dept.name == _currentDepartment)
                  .members;
              _assignedMember = null;

              // Update department in Firestore
              FirebaseFirestore.instance.collection('tickets').doc(widget.ticketId).update({
                'department': _currentDepartment,
              });
            });
          },
          items: _departments.map((department) {
            return DropdownMenuItem<String>(
              value: department.name,
              child: Text(department.name),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAssignMemberSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Assign to Member', style: TextStyle(fontWeight: FontWeight.bold)),
        DropdownButton<String>(
          value: _assignedMember,
          onChanged: (String? newMember) {
            setState(() {
              _assignedMember = newMember;

              // Update assigned member in Firestore
              FirebaseFirestore.instance.collection('tickets').doc(widget.ticketId).update({
                'assigned_member': _assignedMember,
              });
            });
          },
          items: _departmentMembers.map((member) {
            return DropdownMenuItem<String>(
              value: member,
              child: Text(member),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _handleReassignToSupport() {
    setState(() {
      _currentDepartment = 'Support';
      _departmentMembers = _departments
          .firstWhere((dept) => dept.name == 'Support')
          .members;
      _assignedMember = null;
    });

    // Update Firestore with reassign to Support
    FirebaseFirestore.instance.collection('tickets').doc(widget.ticketId).update({
      'department': 'Support',
      'assigned_member': null,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reassign Ticket'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildReassignDepartmentSection(),
            _buildAssignMemberSection(),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _handleReassignToSupport,
              child: Text('Reassign to Support'),
            ),
          ],
        ),
      ),
    );
  }


}
