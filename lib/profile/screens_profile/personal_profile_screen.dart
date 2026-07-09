import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../fireBase_service/fireBase_service.dart';
import '../user_model/user_model.dart';

class PersonalProfileScreen extends StatefulWidget {
  const PersonalProfileScreen({super.key});

  @override
  State<PersonalProfileScreen> createState() => _PersonalProfileScreenState();
}

class _PersonalProfileScreenState extends State<PersonalProfileScreen> {
  final _firebaseService = FirebaseService();
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _usernameController;
  late TextEditingController _phoneController;
  late TextEditingController _bioController;

  String? _imageUrl;
  File? _selectedImage;
  bool _isLoading = false;
  bool _isDataLoaded = false;

  UserModel? _currentUser; // ← خزّن الـ user الحالي

  static const Color _primaryColor = Color(0xFF2E8B7B);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _usernameController = TextEditingController();
    _phoneController = TextEditingController();
    _bioController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  /// ✅ Initialize controllers ONCE when data arrives
  void _initializeControllers(UserModel user) {
    if (_isDataLoaded) return;

    _currentUser = user; // ← خزّن الـ user

    _nameController.text = user.name;
    _emailController.text = user.email;
    _usernameController.text = user.username;
    _phoneController.text = user.phone;
    _bioController.text = user.bio ?? '';
    _imageUrl = user.image;
    _isDataLoaded = true;
  }

  ImageProvider? _getBackgroundImage() {
    if (_selectedImage != null) return FileImage(_selectedImage!);
    if (_imageUrl != null && _imageUrl!.isNotEmpty) return NetworkImage(_imageUrl!);
    return null;
  }

  Future<void> _pickImage() async {
    HapticFeedback.mediumImpact();
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      if (picked == null) return;

      final file = File(picked.path);
      final size = await file.length();
      const maxSize = 5 * 1024 * 1024;

      if (size > maxSize) {
        _showError('Image must be less than 5MB');
        return;
      }

      setState(() => _selectedImage = file);
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    // ✅ تأكد إن الـ user موجود
    if (_currentUser == null) {
      _showError('User data not loaded. Please try again.');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      String? imageUrl = _imageUrl;

      // ✅ Upload image if selected
      if (_selectedImage != null) {
        imageUrl = await _firebaseService.uploadImage(_selectedImage!);
      }

      // ✅ Create updated user using copyWith (uid preserved automatically!)
      final updatedUser = _currentUser!.copyWith(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        username: _usernameController.text.trim(),
        phone: _phoneController.text.trim(),
        image: imageUrl ?? _currentUser!.image,
        bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
        updatedAt: DateTime.now(),
      );

      // ✅ Save to Firebase
      await _firebaseService.updateUser(updatedUser);

      // ✅ Update local reference
      _currentUser = updatedUser;

      if (mounted) {
        _showSuccess('Profile updated successfully!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: _primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade400,
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
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: _isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
                : const Text(
              'Save',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<UserModel>(
        stream: _firebaseService.getUser(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            _initializeControllers(snapshot.data!);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Profile Image Picker
                  GestureDetector(
                    onTap: _pickImage,
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
                            child: CircleAvatar(
                              radius: 60,
                              backgroundColor: Colors.grey.shade200,
                              backgroundImage: _getBackgroundImage(),
                              child: (_selectedImage == null && (_imageUrl?.isEmpty ?? true))
                                  ? const Icon(Icons.person, size: 60, color: Colors.grey)
                                  : null,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _primaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to change photo',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 32),

                  // Form Fields
                  _buildTextField(
                    'Full Name',
                    _nameController,
                    Icons.person,
                    validator: (v) => v?.trim().isEmpty ?? true ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    'Email',
                    _emailController,
                    Icons.email,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v?.trim().isEmpty ?? true) return 'Email is required';
                      if (!v!.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    'Username',
                    _usernameController,
                    Icons.alternate_email,
                    validator: (v) => v?.trim().isEmpty ?? true ? 'Username is required' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    'Phone',
                    _phoneController,
                    Icons.phone,
                    keyboardType: TextInputType.phone,
                    validator: (v) {
                      if (v?.trim().isEmpty ?? true) return 'Phone is required';
                      if (v!.length < 8) return 'Phone number is too short';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    'Bio',
                    _bioController,
                    Icons.info_outline,
                    maxLines: 3,
                    hintText: 'Tell us about yourself...',
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField(
      String label,
      TextEditingController controller,
      IconData icon, {
        TextInputType? keyboardType,
        int maxLines = 1,
        String? hintText,
        String? Function(String?)? validator,
      }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon, color: _primaryColor),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.shade300, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}