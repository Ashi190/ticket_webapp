import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'TicketDetailScreen.dart';


class SupportScreen extends StatefulWidget {
  @override
  _SupportScreenState createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  late Stream<QuerySnapshot> _ticketsStream;

  @override
  void initState() {
    super.initState();
    _ticketsStream = FirebaseFirestore.instance
        .collection('tickets')
        .where('department', isEqualTo: 'Support')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Support Tickets'),
        backgroundColor: Colors.teal,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _ticketsStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final tickets = snapshot.data!.docs;

          return ListView.builder(
            itemCount: tickets.length,
            itemBuilder: (context, index) {
              final ticket = tickets[index].data() as Map<String, dynamic>;
              final ticketId = tickets[index].id;

              return Card(
                margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                elevation: 2.0,
                child: ListTile(
                  title: Text(ticket['subject']),
                  subtitle: Text(ticket['description']),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TicketDetailScreen(ticketId: ticketId),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
