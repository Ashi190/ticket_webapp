// File: lib/screens/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:ticket_ui_test/ticket_service.dart';

import 'auth_service.dart';

class DashboardScreen extends StatefulWidget {
  final String userId;

  DashboardScreen({required this.userId});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TicketService _ticketService = TicketService();
  final AuthService _authService = AuthService();

  List<Map<String, dynamic>> _tickets = [];
  String? _role;
  String? _department;

  @override
  void initState() {
    super.initState();
    _fetchUserRoleAndTickets();
  }

  void _fetchUserRoleAndTickets() async {
    String? role = await _authService.getUserRole(widget.userId);
    String? department = await _authService.getUserDepartment(widget.userId);

    if (role != null && department != null) {
      List<Map<String, dynamic>> tickets = await _ticketService.fetchTickets(widget.userId, role, department);
      setState(() {
        _tickets = tickets;
        _role = role;
        _department = department;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard'),
      ),
      body: ListView.builder(
        itemCount: _tickets.length,
        itemBuilder: (context, index) {
          var ticket = _tickets[index];
          return ListTile(
            title: Text(ticket['title']),
            subtitle: Text(ticket['description']),
            trailing: Text(ticket['status']),
          );
        },
      ),
    );
  }
}
