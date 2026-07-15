import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttermoji/fluttermoji.dart';
import 'package:fluttermoji/fluttermojiCircleAvatar.dart';

import '../fireBase_service/fireBase_service.dart';
import '../user_model/user_model.dart';

class PersonalProfileScreen extends StatefulWidget {
  const PersonalProfileScreen({super.key});

  @override
  State<PersonalProfileScreen> createState() => _PersonalProfileScreenState();
}

class _PersonalProfileScreenState extends State<PersonalProfileScreen> {
  final _firebaseService = FirebaseService();

  static const Color _primaryColor = Color(0xFF2E8B7B);

  // ═══════════════════════════════════════════════════════════
  // AVATAR PICKER - Fluttermoji
  // ═══════════════════════════════════════════════════════════
  void _showAvatarPicker() {
    HapticFeedback.lightImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Customize Avatar',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FluttermojiCustomizer(
                scaffoldHeight: MediaQuery.of(context).size.height * 0.6,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () async {
                  final fluttermojiFunctions = FluttermojiFunctions();
                  final svgString = await fluttermojiFunctions.encodeMySVGtoString();

                  await _firebaseService.updateUserFields({
                    'avatarBase64': svgString,
                    'image': '', // Clear real photo when using avatar
                  });
                  if (mounted) {
                    _showSuccess('Avatar saved!');
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Save Avatar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD AVATAR WIDGET
  // ═══════════════════════════════════════════════════════════
  Widget _buildAvatar(UserModel user) {
    // 1. Fluttermoji Avatar
    if (user.hasAvatar) {
      return FluttermojiCircleAvatar(
        backgroundColor: Colors.grey.shade200,
        radius: 60,
      );
    }

    // 2. Real photo (base64 from camera/gallery)
    if (user.hasImage) {
      if (user.image.startsWith('http')) {
        return CircleAvatar(
          radius: 60,
          backgroundImage: NetworkImage(user.image),
        );
      } else {
        try {
          final bytes = base64Decode(user.image);
          return CircleAvatar(
            radius: 60,
            backgroundImage: MemoryImage(Uint8List.fromList(bytes)),
          );
        } catch (e) {
          return _buildInitials(user);
        }
      }
    }

    // 3. Default initials
    return _buildInitials(user);
  }

  Widget _buildInitials(UserModel user) {
    return CircleAvatar(
      radius: 60,
      backgroundColor: Colors.grey.shade200,
      child: Text(
        user.initials,
        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _primaryColor),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Personal Profile'),
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

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // ═══════════════════════════════════════════════════════
                // AVATAR (Tap to customize)
                // ═══════════════════════════════════════════════════════
                GestureDetector(
                  onTap: _showAvatarPicker,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Hero(
                        tag: 'profile-avatar',
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: _primaryColor.withOpacity(0.2), width: 3),
                          ),
                          child: _buildAvatar(user),
                        ),
                      ),
                      // Edit icon
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.edit, color: Colors.white, size: 16),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap to customize avatar',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 32),

                // ═══════════════════════════════════════════════════════
                // READ-ONLY INFO FIELDS
                // ═══════════════════════════════════════════════════════
                _buildInfoField('Full Name', user.name, Icons.person),
                const SizedBox(height: 16),
                _buildInfoField('Email', user.email, Icons.email),
                const SizedBox(height: 16),
                _buildInfoField('Username', '@${user.username}', Icons.alternate_email),
                const SizedBox(height: 16),
                _buildInfoField('Phone', user.phone, Icons.phone),
                const SizedBox(height: 16),
                _buildInfoField('Bio', user.bio ?? 'No bio added', Icons.info_outline),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // READ-ONLY INFO FIELD
  // ═══════════════════════════════════════════════════════════
  Widget _buildInfoField(String label, String value, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ],
      ),
    );
  }
}