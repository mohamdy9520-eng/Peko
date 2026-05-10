import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool isEmailSent = false;
  bool isVerified = false;
  String? errorMessage;
  int _countdown = 60; //
  Timer? _countdownTimer;
  Timer? _checkTimer;

  @override
  void initState() {
    super.initState();
    sendVerificationEmail();
    startCountdown();
    startChecking();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _checkTimer?.cancel();
    super.dispose();
  }

  void startCountdown() {
    setState(() => _countdown = 60);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
      }
    });
  }

  void startChecking() {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 3), (_) => checkEmailVerified());
  }

  Future<void> sendVerificationEmail() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => errorMessage = 'No user logged in');
        return;
      }
      await user.sendEmailVerification();
      setState(() {
        isEmailSent = true;
        errorMessage = null;
      });
    } catch (e) {
      setState(() => errorMessage = 'Error: $e');
    }
  }

  Future<void> checkEmailVerified() async {
    try {
      await FirebaseAuth.instance.currentUser?.reload();
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.emailVerified && !isVerified) {
        setState(() => isVerified = true);
        _countdownTimer?.cancel();
        _checkTimer?.cancel();
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) context.go('/main');
      }
    } catch (e) {
      debugPrint('Error checking: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.red,
        body: Center(
          child: Text(errorMessage!, style: const TextStyle(color: Colors.white, fontSize: 18)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F3),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120.w,
                height: 120.h,
                decoration: BoxDecoration(
                  color: const Color(0xFF5FA89E).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.mark_email_unread_outlined, size: 60.sp, color: Color(0xFF5FA89E)),
              ),
              SizedBox(height: 32.h),
              Text('Verify Your Email', style: TextStyle(fontSize: 28.sp, fontWeight: FontWeight.bold, color: Color(0xFF3E8E86))),
              SizedBox(height: 16.h),
              Text(
                'We sent a verification link to:\n${FirebaseAuth.instance.currentUser?.email ?? 'your email'}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16.sp, color: Colors.grey, height: 1.5.h),
              ),
              SizedBox(height: 40.h),

              if (isVerified)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12.r)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8.w),
                      Text('Email Verified!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF5FA89E)),
                    SizedBox(height: 16.h),
                    Text(
                      'Checking email verification...',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),

              SizedBox(height: 40.h),

              SizedBox(
                width: double.infinity,
                height: 55.h,
                child: ElevatedButton(
                  onPressed: _countdown > 0
                      ? null
                      : () {
                    sendVerificationEmail();
                    startCountdown();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5FA89E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.r)),
                    elevation: 6,
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: Text(
                    _countdown > 0 ? 'Wait $_countdown seconds...' : 'Resend Email',
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: _countdown > 0 ? Colors.grey.shade600 : Colors.white,
                    ),
                  ),
                ),
              ),

              SizedBox(height: 16.h),

              TextButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (mounted) context.go('/login');
                },
                child: const Text('Cancel & Logout', style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}