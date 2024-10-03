import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'ticket_service.dart'; // Import your TicketService
import 'addticket.dart'; // Import your addTicket method or screen

class TicketScreen extends StatelessWidget {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TicketService _ticketService = TicketService(); // TicketService instance
  final TextEditingController _oldKeyController = TextEditingController(); // For old key input
  final TextEditingController _newKeyController = TextEditingController(); // For new key input

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Tickets')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _titleController,
                decoration: InputDecoration(labelText: 'Title'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: 'Description'),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final title = _titleController.text;
                final description = _descriptionController.text;
                if (title.isNotEmpty && description.isNotEmpty) {
                  addTicket(title, description).then((_) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => TicketListScreen()),
                    );
                  });
                }
              },
              child: Text('Create Ticket'),
            ),
            SizedBox(height: 20),
            Text('Bulk Update Tickets'),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _oldKeyController,
                decoration: InputDecoration(labelText: 'Old Ticket Key'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _newKeyController,
                decoration: InputDecoration(labelText: 'New Ticket Key'),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final oldKey = _oldKeyController.text;
                final newKey = _newKeyController.text;

                if (oldKey.isNotEmpty && newKey.isNotEmpty) {
                  Map<String, String> keyMap = {oldKey: newKey};
                  Map<String, dynamic> updatedData = {
                    'title': _titleController.text,
                    'description': _descriptionController.text,
                  };

                  _ticketService.batchUpdateTickets(keyMap, updatedData).then((_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Ticket updated successfully')),
                    );
                  }).catchError((error) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update ticket')),
                    );
                  });
                }
              },
              child: Text('Update Ticket'),
            ),
          ],
        ),
      ),
    );
  }
}

class TicketListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('My Tickets')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('tickets').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          final tickets = snapshot.data!.docs;
          return ListView.builder(
            itemCount: tickets.length,
            itemBuilder: (context, index) {
              final ticket = tickets[index].data() as Map<String, dynamic>;
              return ListTile(
                title: Text(ticket['title']),
                subtitle: Text(ticket['description']),
              );
            },
          );
        },
      ),
    );
  }
}

// Screen for updating multiple ticket keys
class UpdateTicketKeysScreen extends StatelessWidget {
  final TicketService _ticketService = TicketService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Update Ticket Keys')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // Example key map where you map old keys to new keys
            Map<String, String> keyMap = {
              'YOiPtgVK5Q6sGjCjxBZM': 'k01',
              // Add more key pairs if needed
            };

            // Call the updateTicketKeyFromMap function
            _ticketService.updateTicketKeys(keyMap as Map<String, String>).then((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Keys updated successfully')),
              );
            }).catchError((error) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to update keys: $error')),
              );
            });
          },
          child: Text('Update Keys'),
        ),
      ),
    );
  }
}