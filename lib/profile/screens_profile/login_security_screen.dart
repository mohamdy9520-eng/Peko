import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/di/services/totp_service.dart';
import '../fireBase_service/fireBase_service.dart';

class LoginSecurityScreen extends StatefulWidget {
  const LoginSecurityScreen({super.key});
  @override State<LoginSecurityScreen> createState() => _LoginSecurityScreenState();
}

class _LoginSecurityScreenState extends State<LoginSecurityScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _is2FAEnabled = false;
  bool _isBiometricEnabled = false;
  bool _isLoading = false;
  bool _isCheckingBiometric = false;
  String _deviceName = 'Unknown Device';
  static const Color _primaryColor = Color(0xFF2E8B7B);

  @override
  void initState() {
    super.initState();
    _loadBiometricState();
    _loadDeviceInfo();
    _load2FAState();
  }

  Future<void> _load2FAState() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (mounted && doc.exists) {
        setState(() => _is2FAEnabled = doc.data()?['totp_enabled'] ?? false);
      }
    } catch (e) {
      debugPrint('Error loading 2FA state: $e');
    }
  }

  Future<void> _loadBiometricState() async {
    final isAvailable = await _localAuth.canCheckBiometrics;
    final isDeviceSupported = await _localAuth.isDeviceSupported();
    final prefs = await SharedPreferences.getInstance();
    final savedEnabled = prefs.getBool('biometric_enabled') ?? false;

    if (mounted) {
      setState(() {
        _isBiometricEnabled = savedEnabled && isAvailable && isDeviceSupported;
      });
    }
  }

  Future<void> _loadDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Theme.of(context).platform == TargetPlatform.android) {
        final androidInfo = await deviceInfo.androidInfo;
        setState(() => _deviceName = '${androidInfo.manufacturer} ${androidInfo.model}');
      } else {
        final iosInfo = await deviceInfo.iosInfo;
        setState(() => _deviceName = iosInfo.utsname.machine ?? 'iPhone');
      }
    } catch (e) {
      debugPrint('Device info error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text('Login & Security', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w600)),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 600.w),
              child: ListView(
                padding: EdgeInsets.all(16.r),
                children: [
                  _buildSecurityScoreCard(user),
                  SizedBox(height: 24.h),
                  _buildSectionHeader('Account Security'),
                  _buildSecurityCard(
                    icon: Icons.email_outlined,
                    iconColor: Colors.blue,
                    title: 'Email Address',
                    subtitle: user?.email ?? 'Not available',
                    trailing: TextButton(
                      onPressed: () => _showChangeEmailDialog(),
                      child: Text('Change', style: TextStyle(color: _primaryColor, fontSize: 14.sp)),
                    ),
                  ),
                  _buildSecurityCard(
                    icon: Icons.lock_outline,
                    iconColor: Colors.orange,
                    title: 'Password',
                    subtitle: 'Tap to update your password',
                    trailing: TextButton(
                      onPressed: () => _showChangePasswordDialog(),
                      child: Text('Update', style: TextStyle(color: _primaryColor, fontSize: 14.sp)),
                    ),
                  ),
                  SizedBox(height: 24.h),
                  _buildSectionHeader('Authentication Methods'),
                  _buildSecurityCard(
                    icon: Icons.fingerprint,
                    iconColor: Colors.purple,
                    title: 'Biometric Login',
                    subtitle: _isCheckingBiometric
                        ? 'Checking availability...'
                        : 'Use fingerprint or face recognition',
                    trailing: _isCheckingBiometric
                        ? SizedBox(width: 20.r, height: 20.r, child: CircularProgressIndicator(strokeWidth: 2.w))
                        : Switch(
                      value: _isBiometricEnabled,
                      onChanged: (value) => _handleBiometricToggle(value),
                      activeColor: _primaryColor,
                    ),
                  ),
                  _buildSecurityCard(
                    icon: Icons.security,
                    iconColor: _primaryColor,
                    title: 'Two-Factor Authentication (TOTP)',
                    subtitle: _is2FAEnabled ? 'Currently enabled' : 'Add an extra layer of security with QR Code',
                    trailing: Switch(
                      value: _is2FAEnabled,
                      onChanged: (value) => _handle2FAToggle(value),
                      activeColor: _primaryColor,
                    ),
                  ),
                  SizedBox(height: 24.h),
                  _buildSectionHeader('Active Sessions'),
                  _buildSessionCard(user),
                  SizedBox(height: 40.h),
                  _buildSectionHeader('Danger Zone', color: Colors.red),
                  SizedBox(height: 12.h),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      children: [
                        _buildDangerTile(
                          icon: Icons.logout,
                          title: 'Logout',
                          subtitle: 'Sign out from this device',
                          onTap: () => _showLogoutDialog(),
                        ),
                        Divider(height: 1.h, color: Colors.red.shade200, indent: 56.w),
                        _buildDangerTile(
                          icon: Icons.delete_forever,
                          title: 'Delete Account',
                          subtitle: 'Permanently delete your account and data',
                          onTap: () => _showDeleteAccountDialog(),
                          isDestructive: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(color: _primaryColor),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSecurityScoreCard(User? user) {
    int score = 0, maxScore = 4;
    if (user?.email != null) score++;
    if (user?.emailVerified == true) score++;
    if (_is2FAEnabled) score++;
    if (_isBiometricEnabled) score++;
    final percentage = (score / maxScore * 100).round();
    final scoreColor = percentage >= 75 ? Colors.green : percentage >= 50 ? Colors.orange : Colors.red;
    final scoreText = percentage >= 75 ? 'Strong' : percentage >= 50 ? 'Fair' : 'Weak';

    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 64.r,
                height: 64.r,
                child: CircularProgressIndicator(
                  value: score / maxScore,
                  strokeWidth: 6.w,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                ),
              ),
              Text(
                '$percentage%',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: scoreColor),
              ),
            ],
          ),
          SizedBox(width: 20.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Security Score: $scoreText',
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A2E)),
                ),
                SizedBox(height: 4.h),
                Text(
                  percentage >= 75
                      ? 'Your account is well protected!'
                      : 'Complete the steps below to improve security.',
                  style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {Color? color}) {
    return Padding(
      padding: EdgeInsets.only(left: 4.w, bottom: 12.h),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: color ?? Colors.grey.shade500,
          fontSize: 12.sp,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSecurityCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(icon, color: iconColor, size: 22.r),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A2E)),
                  ),
                  SizedBox(height: 2.h),
                  Text(subtitle, style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade500)),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(User? user) {
    final lastSignIn = user?.metadata.lastSignInTime;
    final formattedDate = lastSignIn != null
        ? '${lastSignIn.day}/${lastSignIn.month}/${lastSignIn.year} at ${lastSignIn.hour}:${lastSignIn.minute.toString().padLeft(2, '0')}'
        : 'Unknown';
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(Icons.phone_android, color: Colors.green.shade600, size: 22.r),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _deviceName,
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A2E)),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Active now • Last sign-in: $formattedDate',
                    style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: const Color(0xFF2E8B7B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text(
                'This Device',
                style: TextStyle(color: _primaryColor, fontSize: 12.sp, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                color: isDestructive ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                icon,
                color: isDestructive ? Colors.red.shade400 : Colors.orange.shade400,
                size: 22.r,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: isDestructive ? Colors.red.shade700 : Colors.orange.shade700,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(subtitle, style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 24.r),
          ],
        ),
      ),
    );
  }

  Future<void> _handleBiometricToggle(bool value) async {
    HapticFeedback.lightImpact();
    setState(() => _isCheckingBiometric = true);

    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();

      if (!isAvailable || !isDeviceSupported) {
        if (mounted) {
          _showError('Biometric authentication is not available on this device');
        }
        return;
      }

      if (value) {
        final savedEmail = await _secureStorage.read(key: 'biometric_email');
        final savedPassword = await _secureStorage.read(key: 'biometric_password');

        if (savedEmail == null || savedPassword == null) {
          if (mounted) {
            _showError('Please login with email/password first to enable biometric login');
            setState(() => _isCheckingBiometric = false);
          }
          return;
        }

        final didAuthenticate = await _localAuth.authenticate(
          localizedReason: 'Authenticate to enable biometric login',
          options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuth: true,
            useErrorDialogs: true,
          ),
        );

        if (mounted) {
          setState(() => _isBiometricEnabled = didAuthenticate);
          if (didAuthenticate) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('biometric_enabled', true);
            _showSuccess('Biometric login enabled');
          } else {
            _showError('Biometric authentication failed');
          }
        }
      } else {
        setState(() => _isBiometricEnabled = false);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('biometric_enabled', false);
        _showSuccess('Biometric login disabled');
      }
    } catch (e) {
      if (mounted) _showError('Biometric error: $e');
    } finally {
      if (mounted) setState(() => _isCheckingBiometric = false);
    }
  }

  void _handle2FAToggle(bool value) async {
    if (value) {
      _show2FASetupDialog();
    } else {
      try {
        setState(() => _isLoading = true);
        final user = FirebaseAuth.instance.currentUser!;

        await _firestore.collection('users').doc(user.uid).update({
          'totp_enabled': false,
          'totp_secret': null,
        });

        if (mounted) {
          setState(() {
            _is2FAEnabled = false;
            _isLoading = false;
          });
          _showSuccess('Two-Factor Authentication disabled');
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showError('Failed to disable 2FA: $e');
        }
      }
    }
  }

  void _show2FASetupDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final secret = await TOTPService.generateUserSecret(user.uid);

      final String qrURL = await TOTPService.generateQRCodeUrl(
        userId: user.uid,
        email: user.email ?? '',
        appName: 'Peko',
      );

      setState(() => _isLoading = false);

      if (!mounted) return;

      final codeController = TextEditingController();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, dialogSetState) {
            bool isVerifying = false;
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
              title: Row(
                children: [
                  Icon(Icons.security, color: _primaryColor, size: 24.r),
                  SizedBox(width: 12.w),
                  Text('Enable 2FA', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Scan this QR code with any authenticator app (Google Authenticator, Microsoft Authenticator, Authy, etc.)',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14.sp),
                    ),
                    SizedBox(height: 16.h),
                    Container(
                      padding: EdgeInsets.all(12.r),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: QrImageView(
                        data: qrURL,
                        version: QrVersions.auto,
                        size: 200.r,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Container(
                      padding: EdgeInsets.all(12.r),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              secret,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.copy, size: 18.r),
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: secret));
                              if (dialogContext.mounted) {
                                ScaffoldMessenger.of(dialogContext).showSnackBar(
                                  SnackBar(content: Text('Secret copied!', style: TextStyle(fontSize: 14.sp)), duration: const Duration(seconds: 2)),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Or enter this secret manually in your authenticator app',
                      style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
                    ),
                    SizedBox(height: 20.h),
                    Text(
                      'Enter the 6-digit code from your authenticator app to verify:',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14.sp),
                    ),
                    SizedBox(height: 12.h),
                    TextField(
                      controller: codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold, letterSpacing: 8.w),
                      decoration: InputDecoration(
                        labelText: 'Verification Code',
                        counterText: '',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                        contentPadding: EdgeInsets.symmetric(vertical: 16.h),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isVerifying ? null : () => Navigator.pop(dialogContext),
                  child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600, fontSize: 14.sp)),
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
                      final isValid = await TOTPService.verifyCode(user.uid, enteredCode);

                      if (isValid) {
                        await _firestore.collection('users').doc(user.uid).update({
                          'totp_enabled': true,
                          'totp_secret': secret,
                        });

                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        if (mounted) {
                          setState(() => _is2FAEnabled = true);
                          _showSuccess('Two-Factor Authentication enabled successfully!');
                        }
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
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                  child: isVerifying
                      ? SizedBox(
                    width: 20.r,
                    height: 20.r,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.w),
                  )
                      : Text('Verify & Enable', style: TextStyle(fontSize: 14.sp)),
                ),
              ],
            );
          },
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to initialize 2FA: $e');
    }
  }

  void _showChangeEmailDialog() {
    final controller = TextEditingController();
    final passwordController = TextEditingController();
    bool isObscured = true;
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, dialogSetState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          title: Row(
            children: [
              Icon(Icons.email, color: _primaryColor, size: 24.r),
              SizedBox(width: 12.w),
              Text('Change Email', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                style: TextStyle(fontSize: 14.sp),
                decoration: InputDecoration(
                  labelText: 'New Email',
                  prefixIcon: Icon(Icons.email, color: _primaryColor, size: 20.r),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                  errorText: _validateEmail(controller.text),
                ),
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => dialogSetState(() {}),
              ),
              SizedBox(height: 16.h),
              TextField(
                controller: passwordController,
                obscureText: isObscured,
                style: TextStyle(fontSize: 14.sp),
                decoration: InputDecoration(
                  labelText: 'Current Password (for verification)',
                  prefixIcon: Icon(Icons.lock, color: _primaryColor, size: 20.r),
                  suffixIcon: IconButton(
                    icon: Icon(isObscured ? Icons.visibility_off : Icons.visibility, size: 20.r),
                    onPressed: () => dialogSetState(() => isObscured = !isObscured),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
              child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600, fontSize: 14.sp)),
            ),
            ElevatedButton(
              onPressed: isLoading || _validateEmail(controller.text) != null
                  ? null
                  : () async {
                if (passwordController.text.trim().isEmpty) {
                  _showError('Please enter your current password');
                  return;
                }
                dialogSetState(() => isLoading = true);
                try {
                  await _firebaseService.reauthenticate(passwordController.text.trim());
                  await _firebaseService.changeEmail(controller.text.trim());
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  _showSuccess('Verification email sent to ${controller.text.trim()}. Please check your inbox and verify.');
                } catch (e) {
                  dialogSetState(() => isLoading = false);
                  _showError(e.toString());
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              child: isLoading
                  ? SizedBox(
                width: 20.r,
                height: 20.r,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.w),
              )
                  : Text('Update', style: TextStyle(fontSize: 14.sp)),
            ),
          ],
        ),
      ),
    );
  }

  String? _validateEmail(String email) {
    if (email.trim().isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email.trim())) return 'Invalid email format';
    return null;
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isCurrentObscured = true;
    bool isNewObscured = true;
    bool isConfirmObscured = true;
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, dialogSetState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          title: Row(
            children: [
              Icon(Icons.lock, color: _primaryColor, size: 24.r),
              SizedBox(width: 12.w),
              Text('Change Password', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPasswordController,
                  obscureText: isCurrentObscured,
                  style: TextStyle(fontSize: 14.sp),
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    prefixIcon: Icon(Icons.lock, color: _primaryColor, size: 20.r),
                    suffixIcon: IconButton(
                      icon: Icon(isCurrentObscured ? Icons.visibility_off : Icons.visibility, size: 20.r),
                      onPressed: () => dialogSetState(() => isCurrentObscured = !isCurrentObscured),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                ),
                SizedBox(height: 12.h),
                TextField(
                  controller: newPasswordController,
                  obscureText: isNewObscured,
                  style: TextStyle(fontSize: 14.sp),
                  onChanged: (_) => dialogSetState(() {}),
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: Icon(Icons.lock_outline, color: _primaryColor, size: 20.r),
                    suffixIcon: IconButton(
                      icon: Icon(isNewObscured ? Icons.visibility_off : Icons.visibility, size: 20.r),
                      onPressed: () => dialogSetState(() => isNewObscured = !isNewObscured),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                ),
                SizedBox(height: 12.h),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: isConfirmObscured,
                  style: TextStyle(fontSize: 14.sp),
                  onChanged: (_) => dialogSetState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: Icon(Icons.lock_outline, color: _primaryColor, size: 20.r),
                    suffixIcon: IconButton(
                      icon: Icon(isConfirmObscured ? Icons.visibility_off : Icons.visibility, size: 20.r),
                      onPressed: () => dialogSetState(() => isConfirmObscured = !isConfirmObscured),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
              child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600, fontSize: 14.sp)),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                if (currentPasswordController.text.trim().isEmpty ||
                    newPasswordController.text.trim().isEmpty ||
                    confirmPasswordController.text.trim().isEmpty) {
                  _showError('All fields are required');
                  return;
                }
                if (newPasswordController.text.trim() != confirmPasswordController.text.trim()) {
                  _showError('New passwords do not match');
                  return;
                }
                if (newPasswordController.text.trim().length < 6) {
                  _showError('Password must be at least 6 characters');
                  return;
                }
                dialogSetState(() => isLoading = true);
                try {
                  await _firebaseService.reauthenticate(currentPasswordController.text.trim());
                  await _firebaseService.changePassword(newPasswordController.text.trim());
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  _showSuccess('Password updated successfully!');
                } catch (e) {
                  dialogSetState(() => isLoading = false);
                  _showError(e.toString());
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              child: isLoading
                  ? SizedBox(
                width: 20.r,
                height: 20.r,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.w),
              )
                  : Text('Update Password', style: TextStyle(fontSize: 14.sp)),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Text('Logout', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to sign out from this device?', style: TextStyle(fontSize: 14.sp)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600, fontSize: 14.sp)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await _firebaseService.signOut();
                if (mounted) context.go('/login');
              } catch (e) {
                _showError('Failed to logout: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
            child: Text('Logout', style: TextStyle(fontSize: 14.sp)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final passwordController = TextEditingController();
    bool isObscured = true;
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, dialogSetState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red, size: 24.r),
              SizedBox(width: 12.w),
              Text('Delete Account', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'This action cannot be undone. All your data will be permanently deleted.',
                style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w500, fontSize: 14.sp),
              ),
              SizedBox(height: 16.h),
              TextField(
                controller: passwordController,
                obscureText: isObscured,
                style: TextStyle(fontSize: 14.sp),
                decoration: InputDecoration(
                  labelText: 'Enter Password to Confirm',
                  prefixIcon: Icon(Icons.lock, color: Colors.red, size: 20.r),
                  suffixIcon: IconButton(
                    icon: Icon(isObscured ? Icons.visibility_off : Icons.visibility, size: 20.r),
                    onPressed: () => dialogSetState(() => isObscured = !isObscured),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
              child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600, fontSize: 14.sp)),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                if (passwordController.text.trim().isEmpty) {
                  _showError('Please enter your password');
                  return;
                }
                dialogSetState(() => isLoading = true);
                try {
                  await _firebaseService.reauthenticate(passwordController.text.trim());
                  await _firebaseService.deleteAccount();
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (mounted) context.go('/login');
                } catch (e) {
                  dialogSetState(() => isLoading = false);
                  _showError(e.toString());
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              child: isLoading
                  ? SizedBox(
                width: 20.r,
                height: 20.r,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.w),
              )
                  : Text('Delete Permanently', style: TextStyle(fontSize: 14.sp)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(fontSize: 14.sp)),
        backgroundColor: _primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
        margin: EdgeInsets.all(16.r),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(fontSize: 14.sp)),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
        margin: EdgeInsets.all(16.r),
      ),
    );
  }
}