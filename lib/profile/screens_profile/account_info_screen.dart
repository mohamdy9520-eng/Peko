import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../fireBase_service/fireBase_service.dart';
import '../user_model/user_model.dart';

class AccountInfoScreen extends StatefulWidget {
  const AccountInfoScreen({super.key});

  @override
  State<AccountInfoScreen> createState() => _AccountInfoScreenState();
}

class _AccountInfoScreenState extends State<AccountInfoScreen> {
  final _firebaseService = FirebaseService();
  static const Color _primaryColor = Color(0xFF2E8B7B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Account Info'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<UserModel>(
        stream: _firebaseService.getUser(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = snapshot.data!;
          // ✅ جيب isEmailVerified مباشرة من Firebase Auth
          final authUser = FirebaseAuth.instance.currentUser;
          final isEmailVerified = authUser?.emailVerified ?? false;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildInfoCard(
                  'Account Status',
                  isEmailVerified ? 'Verified ✓' : 'Not Verified',
                  isEmailVerified ? Icons.verified : Icons.warning,
                  isEmailVerified ? Colors.green : Colors.orange,
                ),
                const SizedBox(height: 12),
                _buildInfoCard('Email', user.email, Icons.email, _primaryColor),
                const SizedBox(height: 12),
                _buildInfoCard('User ID', user.uid, Icons.fingerprint, _primaryColor),
                const SizedBox(height: 12),
                _buildInfoCard('Member Since', _formatDate(user.createdAt), Icons.calendar_today, _primaryColor),
                const SizedBox(height: 12),
                _buildInfoCard('Last Updated', _formatDate(user.updatedAt), Icons.update, _primaryColor),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon, Color iconColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    return '${date.day}/${date.month}/${date.year}';
  }
}