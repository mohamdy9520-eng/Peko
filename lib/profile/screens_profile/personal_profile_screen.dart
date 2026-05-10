import 'dart:io';
import 'package:flutter/material.dart';
import '../fireBase_service/fireBase_service.dart';
import '../user_model/user_model.dart';

class PersonalProfileScreen extends StatefulWidget {
  const PersonalProfileScreen({super.key});

  @override
  State<PersonalProfileScreen> createState() => _PersonalProfileScreenState();
}

class _PersonalProfileScreenState extends State<PersonalProfileScreen> {
  final firebaseService = FirebaseService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _usernameController;
  late TextEditingController _phoneController;

  String? _imageUrl;
  File? _selectedImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _usernameController = TextEditingController();
    _phoneController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  ImageProvider? _getBackgroundImage() {
    if (_selectedImage != null) {
      return FileImage(_selectedImage!);
    }
    if (_imageUrl != null && _imageUrl!.isNotEmpty) {
      return NetworkImage(_imageUrl!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal Profile'),
        backgroundColor: const Color(0xFF4A9B8E),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: StreamBuilder<UserModel>(
        stream: firebaseService.getUser(),
        builder: (context, snapshot) {
          if (snapshot.hasData && _nameController.text.isEmpty) {
            final user = snapshot.data!;
            _nameController.text = user.name;
            _emailController.text = user.email;
            _usernameController.text = user.username;
            _phoneController.text = user.phone;
            _imageUrl = user.image;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: _getBackgroundImage(), // ✅ استدعاء الـ method
                      child: (_selectedImage == null && (_imageUrl?.isEmpty ?? true))
                          ? const Icon(Icons.person, size: 60, color: Colors.grey)
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF4A9B8E),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                    ),
                  ],
                ),
              ),
                  const SizedBox(height: 30),
                  // الحقول
                  _buildTextField('Full Name', _nameController, Icons.person),
                  const SizedBox(height: 16),
                  _buildTextField('Email', _emailController, Icons.email, keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 16),
                  _buildTextField('Username', _usernameController, Icons.alternate_email),
                  const SizedBox(height: 16),
                  _buildTextField('Phone', _phoneController, Icons.phone, keyboardType: TextInputType.phone),
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
      }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF4A9B8E)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF4A9B8E)),
        ),
      ),
      validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
    );
  }

  Future<void> _pickImage() async {
    final file = await firebaseService.pickImage();
    if (file != null) {
      setState(() => _selectedImage = file);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String? imageUrl = _imageUrl;

      if (_selectedImage != null) {
        imageUrl = await firebaseService.uploadImage(_selectedImage!);
      }

      final updatedUser = UserModel(
        name: _nameController.text,
        email: _emailController.text,
        username: _usernameController.text,
        phone: _phoneController.text,
        image: imageUrl ?? '',
      );

      await firebaseService.updateUser(updatedUser);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}