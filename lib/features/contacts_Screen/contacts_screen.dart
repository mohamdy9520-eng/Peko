import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_router.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please login first'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('contacts')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(snapshot.error.toString()),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final contacts = snapshot.data!.docs;

          if (contacts.isEmpty) {
            return const Center(
              child: Text('No contacts found'),
            );
          }

          return ListView.builder(
            itemCount: contacts.length,
            itemBuilder: (context, index) {
              final contact =
              contacts[index].data() as Map<String, dynamic>;

              return ListTile(
                leading: CircleAvatar(
                  child: Text(
                    (contact['name'] ?? 'U')
                        .toString()
                        .substring(0, 1)
                        .toUpperCase(),
                  ),
                ),
                title: Text(contact['name'] ?? ''),
                subtitle: Text(contact['email'] ?? ''),
                trailing: const Icon(Icons.send),

                onTap: () {
                  context.push(
                    AppRoutes.billPayment,
                    extra: {
                      'contactName': contact['name'],
                      'contactEmail': contact['email'],
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}