import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted || _navigated) return;
    _navigated = true;

    final prefs = await SharedPreferences.getInstance();
    final secureStorage = const FlutterSecureStorage();

    final languageSelected = prefs.getBool('language_selected') ?? false;

    if (!languageSelected) {
      debugPrint('GOING TO LANGUAGE SELECTION');
      context.go('/language');
      return;
    }

    final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;

    final user = FirebaseAuth.instance.currentUser;
    final isBiometricEnabled = prefs.getBool('biometric_enabled') ?? false;
    final hasCredentials = await secureStorage.read(key: 'biometric_email') != null;

    debugPrint(
      'SPLASH: languageSelected=$languageSelected, '
          'hasSeenOnboarding=$hasSeenOnboarding, '
          'user=${user?.email}, '
          'emailVerified=${user?.emailVerified}, '
          'isBiometricEnabled=$isBiometricEnabled, '
          'hasCredentials=$hasCredentials',
    );

    if (!hasSeenOnboarding) {
      debugPrint('GOING TO ONBOARDING');
      context.go('/onboarding');
    } else if (user == null) {
      // المستخدم غير مسجل → صفحة تسجيل الدخول العادية
      debugPrint('GOING TO LOGIN (No user found)');
      context.go('/login');
    } else if (!user.emailVerified) {
      debugPrint('GOING TO VERIFY EMAIL');
      context.go('/verify-email');
    } else {
      // المستخدم مسجل مسبقًا
      if (isBiometricEnabled && hasCredentials) {
        // مسجل + البصمة شغالة → شاشة البصمة
        debugPrint('GOING TO BIOMETRIC LOGIN');
        context.go('/biometric-login');
      } else {
        // مسجل بس مفيش بصمة → Main مباشرة
        debugPrint('GOING TO MAIN');
        context.go('/main');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF4A9B9B),
              Color(0xFF3A8A8A),
            ],
          ),
        ),
        child: Center(
          child: Image.asset(
            'assets/icon/pēco.png',
            width: 300.w,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
