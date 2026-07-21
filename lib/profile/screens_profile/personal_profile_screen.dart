import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttermoji/fluttermoji.dart';
import 'package:fluttermoji/fluttermojiCircleAvatar.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  void _syncAvatarToLocalCache(String avatarJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fluttermojiSelectedOptions', avatarJson);
  }

  void _showAvatarPicker() {
    HapticFeedback.lightImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 600.w),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            ),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(16.r),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Customize Avatar',
                        style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close, size: 24.r),
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
                  padding: EdgeInsets.all(16.r),
                  child: ElevatedButton(
                    onPressed: () async {
                      final fluttermojiFunctions = FluttermojiFunctions();
                      String jsonString = await fluttermojiFunctions.encodeMySVGtoString();

                      await _firebaseService.updateUserFields({
                        'avatarBase64': jsonString,
                        'image': '',
                      });

                      if (mounted) {
                        _showSuccess('Avatar saved!');
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      minimumSize: Size(double.infinity, 50.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                    ),
                    child: Text('Save Avatar', style: TextStyle(fontSize: 16.sp, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(UserModel user) {
    if (user.avatarBase64 != null && user.avatarBase64!.trim().isNotEmpty && user.avatarBase64!.contains('{')) {
      return CircleAvatar(
        radius: 60.r,
        backgroundColor: Colors.grey.shade100,
        child: ClipOval(
          child: FluttermojiCircleAvatar(
            radius: 55.r,
            backgroundColor: Colors.transparent,
          ),
        ),
      );
    }

    if (user.hasImage && user.image.isNotEmpty) {
      if (user.image.startsWith('http')) {
        return CircleAvatar(
          radius: 60.r,
          backgroundImage: NetworkImage(user.image),
        );
      } else {
        try {
          final bytes = base64Decode(user.image);
          return CircleAvatar(
            radius: 60.r,
            backgroundImage: MemoryImage(Uint8List.fromList(bytes)),
          );
        } catch (e) {
          return _buildInitials(user);
        }
      }
    }

    return _buildInitials(user);
  }

  Widget _buildInitials(UserModel user) {
    return CircleAvatar(
      radius: 60.r,
      backgroundColor: Colors.grey.shade200,
      child: Text(
        user.initials,
        style: TextStyle(fontSize: 32.sp, fontWeight: FontWeight.bold, color: _primaryColor),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(fontSize: 14.sp)),
        backgroundColor: _primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
        margin: EdgeInsets.all(16.r),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text('Personal Profile', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w600)),
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

          if (user.avatarBase64 != null && user.avatarBase64!.trim().isNotEmpty && user.avatarBase64!.contains('{')) {
            _syncAvatarToLocalCache(user.avatarBase64!);
          }

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 600.w),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20.r),
                child: Column(
                  children: [
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
                                border: Border.all(color: _primaryColor.withOpacity(0.2), width: 3.w),
                              ),
                              child: _buildAvatar(user),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.all(8.r),
                            decoration: BoxDecoration(
                              color: _primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2.w),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 8.r,
                                  offset: Offset(0, 3.h),
                                ),
                              ],
                            ),
                            child: Icon(Icons.edit, color: Colors.white, size: 16.r),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Tap to customize avatar',
                      style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade500),
                    ),
                    SizedBox(height: 32.h),

                    _buildInfoField('Full Name', user.name, Icons.person, isEditable: false),
                    SizedBox(height: 16.h),
                    _buildInfoField('Email', user.email, Icons.email, isEditable: false),
                    SizedBox(height: 16.h),

                    _buildInfoField(
                      'Username',
                      '@${user.username}',
                      Icons.alternate_email,
                      isEditable: true,
                      onEditTap: () => _showEditDialog('username', user.username),
                    ),
                    SizedBox(height: 16.h),
                    _buildInfoField(
                      'Phone',
                      user.phone,
                      Icons.phone,
                      isEditable: true,
                      onEditTap: () => _showEditDialog('phone', user.phone),
                    ),
                    SizedBox(height: 16.h),
                    _buildInfoField(
                      'Bio',
                      user.bio ?? 'No bio added',
                      Icons.info_outline,
                      isEditable: true,
                      onEditTap: () => _showEditDialog('bio', user.bio ?? ''),
                    ),
                    SizedBox(height: 32.h),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoField(String label, String value, IconData icon, {required bool isEditable, VoidCallback? onEditTap}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: _primaryColor, size: 20.r),
                    SizedBox(width: 8.w),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
          ),
          if (isEditable)
            IconButton(
              icon: Icon(Icons.edit_outlined, color: _primaryColor, size: 22.r),
              onPressed: onEditTap,
            ),
        ],
      ),
    );
  }

  void _showEditDialog(String fieldKey, String currentValue) {
    final TextEditingController controller = TextEditingController(text: currentValue);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text('Update ${fieldKey.toUpperCase()}', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          style: TextStyle(fontSize: 14.sp),
          decoration: InputDecoration(
            hintText: 'Enter new $fieldKey',
            hintStyle: TextStyle(fontSize: 14.sp),
            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: _primaryColor, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey, fontSize: 14.sp)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
            ),
            onPressed: () async {
              final newValue = controller.text.trim();

              if (newValue.isNotEmpty && newValue != currentValue) {
                Navigator.pop(context);

                try {
                  await _firebaseService.updateUserFields({
                    fieldKey: newValue,
                  });

                  if (mounted) {
                    _showSuccess('${fieldKey.toUpperCase()} updated successfully!');
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update: $e', style: TextStyle(fontSize: 14.sp)), backgroundColor: Colors.red),
                    );
                  }
                }
              } else {
                Navigator.pop(context);
              }
            },
            child: Text('Save', style: TextStyle(color: Colors.white, fontSize: 14.sp)),
          ),
        ],
      ),
    );
  }
}