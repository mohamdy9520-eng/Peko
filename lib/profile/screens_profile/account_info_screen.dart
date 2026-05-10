import 'package:flutter/material.dart';
import '../fireBase_service/fireBase_service.dart';
import '../user_model/user_model.dart';

class AccountInfoScreen extends StatelessWidget {
  const AccountInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseService = FirebaseService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Info'),
        backgroundColor: const Color(0xFF4A9B8E),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<UserModel>(
        stream: firebaseService.getUser(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildInfoCard('Full Name', user.name, Icons.person),
                _buildInfoCard('Email', user.email, Icons.email),
                _buildInfoCard('Username', '@${user.username}', Icons.alternate_email),
                _buildInfoCard('Phone', user.phone, Icons.phone),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF4A9B8E)),
        title: Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
        subtitle: Text(
          value.isNotEmpty ? value : 'Not set',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}