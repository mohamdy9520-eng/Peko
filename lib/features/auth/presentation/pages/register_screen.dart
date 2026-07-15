import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/di/services/ai_access_service.dart';
import '../../../../profile/fireBase_service/fireBase_service.dart';
import 'google_auth/google_auth.dart';
import '../bloc/auth_bloc.dart';

class SignUpScreen extends StatefulWidget {
  final String? inviteCode;

  const SignUpScreen({this.inviteCode, super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final usernameController = TextEditingController();
  final inviteCodeController = TextEditingController();

  final GoogleAuthService _googleAuth = GoogleAuthService();
  final FirebaseService _firebaseService = FirebaseService();

  File? imageFile;

  bool _isLoading = false;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    if (widget.inviteCode != null) {
      inviteCodeController.text = widget.inviteCode!;
    }
  }

  Future<void> pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source);
    if (picked != null) {
      setState(() => imageFile = File(picked.path));

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'name': nameController.text.trim(),
          'email': user.email,
        });
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    usernameController.dispose();
    inviteCodeController.dispose();
    super.dispose();
  }

  String _getErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('unavailable') ||
        errorString.contains('network') ||
        errorString.contains('socket') ||
        errorString.contains('timeout')) {
      return 'Network error: Could not connect to the server. Please check your connection.';
    }

    if (errorString.contains('permission-denied')) {
      return 'Access denied. Please contact support.';
    }

    return 'Error: $error';
  }

  // ─── VERIFY INVITE & REWARD ───
  Future<void> _verifyInviteAndReward(String newUserId) async {
    final inviteCode = inviteCodeController.text.trim().toUpperCase();
    if (inviteCode.isEmpty) return;

    try {
      final firestore = FirebaseFirestore.instance;

      // 1. دور على الدعوة
      final inviteQuery = await firestore
          .collectionGroup('friends')
          .where('inviteCode', isEqualTo: inviteCode)
          .where('friendRegistered', isEqualTo: false)
          .limit(1)
          .get();

      if (inviteQuery.docs.isEmpty) return;

      final inviteDoc = inviteQuery.docs.first;
      final inviteData = inviteDoc.data();
      final inviterId = inviteData['invitedBy'] as String?;

      if (inviterId == null || inviterId == newUserId) return;

      await inviteDoc.reference.update({
        'friendRegistered': true,
        'friendUserId': newUserId,
        'registeredAt': FieldValue.serverTimestamp(),
      });


      await AIAccessService.grantInviteReward(userId: inviterId);

      // 4. علّم إنه اخد المكافئة
      await inviteDoc.reference.update({'rewarded': true});

    } catch (e) {
      debugPrint('Invite verification error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) async {
        debugPrint('AuthState changed: ${state.runtimeType}');

        setState(() => _isLoading = state is AuthLoading);

        if (state is AuthEmailVerificationRequired) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account created! Please verify your email.'),
              backgroundColor: Colors.green,
            ),
          );
          context.go('/verify-email');
        }

        if (state is AuthSuccess) {
          // ✅ بعد التسجيل الناجح، تحقق من الدعوة واعطِ المكافئة
          final userId = FirebaseAuth.instance.currentUser?.uid;
          if (userId != null) {
            final redeemed = await _firebaseService.redeemInviteCode(inviteCodeController.text);
            _verifyInviteAndReward(userId);
          }
          context.go('/main');
        }

        if (state is AuthFailure) {
          final message = _getErrorMessage(state.message);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            "Sign Up",
            style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/onboarding'),
          ),
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: "Name",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Name is required";
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 10.h),

                      TextFormField(
                        controller: usernameController,
                        decoration: InputDecoration(
                          labelText: "Username",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Username is required";
                          }
                          if (!value.contains('_')) {
                            return "Use _ in username";
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 10.h),

                      TextFormField(
                        controller: emailController,
                        decoration: InputDecoration(
                          labelText: "Email",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Email is required";
                          }
                          if (!value.contains('@')) {
                            return "Enter valid email";
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 10.h),

                      TextFormField(
                        controller: passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: "Password",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Password is required";
                          }
                          if (value.length < 6) {
                            return "Min 6 characters";
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 10.h),

                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        decoration: InputDecoration(
                          labelText: "Confirm Password",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword = !_obscureConfirmPassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value != passwordController.text) {
                            return "Passwords do not match";
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 10.h),

                      // ─── Invite Code Field ───
                      TextFormField(
                        controller: inviteCodeController,
                        decoration: InputDecoration(
                          labelText: "Invite Code (Optional)",
                          hintText: "Enter invite code if you have one",
                          prefixIcon: const Icon(Icons.card_giftcard, color: Color(0xFF2E8B7B)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        textCapitalization: TextCapitalization.characters,
                      ),

                      SizedBox(height: 20.h),

                      SizedBox(
                        width: double.infinity,
                        height: 55.h,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () async {
                            if (!_formKey.currentState!.validate()) return;

                            final username = usernameController.text.trim().toLowerCase();

                            setState(() => _isLoading = true);

                            try {
                              final doc = await FirebaseFirestore.instance
                                  .collection('usernames')
                                  .doc(username)
                                  .get();

                              if (doc.exists) {
                                setState(() => _isLoading = false);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Username already taken'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              context.read<AuthBloc>().add(
                                SignUpRequested(
                                  name: nameController.text.trim(),
                                  email: emailController.text.trim(),
                                  password: passwordController.text.trim(),
                                  username: username,
                                ),
                              );
                            } catch (e) {
                              setState(() => _isLoading = false);

                              final message = _getErrorMessage(e);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(message),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          child: _isLoading
                              ? const CircularProgressIndicator(
                            color: Colors.white,
                          )
                              : const Text("Create Account"),
                        ),
                      ),

                      SizedBox(height: 20.h),

                      ElevatedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () async {
                          final userCred =
                          await _googleAuth.signInWithGoogle();
                          if (userCred != null && context.mounted) {
                            // ✅ تحقق من الدعوة بعد Google Sign In
                            final userId = FirebaseAuth.instance.currentUser?.uid;
                            if (userId != null) {
                              final redeemed = await _firebaseService.redeemInviteCode(inviteCodeController.text);
                              _verifyInviteAndReward(userId);
                            }
                            context.go('/main');
                          }
                        },
                        icon: SvgPicture.asset(
                          'assets/images/google.svg',
                          height: 20.h,
                        ),
                        label: const Text("Sign up with Google"),
                      ),

                      SizedBox(height: 30.h),

                      RichText(
                        text: TextSpan(
                          text: "Already have an account? ",
                          style: const TextStyle(color: Colors.black),
                          children: [
                            TextSpan(
                              text: "Login",
                              style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => context.go('/login'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}