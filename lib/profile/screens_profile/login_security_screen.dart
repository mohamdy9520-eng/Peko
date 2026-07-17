import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:otp/otp.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/di/services/totp_service.dart';
import '../../routes/app_router.dart';
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
        title: const Text('Login & Security'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSecurityScoreCard(user),
              const SizedBox(height: 24),
              _buildSectionHeader('Account Security'),
              _buildSecurityCard(
                icon: Icons.email_outlined,
                iconColor: Colors.blue,
                title: 'Email Address',
                subtitle: user?.email ?? 'Not available',
                trailing: TextButton(
                  onPressed: () => _showChangeEmailDialog(),
                  child: const Text('Change', style: TextStyle(color: _primaryColor)),
                ),
              ),
              _buildSecurityCard(
                icon: Icons.lock_outline,
                iconColor: Colors.orange,
                title: 'Password',
                subtitle: 'Tap to update your password',
                trailing: TextButton(
                  onPressed: () => _showChangePasswordDialog(),
                  child: const Text('Update', style: TextStyle(color: _primaryColor)),
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionHeader('Authentication Methods'),
              _buildSecurityCard(
                icon: Icons.fingerprint,
                iconColor: Colors.purple,
                title: 'Biometric Login',
                subtitle: _isCheckingBiometric
                    ? 'Checking availability...'
                    : 'Use fingerprint or face recognition',
                trailing: _isCheckingBiometric
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
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
              const SizedBox(height: 24),
              _buildSectionHeader('Active Sessions'),
              _buildSessionCard(user),
              const SizedBox(height: 40),
              _buildSectionHeader('Danger Zone', color: Colors.red),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(16),
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
                    Divider(height: 1, color: Colors.red.shade200, indent: 56),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: CircularProgressIndicator(
                  value: score / maxScore,
                  strokeWidth: 6,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                ),
              ),
              Text(
                '$percentage%',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: scoreColor),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Security Score: $scoreText',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
                ),
                const SizedBox(height: 4),
                Text(
                  percentage >= 75
                      ? 'Your account is well protected!'
                      : 'Complete the steps below to improve security.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
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
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: color ?? Colors.grey.shade500,
          fontSize: 12,
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
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
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
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.phone_android, color: Colors.green.shade600, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _deviceName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Active now • Last sign-in: $formattedDate',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF2E8B7B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'This Device',
                style: TextStyle(color: _primaryColor, fontSize: 12, fontWeight: FontWeight.w600),
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
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDestructive ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isDestructive ? Colors.red.shade400 : Colors.orange.shade400,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDestructive ? Colors.red.shade700 : Colors.orange.shade700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.security, color: _primaryColor),
                  SizedBox(width: 12),
                  Text('Enable 2FA'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Scan this QR code with any authenticator app (Google Authenticator, Microsoft Authenticator, Authy, etc.)',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: QrImageView(
                        data: qrURL,
                        version: QrVersions.auto,
                        size: 200,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              secret,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 18),
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: secret));
                              if (dialogContext.mounted) {
                                ScaffoldMessenger.of(dialogContext).showSnackBar(
                                  const SnackBar(content: Text('Secret copied!'), duration: Duration(seconds: 2)),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Or enter this secret manually in your authenticator app',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Enter the 6-digit code from your authenticator app to verify:',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
                      decoration: InputDecoration(
                        labelText: 'Verification Code',
                        counterText: '',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isVerifying ? null : () => Navigator.pop(dialogContext),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isVerifying
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                      : const Text('Verify & Enable'),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.email, color: _primaryColor),
              SizedBox(width: 12),
              Text('Change Email'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'New Email',
                  prefixIcon: const Icon(Icons.email, color: _primaryColor),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  errorText: _validateEmail(controller.text),
                ),
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => dialogSetState(() {}),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: isObscured,
                decoration: InputDecoration(
                  labelText: 'Current Password (for verification)',
                  prefixIcon: const Icon(Icons.lock, color: _primaryColor),
                  suffixIcon: IconButton(
                    icon: Icon(isObscured ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => dialogSetState(() => isObscured = !isObscured),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
              child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
                  : const Text('Update'),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.lock, color: _primaryColor),
              SizedBox(width: 12),
              Text('Change Password'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPasswordController,
                  obscureText: isCurrentObscured,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    prefixIcon: const Icon(Icons.lock, color: _primaryColor),
                    suffixIcon: IconButton(
                      icon: Icon(isCurrentObscured ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => dialogSetState(() => isCurrentObscured = !isCurrentObscured),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPasswordController,
                  obscureText: isNewObscured,
                  onChanged: (_) => dialogSetState(() {}),
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: const Icon(Icons.lock_outline, color: _primaryColor),
                    suffixIcon: IconButton(
                      icon: Icon(isNewObscured ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => dialogSetState(() => isNewObscured = !isNewObscured),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: isConfirmObscured,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: const Icon(Icons.lock_outline, color: _primaryColor),
                    suffixIcon: IconButton(
                      icon: Icon(isConfirmObscured ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => dialogSetState(() => isConfirmObscured = !isConfirmObscured),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                _buildPasswordRequirements(newPasswordController.text),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
              child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
            ),
            ElevatedButton(
              onPressed: isLoading || !_isPasswordValid(newPasswordController.text)
                  ? null
                  : () async {
                if (currentPasswordController.text.trim().isEmpty) {
                  _showError('Please enter your current password');
                  return;
                }
                if (newPasswordController.text != confirmPasswordController.text) {
                  _showError('Passwords do not match');
                  return;
                }
                dialogSetState(() => isLoading = true);
                try {
                  await _firebaseService.reauthenticate(currentPasswordController.text.trim());
                  await _firebaseService.changePassword(newPasswordController.text);
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
                  : const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  bool _isPasswordValid(String password) {
    return password.length >= 8 &&
        password.contains(RegExp(r'[A-Z]')) &&
        password.contains(RegExp(r'[a-z]')) &&
        password.contains(RegExp(r'[0-9]')) &&
        password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
  }

  Widget _buildPasswordRequirements(String password) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Password Requirements:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          _buildRequirement('At least 8 characters', password.length >= 8),
          _buildRequirement('Contains uppercase letter', password.contains(RegExp(r'[A-Z]'))),
          _buildRequirement('Contains lowercase letter', password.contains(RegExp(r'[a-z]'))),
          _buildRequirement('Contains number', password.contains(RegExp(r'[0-9]'))),
          _buildRequirement('Contains special character', password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))),
        ],
      ),
    );
  }

  Widget _buildRequirement(String text, bool met) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(met ? Icons.check_circle : Icons.circle_outlined, size: 14, color: met ? Colors.green : Colors.grey.shade400),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(fontSize: 12, color: met ? Colors.green.shade700 : Colors.grey.shade500)),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 12),
            Text('Logout'),
          ],
        ),
        content: const Text('Are you sure you want to sign out from this device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              setState(() => _isLoading = true);
              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('biometric_enabled', false);

                await _firebaseService.signOut();
                if (mounted) {
                  context.go(AppRoutes.login);
                }
              } catch (e) {
                if (mounted) {
                  setState(() => _isLoading = false);
                  _showError('Failed to sign out: $e');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    HapticFeedback.mediumImpact();
    final passwordController = TextEditingController();
    bool isObscured = true;
    bool isLoading = false;
    bool isConfirmed = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, dialogSetState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.delete_forever, color: Colors.red),
              SizedBox(width: 12),
              Text('Delete Account'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This action is permanent and cannot be undone.',
                          style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('All your data including:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                const Text('• Profile information'),
                const Text('• Transaction history'),
                const Text('• Friends and messages'),
                const SizedBox(height: 12),
                const Text('will be permanently deleted.'),
                const SizedBox(height: 16),
                CheckboxListTile(
                  value: isConfirmed,
                  onChanged: (value) => dialogSetState(() => isConfirmed = value ?? false),
                  title: const Text('I understand and want to delete my account'),
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: Colors.red,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: isObscured,
                  decoration: InputDecoration(
                    labelText: 'Current Password (required)',
                    prefixIcon: const Icon(Icons.lock, color: Colors.red),
                    suffixIcon: IconButton(
                      icon: Icon(isObscured ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => dialogSetState(() => isObscured = !isObscured),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
              child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
            ),
            ElevatedButton(
              onPressed: isLoading || !isConfirmed || passwordController.text.trim().isEmpty
                  ? null
                  : () async {
                dialogSetState(() => isLoading = true);
                try {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('biometric_enabled', false);
                  await _secureStorage.delete(key: 'biometric_email');
                  await _secureStorage.delete(key: 'biometric_password');

                  await _firebaseService.reauthenticate(passwordController.text.trim());
                  await _firebaseService.deleteAccount();
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (mounted) {
                    _showSuccess('Account deleted successfully');
                    context.go(AppRoutes.login);
                  }
                } catch (e) {
                  dialogSetState(() => isLoading = false);
                  _showError('Failed to delete account: $e');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
                  : const Text('Delete Account'),
            ),
          ],
        ),
      ),
    );
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
}
