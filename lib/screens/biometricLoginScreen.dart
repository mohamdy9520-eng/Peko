import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:go_router/go_router.dart';

class BiometricLoginScreen extends StatefulWidget {
  const BiometricLoginScreen({super.key});

  @override
  State<BiometricLoginScreen> createState() => _BiometricLoginScreenState();
}

class _BiometricLoginScreenState extends State<BiometricLoginScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  Future<void> _authenticate() async {
    try {
      setState(() => _isLoading = true);

      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Verify your identity to access the app',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (!didAuthenticate) {
        // User cancelled or failed biometric → go to password login
        if (mounted) context.go('/login');
        return;
      }

      // Get saved credentials
      final savedEmail = await _secureStorage.read(key: 'biometric_email');
      final savedPassword = await _secureStorage.read(key: 'biometric_password');

      if (savedEmail == null || savedPassword == null) {
        if (mounted) context.go('/login');
        return;
      }

      // Sign in with saved credentials
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: savedEmail,
        password: savedPassword,
      );

      if (mounted) context.go('/main');

    } on FirebaseAuthException catch (e) {
      if (mounted) {
        _showError(_getErrorMessage(e));
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) context.go('/login');
      }
    } on PlatformException catch (e) {
      if (mounted) {
        String message = 'Biometric authentication failed';
        if (e.code == auth_error.notAvailable) {
          message = 'Biometric not available';
        } else if (e.code == auth_error.notEnrolled) {
          message = 'No biometric enrolled on this device';
        } else if (e.code == auth_error.passcodeNotSet) {
          message = 'Device passcode not set';
        }
        _showError(message);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        _showError('Authentication failed: $e');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) context.go('/login');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('invalid-credential') ||
        errorString.contains('wrong-password') ||
        errorString.contains('user-not-found')) {
      return 'Invalid credentials. Please login again.';
    }

    if (errorString.contains('network') ||
        errorString.contains('timeout')) {
      return 'Network error. Please check your connection.';
    }

    return 'Authentication error. Please try again.';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
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
      backgroundColor: const Color(0xFF2E8B7B),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: _isLoading
                    ? const SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
                    : const Icon(
                  Icons.fingerprint,
                  size: 80,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Pēco',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _isLoading ? 'Verifying...' : 'Touch the fingerprint sensor',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text(
                  'Use password instead',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}