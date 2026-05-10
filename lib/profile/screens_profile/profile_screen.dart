import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../fireBase_service/fireBase_service.dart';
import '../user_model/user_model.dart';
import 'invite_friends_screen.dart';
import 'account_info_screen.dart';
import 'personal_profile_screen.dart';
import 'message_center_screen.dart';
import 'login_security_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();

  static Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildNavItem(IconData icon, bool isActive) {
    return Icon(
      icon,
      size: 26,
      color: isActive ? const Color(0xFF2E8B7B) : Colors.grey,
    );
  }
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseService firebaseService = FirebaseService();
  final ImagePicker picker = ImagePicker();

  bool isUploading = false;


  Future<void> _pickImage(ImageSource source) async {
    final XFile? file = await picker.pickImage(
      source: source,
      imageQuality: 70,
    );

    if (file == null) return;

    try {
      setState(() {
        isUploading = true;
      });

      final imageFile = File(file.path);

      final uid = firebaseService.uid;

      if (uid == null) {
        throw Exception("User not logged in");
      }

      final url = await firebaseService.uploadImage(imageFile);

      await firebaseService.updateUserImage(url);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      setState(() {
        isUploading = false;
      });
    }
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text("Camera"),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo),
                title: const Text("Gallery"),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: StreamBuilder<UserModel>(
        stream: firebaseService.getUser(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = snapshot.data ??
              UserModel(
                name: 'Enjelin Morgeana',
                email: '',
                username: 'enjelin_morgeana',
                phone: '',
                image: '',
              );

          return Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 220,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2E8B7B),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(40),
                        bottomRight: Radius.circular(40),
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                            ),
                            const Text(
                              "Profile",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Icon(Icons.notifications_outlined, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    bottom: -50,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                            ),
                            child: CircleAvatar(
                              radius: 50,
                              backgroundImage: user.image.isNotEmpty
                                  ? NetworkImage(user.image)
                                  : null,
                              child: user.image.isEmpty
                                  ? const Icon(Icons.person, size: 50)
                                  : null,
                            ),
                          ),

                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: InkWell(
                              onTap: _showImagePicker,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2E8B7B),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),

                          if (isUploading)
                            const Positioned.fill(
                              child: Center(child: CircularProgressIndicator()),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 60),

              Text(user.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Text("@${user.username}", style: const TextStyle(color: Color(0xFF2E8B7B))),

              const SizedBox(height: 30),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  children: [
                    ProfileScreen._buildMenuItem(
                      icon: Icons.diamond,
                      iconColor: const Color(0xFF2E8B7B),
                      title: "Invite Friends",
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const InviteFriendsScreen()),
                      ),
                    ),

                    const Divider(),

                    ProfileScreen._buildMenuItem(
                      icon: Icons.person,
                      iconColor: Colors.grey,
                      title: "Account info",
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AccountInfoScreen()),
                      ),
                    ),

                    ProfileScreen._buildMenuItem(
                      icon: Icons.people,
                      iconColor: Colors.grey,
                      title: "Personal profile",
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PersonalProfileScreen()),
                      ),
                    ),

                    ProfileScreen._buildMenuItem(
                      icon: Icons.mail,
                      iconColor: Colors.grey,
                      title: "Message center",
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MessageCenterScreen()),
                      ),
                    ),

                    ProfileScreen._buildMenuItem(
                      icon: Icons.shield,
                      iconColor: Colors.grey,
                      title: "Login and security",
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginSecurityScreen()),
                      ),
                    ),

                    ProfileScreen._buildMenuItem(
                      icon: Icons.lock,
                      iconColor: Colors.grey,
                      title: "Data and privacy",
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}