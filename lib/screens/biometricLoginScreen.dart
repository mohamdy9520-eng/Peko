import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/di/services/totp_service.dart';

class BiometricLoginScreen extends StatefulWidget {
  const BiometricLoginScreen({super.key});

  @override
  State<BiometricLoginScreen> createState() => _BiometricLoginScreenState();
}

class _BiometricLoginScreenState extends State<BiometricLoginScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
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
        if (mounted) context.go('/login');
        return;
      }

      final savedEmail = await _secureStorage.read(key: 'biometric_email');
      final savedPassword = await _secureStorage.read(key: 'biometric_password');

      if (savedEmail == null || savedPassword == null) {
        if (mounted) context.go('/login');
        return;
      }

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: savedEmail,
        password: savedPassword,
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        final isTotpEnabled = doc.data()?['totp_enabled'] ?? false;

        if (isTotpEnabled) {
          if (mounted) {
            setState(() => _isLoading = false);
            _showTOTPVerificationDialog(user.uid);
            return;
          }
        }
      }

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

  void _showTOTPVerificationDialog(String userId) {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, dialogSetState) {
          bool isVerifying = false;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.security, color: Color(0xFF2E8B7B)),
                SizedBox(width: 12),
                Text('Two-Factor Authentication'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter the 6-digit code from your authenticator app',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Verification Code',
                    counterText: '',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isVerifying ? null : () {
                  Navigator.pop(dialogContext);
                  context.go('/login');
                },
                child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
              ),
              ElevatedButton(
                onPressed: isVerifying
                    ? null
                    : () async {
                  final enteredCode = codeController.text.trim();
                  if (enteredCode.length != 6) {
                    _showError('Please enter a 6-digit code');
                    return;
                  }

                  dialogSetState(() => isVerifying = true);

                  try {
                    final isValid = TOTPService.verifyCode(userId, enteredCode);

                    if (await isValid) {
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                      if (mounted) context.go('/main');
                    } else {
                      dialogSetState(() => isVerifying = false);
                      _showError('Invalid code. Please try again.');
                    }
                  } catch (e) {
                    dialogSetState(() => isVerifying = false);
                    _showError('Verification failed: $e');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E8B7B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isVerifying
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
                    : const Text('Verify'),
              ),
            ],
          );
        },
      ),
    );
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
                'Peko',
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
