import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:ai_expense_tracker/profile/screens_profile/data_privacy.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';
import 'package:image/image.dart' as img;
import '../../providers/currency_provider.dart';
import '../../routes/app_router.dart';
import '../fireBase_service/fireBase_service.dart';
import '../user_model/user_model.dart';
import 'change_Currency.dart';
import 'invite_friends_screen.dart';
import 'account_info_screen.dart';
import 'personal_profile_screen.dart';
import 'message_center_screen.dart';
import 'login_security_screen.dart';
import 'package:fluttermoji/fluttermojiCircleAvatar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  late AnimationController _animationController;

  static const Color _primaryColor = Color(0xFF2E8B7B);
  static const Color _accentColor = Color(0xFF4A9B8E);

  static const int _maxWidth = 400;
  static const int _maxHeight = 400;
  static const int _quality = 85;
  static const double _maxSizeKB = 500;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? file = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1200,
      maxHeight: 1200,
    );
    if (file == null) return;

    HapticFeedback.mediumImpact();
    setState(() { _isUploading = true; _uploadProgress = 0.1; });

    try {
      final imageFile = File(file.path);
      final uid = _firebaseService.uid;
      if (uid == null) throw Exception("User not logged in");

      setState(() => _uploadProgress = 0.3);

      final bytes = await imageFile.readAsBytes();
      setState(() => _uploadProgress = 0.5);

      img.Image? image = img.decodeImage(bytes);
      if (image == null) throw Exception("Failed to decode image");

      if (image.width > _maxWidth || image.height > _maxHeight) {
        image = img.copyResize(
          image,
          width: image.width > image.height ? _maxWidth : null,
          height: image.height >= image.width ? _maxHeight : null,
        );
      }
      setState(() => _uploadProgress = 0.7);

      final compressedBytes = img.encodeJpg(image, quality: _quality);
      setState(() => _uploadProgress = 0.8);

      final base64Image = base64Encode(compressedBytes);
      setState(() => _uploadProgress = 0.9);

      final sizeKB = compressedBytes.length / 1024;
      if (sizeKB > _maxSizeKB) {
        throw Exception("Image too large (${sizeKB.toStringAsFixed(1)} KB). Max allowed: $_maxSizeKB KB");
      }

      await _firebaseService.updateUserFields({
        'avatarBase64': FieldValue.delete(),
        'image': base64Image,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() => _uploadProgress = 1.0);

      if (mounted) {
        _showSuccessSnackBar('Profile photo updated successfully! (${sizeKB.toStringAsFixed(1)} KB)');
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar('Failed to upload image: $e');
    } finally {
      if (mounted) setState(() { _isUploading = false; _uploadProgress = 0.0; });
    }
  }

  void _showImagePicker() {
    HapticFeedback.lightImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext bottomSheetContext) {
        return _ImagePickerBottomSheet(
          onCameraTap: () {
            Navigator.pop(bottomSheetContext);
            _pickImage(ImageSource.camera);
          },
          onGalleryTap: () {
            Navigator.pop(bottomSheetContext);
            _pickImage(ImageSource.gallery);
          },
          onRemoveTap: () async {
            Navigator.pop(bottomSheetContext);
            await _removePhoto();
          },
        );
      },
    );
  }

  Future<void> _removePhoto() async {
    HapticFeedback.mediumImpact();

    try {
      await _firebaseService.updateUserFields({
        'avatarBase64': FieldValue.delete(),
        'image': '',
      });
      if (mounted) {
        _showSuccessSnackBar('Profile photo removed');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to remove photo: $e');
      }
    }
  }

  void _navigateTo(Widget screen) {
    HapticFeedback.selectionClick();
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white),
        const SizedBox(width: 12),
        Expanded(child: Text(message)),
      ]),
      backgroundColor: _primaryColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white),
        const SizedBox(width: 12),
        Expanded(child: Text(message)),
      ]),
      backgroundColor: Colors.red.shade400,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 4),
      action: SnackBarAction(label: 'DISMISS', textColor: Colors.white, onPressed: () {}),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final currencyProvider = Provider.of<CurrencyProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: StreamBuilder<User?>(
        stream: _firebaseService.authStateChanges,
        builder: (context, authSnapshot) {
          if (authSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!authSnapshot.hasData || authSnapshot.data == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.go(AppRoutes.login);
            });
            return const SizedBox.shrink();
          }

          return StreamBuilder<UserModel>(
            stream: _firebaseService.getUser(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return _buildLoadingState();
              }
              if (snapshot.hasError) {
                return _buildErrorState(snapshot.error.toString());
              }
              final user = snapshot.data ?? UserModel.empty;

              return RefreshIndicator(
                onRefresh: () async =>
                await Future.delayed(const Duration(milliseconds: 500)),
                color: _primaryColor,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeader(user)),
                    SliverToBoxAdapter(child: _buildUserInfo(user)),
                    SliverToBoxAdapter(child: _buildStatsRow()),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildMenuSection('General', [
                            _buildMenuTile(_MenuItem(
                              icon: Icons.diamond,
                              iconColor: _primaryColor,
                              title: 'Invite Friends',
                              subtitle: 'Earn rewards by inviting',
                              onTap: () => _navigateTo(const InviteFriendsScreen()),
                            )),
                            StreamBuilder<int>(
                              stream: _firebaseService.getUnreadMessagesCount(),
                              builder: (context, snapshot) {
                                final unreadCount = snapshot.data ?? 0;
                                return _buildMenuTile(_MenuItem(
                                  icon: Icons.mail_outline,
                                  iconColor: Colors.orange,
                                  title: 'Message Center',
                                  subtitle: unreadCount > 0
                                      ? '$unreadCount unread messages'
                                      : 'View your notifications',
                                  onTap: () => _navigateTo(const MessageCenterScreen()),
                                  badge: unreadCount > 0,
                                ));
                              },
                            ),
                          ]),
                          const SizedBox(height: 16),
                          _buildMenuSection('Account', [
                            _buildMenuTile(_MenuItem(
                              icon: Icons.person_outline,
                              iconColor: Colors.blue,
                              title: 'Account Info',
                              subtitle: 'View your account details',
                              onTap: () => _navigateTo(const AccountInfoScreen()),
                            )),
                            _buildMenuTile(_MenuItem(
                              icon: Icons.edit_note,
                              iconColor: _accentColor,
                              title: 'Personal Profile',
                              subtitle: 'Edit your profile information',
                              onTap: () => _navigateTo(const PersonalProfileScreen()),
                            )),
                            _buildMenuTile(_MenuItem(
                              icon: Icons.currency_exchange,
                              iconColor: Colors.teal,
                              title: 'Change Currency',
                              subtitle: '${currencyProvider.flag} ${currencyProvider.name} (${currencyProvider.code})',
                              onTap: () => _navigateTo(const ChangeCurrencyScreen()),
                            )),
                            _buildMenuTile(_MenuItem(
                              icon: Icons.shield_outlined,
                              iconColor: Colors.purple,
                              title: 'Login & Security',
                              subtitle: 'Password, 2FA, and sessions',
                              onTap: () => _navigateTo(const LoginSecurityScreen()),
                            )),
                            _buildMenuTile(_MenuItem(
                              icon: Icons.lock_outline,
                              iconColor: Colors.red.shade400,
                              title: 'Data & Privacy',
                              subtitle: 'Manage your data',
                              onTap: () => _navigateTo(const DataPrivacyScreen()),
                            )),
                          ]),
                          const SizedBox(height: 32),
                        ]),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300, highlightColor: Colors.grey.shade100,
      child: Column(children: [
        Container(height: 220, width: double.infinity,
            decoration: const BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)))),
        const SizedBox(height: 60),
        Container(width: 150, height: 24, color: Colors.white),
        const SizedBox(height: 8),
        Container(width: 100, height: 16, color: Colors.white),
        const SizedBox(height: 30),
        Expanded(child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: 6,
          itemBuilder: (_, __) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(children: [
              Container(width: 40, height: 40, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
              const SizedBox(width: 16),
              Expanded(child: Container(height: 20, color: Colors.white)),
            ]),
          ),
        )),
      ]),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
        const SizedBox(height: 16),
        Text('Something went wrong', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
        const SizedBox(height: 8),
        Text(error, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => setState(() {}),
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
      ]),
    ));
  }

  Widget _buildHeader(UserModel user) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          height: 220,
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2E8B7B), Color(0xFF4A9B8E)],
            ),
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
                  const Spacer(),
                   Center(
                    child: Text(
                      "Profile",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 40.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => _navigateTo(const MessageCenterScreen()),
                    icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                    tooltip: 'Notifications',
                  ),
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
            child: Hero(
              tag: 'profile-avatar',
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 52,
                      backgroundColor: Colors.grey.shade200,
                      child: _buildAvatarContent(user),
                    ),
                    if (_isUploading)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withOpacity(0.5),
                          ),
                          child: Center(
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(
                                value: _uploadProgress > 0 ? _uploadProgress : null,
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: _showImagePicker,
                        behavior: HitTestBehavior.translucent,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _primaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarContent(UserModel user) {
    // 1. Fluttermoji Avatar (SVG string - مش bytes!)
    if (user.hasAvatar) {
      return FluttermojiCircleAvatar(
        backgroundColor: Colors.grey.shade200,
        radius: 52,
      );
    }

    // 2. Real photo (base64 from camera/gallery)
    if (user.hasImage) {
      // Check if it's a URL or base64
      if (user.image.startsWith('http')) {
        return ClipOval(
          child: Image.network(
            user.image,
            fit: BoxFit.cover,
            width: 104,
            height: 104,
            errorBuilder: (context, error, stackTrace) {
              return _buildInitials(user);
            },
          ),
        );
      } else {
        // Base64 image
        try {
          final bytes = base64Decode(user.image);
          return ClipOval(
            child: Image.memory(
              Uint8List.fromList(bytes),
              fit: BoxFit.cover,
              width: 104,
              height: 104,
              errorBuilder: (context, error, stackTrace) {
                return _buildInitials(user);
              },
            ),
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
    return Text(
      user.initials,
      style: const TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Color(0xFF2E8B7B),
      ),
    );
  }

  Widget _buildUserInfo(UserModel user) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(children: [
        Text(user.displayName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
        const SizedBox(height: 4),
        Text("@${user.username}", style: const TextStyle(color: Color(0xFF2E8B7B), fontSize: 14, fontWeight: FontWeight.w500)),
        if (user.bio != null && user.bio!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(user.bio!, textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          ),
        ],
      ]),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          StreamBuilder<int>(
            stream: _firebaseService.getFriendsCount(),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return _buildStatItem(count.toString(), 'Friends');
            },
          ),
          _buildDivider(),
          StreamBuilder<int>(
            stream: _firebaseService.getMessagesCount(),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return _buildStatItem(count.toString(), 'Messages');
            },
          ),
          _buildDivider(),
          StreamBuilder<int>(
            stream: _firebaseService.getRewardsCount(),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              print('Rewards count: $count');
              return _buildStatItem(count.toString(), 'Rewards');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(children: [
      Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
    ]);
  }

  Widget _buildDivider() => Container(height: 30, width: 1, color: Colors.grey.shade300);

  Widget _buildMenuSection(String title, List<Widget> items) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 8),
        child: Text(title.toUpperCase(),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade500, letterSpacing: 0.5)),
      ),
      Container(
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: items.asMap().entries.map((entry) {
            final index = entry.key;
            final widget = entry.value;
            return Column(children: [
              widget,
              if (index < items.length - 1) Divider(height: 1, indent: 56, color: Colors.grey.shade100),
            ]);
          }).toList(),
        ),
      ),
    ]);
  }

  Widget _buildMenuTile(_MenuItem item) {
    return Material(
      color: Colors.transparent, borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: item.onTap, borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: item.iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(item.icon, color: item.iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
              if (item.subtitle != null)
                Text(item.subtitle!, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ])),
            if (item.badge) Container(width: 8, height: 8,
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
          ]),
        ),
      ),
    );
  }

  void _showComingSoon() {
    HapticFeedback.lightImpact();
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [Icon(Icons.construction, color: _primaryColor), SizedBox(width: 12), Text('Coming Soon')]),
      content: const Text('This feature is under development and will be available in the next update.'),
      actions: [TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK', style: TextStyle(color: _primaryColor)))],
    ));
  }
}

class _MenuItem {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool badge;
  const _MenuItem({required this.icon, required this.iconColor, required this.title,
    this.subtitle, required this.onTap, this.badge = false});
}

class _ImagePickerBottomSheet extends StatelessWidget {
  final VoidCallback onCameraTap;
  final VoidCallback onGalleryTap;
  final VoidCallback? onRemoveTap;

  const _ImagePickerBottomSheet({
    required this.onCameraTap,
    required this.onGalleryTap,
    this.onRemoveTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Change Profile Photo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _buildOption(
              icon: Icons.camera_alt,
              label: 'Take Photo',
              onTap: onCameraTap,
            ),
            const SizedBox(height: 12),
            _buildOption(
              icon: Icons.photo_library,
              label: 'Choose from Gallery',
              onTap: onGalleryTap,
            ),
            const SizedBox(height: 12),
            if (onRemoveTap != null)
              _buildOption(
                icon: Icons.delete_outline,
                label: 'Remove Photo',
                color: Colors.red,
                onTap: onRemoveTap!,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Material(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(
                icon,
                color: color ?? const Color(0xFF2E8B7B),
                size: 24,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: color ?? Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}