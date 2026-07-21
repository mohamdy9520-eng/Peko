import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:otp/otp.dart';

import '../../../../routes/app_router.dart';
import '../bloc/auth_bloc.dart';


class TOTPService {
  static const int _interval = 30;
  static const int _digits = 6;
  static const String _algorithm = 'SHA1';

  static Future<String> _getAppSecret() async {
    final remoteConfig = FirebaseRemoteConfig.instance;
    await remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: const Duration(hours: 1),
    ));
    await remoteConfig.fetchAndActivate();
    return remoteConfig.getString('totp_app_secret');
  }

  static String _fallbackSecret() {
    throw Exception('TOTP app secret not configured in Firebase Remote Config');
  }

  static Future<String> generateUserSecret(String userId) async {
    String appSecret;
    try {
      appSecret = await _getAppSecret();
    } catch (e) {
      appSecret = _fallbackSecret();
    }

    final data = '$userId:$appSecret';
    final bytes = utf8.encode(data);
    final base64Str = base64.encode(bytes);
    final clean = base64Str.replaceAll(RegExp(r'[^A-Z2-7]'), '');
    return clean.length >= 32 ? clean.substring(0, 32) : clean.padRight(32, 'A');
  }

  static Future<String> generateQRCodeUrl({
    required String userId,
    required String email,
    required String appName,
  }) async {
    final secret = await generateUserSecret(userId);
    return 'otpauth://totp/$appName:${Uri.encodeComponent(email)}'
        '?secret=$secret'
        '&issuer=$appName'
        '&algorithm=$_algorithm'
        '&digits=$_digits'
        '&period=$_interval';
  }

  static Future<String> generateCurrentCode(String userId) async {
    final secret = await generateUserSecret(userId);
    return OTP.generateTOTPCodeString(
      secret,
      DateTime.now().millisecondsSinceEpoch,
      interval: _interval,
      length: _digits,
      algorithm: Algorithm.SHA1,
      isGoogle: true,
    );
  }

  static Future<bool> verifyCode(String userId, String enteredCode) async {
    final secret = await generateUserSecret(userId);
    final now = DateTime.now().millisecondsSinceEpoch;

    final currentCode = OTP.generateTOTPCodeString(
      secret, now,
      interval: _interval, length: _digits,
      algorithm: Algorithm.SHA1, isGoogle: true,
    );
    if (enteredCode == currentCode) return true;

    final previousCode = OTP.generateTOTPCodeString(
      secret, now - (_interval * 1000),
      interval: _interval, length: _digits,
      algorithm: Algorithm.SHA1, isGoogle: true,
    );
    return enteredCode == previousCode;
  }
}


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  bool _obscurePassword = true;

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isBiometricAvailable = false;
  bool _isBiometricEnabled = false;
  bool _hasSavedCredentials = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricState();
  }

  Future<void> _checkBiometricState() async {
    final isAvailable = await _localAuth.canCheckBiometrics;
    final isDeviceSupported = await _localAuth.isDeviceSupported();
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool('biometric_enabled') ?? false;
    final hasCreds = await _secureStorage.read(key: 'biometric_email') != null;

    if (mounted) {
      setState(() {
        _isBiometricAvailable = isAvailable && isDeviceSupported;
        _isBiometricEnabled = isEnabled;
        _hasSavedCredentials = hasCreds;
      });
    }
  }

  Future<void> _saveBiometricCredentials() async {
    await _secureStorage.write(
      key: 'biometric_email',
      value: emailController.text.trim(),
    );
    await _secureStorage.write(
      key: 'biometric_password',
      value: passwordController.text.trim(),
    );
  }


  Future<bool> _isMFAEnabled(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data()?['totp_enabled'] ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _isMFASetupComplete(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data()?['totp_enabled'] ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<void> _showMFASetupDialog(String userId, String email) async {
    final qrUrl = await TOTPService.generateQRCodeUrl(
      userId: userId,
      email: email,
      appName: 'Peco',
    );
    final secret = await TOTPService.generateUserSecret(userId);
    final codeController = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, dialogSetState) {
          bool isVerifying = false;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.security, color: Color(0xFF2E8B7B)),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'Enable Two-Factor Authentication',
                    style: TextStyle(fontSize: 18.sp),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Scan this QR code with any authenticator app (Google Authenticator, Microsoft Authenticator, etc.)',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: QrImageView(
                        data: qrUrl,
                        version: QrVersions.auto,
                        size: 200,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          const Text('Or enter this secret manually:', style: TextStyle(fontSize: 12)),
                          SelectableText(
                            secret,
                            style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: '6-digit Code',
                        counterText: '',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isVerifying ? null : () => Navigator.pop(dialogContext),
                child: Text('Skip', style: TextStyle(color: Colors.grey.shade600)),
              ),
              ElevatedButton(
                onPressed: isVerifying
                    ? null
                    : () async {
                  final code = codeController.text.trim();
                  if (code.length != 6) {
                    _showSnackBar('Please enter a 6-digit code', Colors.orange);
                    return;
                  }

                  dialogSetState(() => isVerifying = true);

                  final isValid = await TOTPService.verifyCode(userId, code);
                  if (isValid) {
                    await _firestore.collection('users').doc(userId).update({
                      'totp_enabled': true,
                      'totp_secret': secret,
                    });

                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                    _showSnackBar('2FA enabled successfully!', Colors.green);
                    _navigateAfterLogin();
                  } else {
                    dialogSetState(() => isVerifying = false);
                    _showSnackBar('Invalid code. Please try again.', Colors.red);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E8B7B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isVerifying
                    ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
                    : const Text('Verify & Enable'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showMFAVerifyDialog(String userId) async {
    final codeController = TextEditingController();

    await showDialog(
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
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield_outlined, size: 48, color: Color(0xFF2E8B7B)),
                  const SizedBox(height: 12),
                  const Text('Enter the 6-digit code from your authenticator app'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'Verification Code',
                      counterText: '',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder(
                    stream: Stream.periodic(const Duration(seconds: 1)),
                    builder: (_, __) {
                      final seconds = 30 - (DateTime.now().second % 30);
                      return Text(
                        'Code expires in $seconds seconds',
                        style: TextStyle(
                          color: seconds < 5 ? Colors.red : Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isVerifying ? null : () {
                  Navigator.pop(dialogContext);
                  setState(() => isLoading = false);
                },
                child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
              ),
              ElevatedButton(
                onPressed: isVerifying
                    ? null
                    : () async {
                  final code = codeController.text.trim();
                  if (code.length != 6) {
                    _showSnackBar('Please enter a 6-digit code', Colors.orange);
                    return;
                  }

                  dialogSetState(() => isVerifying = true);

                  final isValid = await TOTPService.verifyCode(userId, code);
                  if (isValid) {
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                    _navigateAfterLogin();
                  } else {
                    dialogSetState(() => isVerifying = false);
                    _showSnackBar('Invalid code. Please try again.', Colors.red);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E8B7B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isVerifying
                    ? const SizedBox(
                  width: 18, height: 18,
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

  void _navigateAfterLogin() {
    setState(() => isLoading = false);
    context.go('/main');
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }


  Future<void> _authenticateWithBiometric() async {
    try {
      setState(() => isLoading = true);

      final savedEmail = await _secureStorage.read(key: 'biometric_email');
      final savedPassword = await _secureStorage.read(key: 'biometric_password');

      if (savedEmail == null || savedPassword == null) {
        setState(() => isLoading = false);
        _showSnackBar('Please login with email/password first to enable biometric login', Colors.orange);
        return;
      }

      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Use your fingerprint or face to login',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (!didAuthenticate) {
        setState(() => isLoading = false);
        return;
      }

      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: savedEmail,
        password: savedPassword,
      );

      final userId = userCredential.user!.uid;

      final mfaEnabled = await _isMFAEnabled(userId);
      if (mfaEnabled) {
        setState(() => isLoading = false);
        await _showMFAVerifyDialog(userId);
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('biometric_enabled', true);

      if (!mounted) return;
      _navigateAfterLogin();

    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        final msg = _getErrorMessage(e);
        _showSnackBar(msg, Colors.red);
      }
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        String message = 'Biometric authentication failed';
        if (e.code == auth_error.notAvailable) message = 'Biometric not available';
        else if (e.code == auth_error.notEnrolled) message = 'No biometric enrolled';
        else if (e.code == auth_error.passcodeNotSet) message = 'Device passcode not set';
        _showSnackBar(message, Colors.red);
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        _showSnackBar('Login failed: $e', Colors.red);
      }
    }
  }



  String _getErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('invalid-credential') ||
        errorString.contains('wrong-password') ||
        errorString.contains('user-not-found')) {
      return 'Invalid Username/password';
    }

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


  Future<void> login() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => isLoading = true);

      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final user = userCredential.user!;
      final userId = user.uid;
      final email = user.email ?? emailController.text.trim();

      await _saveBiometricCredentials();

      final mfaEnabled = await _isMFAEnabled(userId);

      if (!mfaEnabled) {
        setState(() => isLoading = false);
        await _showMFASetupDialog(userId, email);
        return;
      }

      setState(() => isLoading = false);
      await _showMFAVerifyDialog(userId);

    } on FirebaseAuthException catch (e) {
      setState(() => isLoading = false);
      final msg = _getErrorMessage(e);
      if (mounted) {
        _showSnackBar(msg, Colors.red);
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        _showSnackBar('Login failed: $e', Colors.red);
      }
    }
  }


  Future<void> signInWithGoogle() async {
    try {
      setState(() => isLoading = true);

      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => isLoading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user!;
      final userId = user.uid;

      if (user.email != null) {
        await _secureStorage.write(key: 'biometric_email', value: user.email);
      }

      final userDoc = _firestore.collection('users').doc(userId);
      final snapshot = await userDoc.get();

      if (!snapshot.exists) {
        await userDoc.set({
          'name': user.displayName ?? '',
          'email': user.email ?? '',
          'username': '',
          'totalBalance': 0.0,
          'totalIncome': 0.0,
          'totalExpense': 0.0,
          'createdAt': Timestamp.now(),
          'imageUrl': user.photoURL ?? '',
          'totp_enabled': false,
        });
      }

      final mfaEnabled = await _isMFAEnabled(userId);
      if (mfaEnabled) {
        setState(() => isLoading = false);
        await _showMFAVerifyDialog(userId);
        return;
      }

      if (!snapshot.exists || !(snapshot.data()?['totp_enabled'] ?? false)) {
        setState(() => isLoading = false);
        await _showMFASetupDialog(userId, user.email ?? '');
        return;
      }

      if (!mounted) return;
      _navigateAfterLogin();

    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        _showSnackBar('Google sign-in failed: $e', Colors.red);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) async {
        if (state is AuthLoading) {
          setState(() => isLoading = true);
        }

        if (state is AuthSuccess) {
          await _saveBiometricCredentials();

          final prefs = await SharedPreferences.getInstance();
          final hasSelectedCurrency = prefs.getBool('has_selected_currency') ?? false;

          if (!mounted) return;
          setState(() => isLoading = false);

          if (hasSelectedCurrency) {
            context.go(AppRoutes.home);
          } else {
            context.go(AppRoutes.currency);
          }
        }

        if (state is AuthFailure) {
          if (!mounted) return;
          setState(() => isLoading = false);
          _showSnackBar(state.message, Colors.red);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text("Log In", style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 40.sp
          )),
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20.w, 40.h, 20.w, 20.h),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: emailController,
                        decoration: InputDecoration(
                          labelText: "Email",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: BorderSide(color: Colors.green, width: 2.w),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return "Email is required";
                          if (!value.contains('@')) return "Enter valid email";
                          return null;
                        },
                      ),
                      SizedBox(height: 10.h),
                      TextFormField(
                        controller: passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: "Password",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: BorderSide(color: Colors.green, width: 2.w),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: Colors.grey,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return "Password is required";
                          if (value.length < 6) return "Min 6 characters";
                          return null;
                        },
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: EdgeInsets.only(top: 4.h, right: 4.w),
                          child: GestureDetector(
                            onTap: () => context.go('/forgot-password'),
                            child: Text(
                              "Forgot Password?",
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 20.h),
                      ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            login();
                          }
                        },
                        child: const Text("Login"),
                      ),
                      SizedBox(height: 10.h),
                      Text(
                        "OR",
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w400,
                          color: Colors.grey.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 10.h),
                      ElevatedButton.icon(
                        onPressed: signInWithGoogle,
                        icon: SvgPicture.asset(
                          'assets/images/google.svg',
                          width: 20.w,
                          height: 20.h,
                        ),
                        label: const Text("Login with Google"),
                      ),
                      if (_isBiometricAvailable && _hasSavedCredentials)
                        Column(
                          children: [
                            SizedBox(height: 10.h),
                            ElevatedButton.icon(
                              onPressed: _authenticateWithBiometric,
                              icon: const Icon(Icons.fingerprint, color: Colors.white),
                              label: const Text("Login with Biometric"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E8B7B),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                              ),
                            ),
                          ],
                        ),
                      SizedBox(height: 30.h),
                      Center(
                        child: RichText(
                          text: TextSpan(
                            text: "Don't have an account? ",
                            style: const TextStyle(color: Colors.black),
                            children: [
                              TextSpan(
                                text: "Sign Up",
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => context.go('/signup'),
                              ),
                            ],
                          ),
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