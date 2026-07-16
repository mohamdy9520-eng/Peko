import 'package:cloud_firestore/cloud_firestore.dart';
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

import '../../../../routes/app_router.dart';
import '../bloc/auth_bloc.dart';

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

  // Biometric
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool _isBiometricAvailable = false;
  bool _isBiometricEnabled = false;

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

    print('isAvailable: $isAvailable');
    print('isDeviceSupported: $isDeviceSupported');
    print('isEnabled: $isEnabled');
    print('_isBiometricAvailable: ${isAvailable && isDeviceSupported}');

    if (mounted) {
      setState(() {
        _isBiometricAvailable = isAvailable && isDeviceSupported;
        _isBiometricEnabled = isEnabled;
      });
    }
  }

  Future<void> _authenticateWithBiometric() async {
    try {
      setState(() => isLoading = true);

      // Check if credentials exist first
      final savedEmail = await _secureStorage.read(key: 'biometric_email');
      final savedPassword = await _secureStorage.read(key: 'biometric_password');

      if (savedEmail == null || savedPassword == null) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login with email/password first to enable biometric login'),
            backgroundColor: Colors.orange,
          ),
        );
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

      // Use FirebaseAuth directly for biometric login
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: savedEmail,
        password: savedPassword,
      );

      // Re-enable biometric flag so next app open shows biometric screen
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('biometric_enabled', true);

      if (!mounted) return;
      context.go('/main');

    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        final msg = _getErrorMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        String message = 'Biometric authentication failed';
        if (e.code == auth_error.notAvailable) {
          message = 'Biometric not available';
        } else if (e.code == auth_error.notEnrolled) {
          message = 'No biometric enrolled on this device';
        } else if (e.code == auth_error.passcodeNotSet) {
          message = 'Device passcode not set';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
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

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // Save credentials for biometric login using Secure Storage
      await _secureStorage.write(
        key: 'biometric_email',
        value: emailController.text.trim(),
      );
      await _secureStorage.write(
        key: 'biometric_password',
        value: passwordController.text.trim(),
      );

      // Check if user previously had biometric enabled (credentials existed before)
      // If yes, re-enable the flag so next app open shows biometric screen
      final prefs = await SharedPreferences.getInstance();
      final hadBiometricBefore = await _secureStorage.read(key: 'biometric_email') != null;
      if (hadBiometricBefore) {
        await prefs.setBool('biometric_enabled', true);
      }

      if (!mounted) return;
      context.go('/main');
    } on FirebaseAuthException catch (e) {
      final msg = _getErrorMessage(e);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      setState(() => isLoading = true);

      final googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
      await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      final user = userCredential.user!;

      final userDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

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
        });
      }

      if (!mounted) return;
      context.go('/main');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Google sign-in failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) async {
        if (state is AuthLoading) {
          // Loading is handled by isLoading state
        }

        if (state is AuthSuccess) {
          // Save credentials for biometric login using Secure Storage
          await _secureStorage.write(
            key: 'biometric_email',
            value: emailController.text.trim(),
          );
          await _secureStorage.write(
            key: 'biometric_password',
            value: passwordController.text.trim(),
          );

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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text("Log In", style: TextStyle(
            fontWeight: FontWeight.bold, fontSize: 40.sp
        ),)),
        body: GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
          },
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
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: BorderSide(
                              color: Colors.green,
                              width: 2.w,
                            ),
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
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: BorderSide(
                              color: Colors.green,
                              width: 2.w,
                            ),
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

                      if (_isBiometricAvailable)
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
                                  ..onTap = () {
                                    context.go('/signup');
                                  },
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