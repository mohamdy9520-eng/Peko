import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MessageCenterScreen extends StatelessWidget {
  const MessageCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    final stream = FirebaseFirestore.instance
        .collection('messages')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots();

    FirebaseFirestore.instance.collection('messages').add({
      'title': 'Welcome!',
      'body': 'Thanks for joining',
      'isRead': false,
      'userId': FirebaseAuth.instance.currentUser!.uid,
      'timestamp': FieldValue.serverTimestamp(),
    });



    return Scaffold(
      appBar: AppBar(
        title: const Text('Message Center'),
        backgroundColor: const Color(0xFF4A9B8E),
        foregroundColor: Colors.white,
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No messages yet"));
          }

          final messages = snapshot.data!.docs;

          return ListView.builder(
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final data = messages[index].data() as Map<String, dynamic>;

              final isRead = data['isRead'] ?? false;
              final timestamp = data['timestamp'] as Timestamp?;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isRead
                      ? Colors.grey.shade200
                      : const Color(0xFF4A9B8E).withOpacity(0.2),
                  child: Icon(
                    isRead
                        ? Icons.mark_email_read
                        : Icons.mark_email_unread,
                    color: isRead
                        ? Colors.grey
                        : const Color(0xFF4A9B8E),
                  ),
                ),

                title: Text(
                  data['title'] ?? '',
                  style: TextStyle(
                    fontWeight:
                    isRead ? FontWeight.normal : FontWeight.bold,
                  ),
                ),

                subtitle: Text(data['body'] ?? ''),

                trailing: Text(
                  _formatTime(timestamp),
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),

                onTap: () async {
                  await messages[index].reference.update({
                    'isRead': true,
                  });
                },
              );
            },
          );
        },
      ),
    );
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final date = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';

    return '${diff.inDays}d ago';
  }
}