import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_router.dart';
import '../fireBase_service/fireBase_service.dart';

class LoginSecurityScreen extends StatefulWidget {
  const LoginSecurityScreen({super.key});
  @override State<LoginSecurityScreen> createState() => _LoginSecurityScreenState();
}

class _LoginSecurityScreenState extends State<LoginSecurityScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _is2FAEnabled = false;
  bool _isBiometricEnabled = false;
  bool _isLoading = false;
  static const Color _primaryColor = Color(0xFF2E8B7B);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: const Text('Login & Security'), backgroundColor: _primaryColor, foregroundColor: Colors.white, elevation: 0),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSecurityScoreCard(user),
          const SizedBox(height: 24),
          _buildSectionHeader('Account Security'),
          _buildSecurityCard(
              icon: Icons.email_outlined, iconColor: Colors.blue, title: 'Email Address',
              subtitle: user?.email ?? 'Not available',
              trailing: TextButton(onPressed: () => _showChangeEmailDialog(),
                  child: const Text('Change', style: TextStyle(color: _primaryColor)))),
          _buildSecurityCard(
              icon: Icons.lock_outline, iconColor: Colors.orange, title: 'Password',
              subtitle: 'Tap to update your password',
              trailing: TextButton(onPressed: () => _showChangePasswordDialog(),
                  child: const Text('Update', style: TextStyle(color: _primaryColor)))),
          const SizedBox(height: 24),
          _buildSectionHeader('Authentication Methods'),
          _buildSecurityCard(
              icon: Icons.fingerprint, iconColor: Colors.purple, title: 'Biometric Login',
              subtitle: 'Use fingerprint or face recognition',
              trailing: Switch(value: _isBiometricEnabled, onChanged: (value) {
                setState(() => _isBiometricEnabled = value);
                HapticFeedback.lightImpact();
                _showSuccess(_isBiometricEnabled ? 'Biometric login enabled' : 'Biometric login disabled');
              }, activeColor: _primaryColor)),
          _buildSecurityCard(
              icon: Icons.security, iconColor: _primaryColor, title: 'Two-Factor Authentication',
              subtitle: _is2FAEnabled ? 'Currently enabled' : 'Add an extra layer of security',
              trailing: Switch(value: _is2FAEnabled, onChanged: (value) {
                setState(() => _is2FAEnabled = value);
                if (value) _show2FASetupDialog();
              }, activeColor: _primaryColor)),
          const SizedBox(height: 24),
          _buildSectionHeader('Active Sessions'),
          _buildSessionCard(user),
          const SizedBox(height: 40),
          _buildSectionHeader('Danger Zone', color: Colors.red),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
                color: Colors.red.shade50, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.shade200)),
            child: Column(children: [
              _buildDangerTile(icon: Icons.logout, title: 'Logout', subtitle: 'Sign out from this device', onTap: () => _showLogoutDialog()),
              Divider(height: 1, color: Colors.red.shade200, indent: 56),
              _buildDangerTile(icon: Icons.delete_forever, title: 'Delete Account',
                  subtitle: 'Permanently delete your account and data', onTap: () => _showDeleteAccountDialog(), isDestructive: true),
            ]),
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Row(children: [
        Stack(alignment: Alignment.center, children: [
          SizedBox(width: 64, height: 64,
              child: CircularProgressIndicator(value: score / maxScore, strokeWidth: 6,
                  backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation<Color>(scoreColor))),
          Text('$percentage%', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: scoreColor)),
        ]),
        const SizedBox(width: 20),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Security Score: $scoreText', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
            const SizedBox(height: 4),
            Text(percentage >= 75 ? 'Your account is well protected!' : 'Complete the steps below to improve security.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildSectionHeader(String title, {Color? color}) {
    return Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 12),
        child: Text(title.toUpperCase(),
            style: TextStyle(color: color ?? Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2)));
  }

  Widget _buildSecurityCard({required IconData icon, required Color iconColor, required String title,
    required String subtitle, required Widget trailing}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor, size: 22)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
            ]),
          ),
          trailing,
        ]),
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.phone_android, color: Colors.green.shade600, size: 22)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Current Device', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
              const SizedBox(height: 2),
              Text('Active now • Last sign-in: $formattedDate', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
            ]),
          ),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFF2E8B7B).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: const Text('This Device', style: TextStyle(color: _primaryColor, fontSize: 12, fontWeight: FontWeight.w600))),
        ]),
      ),
    );
  }

  Widget _buildDangerTile({required IconData icon, required String title, required String subtitle,
    required VoidCallback onTap, bool isDestructive = false}) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: isDestructive ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: isDestructive ? Colors.red.shade400 : Colors.orange.shade400, size: 22)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                  color: isDestructive ? Colors.red.shade700 : Colors.orange.shade700)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
            ]),
          ),
          Icon(Icons.chevron_right, color: Colors.grey.shade400),
        ]),
      ),
    );
  }

  void _showChangeEmailDialog() {
    final controller = TextEditingController();
    final passwordController = TextEditingController();
    bool isObscured = true, isLoading = false;
    showDialog(context: context, builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [Icon(Icons.email, color: _primaryColor), SizedBox(width: 12), Text('Change Email')]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: controller,
              decoration: InputDecoration(labelText: 'New Email', prefixIcon: const Icon(Icons.email, color: _primaryColor),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 16),
          TextField(controller: passwordController, obscureText: isObscured,
              decoration: InputDecoration(labelText: 'Current Password (for verification)',
                  prefixIcon: const Icon(Icons.lock, color: _primaryColor),
                  suffixIcon: IconButton(icon: Icon(isObscured ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => isObscured = !isObscured)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600))),
          ElevatedButton(
              onPressed: isLoading ? null : () async {
                if (controller.text.trim().isEmpty) { _showError('Please enter a valid email'); return; }
                setState(() => isLoading = true);
                try {
                  await _firebaseService.reauthenticate(passwordController.text);
                  await _firebaseService.changeEmail(controller.text.trim());
                  Navigator.pop(context);
                  _showSuccess('Verification email sent to ${controller.text.trim()}');
                } catch (e) { setState(() => isLoading = false); _showError(e.toString()); }
              },
              style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Update')),
        ],
      ),
    ));
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isCurrentObscured = true, isNewObscured = true, isConfirmObscured = true, isLoading = false;
    showDialog(context: context, builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [Icon(Icons.lock, color: _primaryColor), SizedBox(width: 12), Text('Change Password')]),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: currentPasswordController, obscureText: isCurrentObscured,
                decoration: InputDecoration(labelText: 'Current Password', prefixIcon: const Icon(Icons.lock, color: _primaryColor),
                    suffixIcon: IconButton(icon: Icon(isCurrentObscured ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => isCurrentObscured = !isCurrentObscured)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 12),
            TextField(controller: newPasswordController, obscureText: isNewObscured, onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: 'New Password', prefixIcon: const Icon(Icons.lock_outline, color: _primaryColor),
                    suffixIcon: IconButton(icon: Icon(isNewObscured ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => isNewObscured = !isNewObscured)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 12),
            TextField(controller: confirmPasswordController, obscureText: isConfirmObscured,
                decoration: InputDecoration(labelText: 'Confirm New Password', prefixIcon: const Icon(Icons.lock_outline, color: _primaryColor),
                    suffixIcon: IconButton(icon: Icon(isConfirmObscured ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => isConfirmObscured = !isConfirmObscured)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 16),
            _buildPasswordRequirements(newPasswordController.text),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600))),
          ElevatedButton(
              onPressed: isLoading ? null : () async {
                if (newPasswordController.text != confirmPasswordController.text) { _showError('Passwords do not match'); return; }
                setState(() => isLoading = true);
                try {
                  await _firebaseService.reauthenticate(currentPasswordController.text);
                  await _firebaseService.changePassword(newPasswordController.text);
                  Navigator.pop(context);
                  _showSuccess('Password updated successfully!');
                } catch (e) { setState(() => isLoading = false); _showError(e.toString()); }
              },
              style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Update')),
        ],
      ),
    ));
  }

  Widget _buildPasswordRequirements(String password) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Password Requirements:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
        const SizedBox(height: 8),
        _buildRequirement('At least 8 characters', password.length >= 8),
        _buildRequirement('Contains uppercase letter', password.contains(RegExp(r'[A-Z]'))),
        _buildRequirement('Contains lowercase letter', password.contains(RegExp(r'[a-z]'))),
        _buildRequirement('Contains number', password.contains(RegExp(r'[0-9]'))),
        _buildRequirement('Contains special character', password.contains(RegExp(r'[!@#$%^&*(),.?\":{}|<>]'))),
      ]),
    );
  }

  Widget _buildRequirement(String text, bool met) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Icon(met ? Icons.check_circle : Icons.circle_outlined, size: 14, color: met ? Colors.green : Colors.grey.shade400),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(fontSize: 12, color: met ? Colors.green.shade700 : Colors.grey.shade500)),
      ]),
    );
  }

  void _show2FASetupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.security, color: _primaryColor),
            SizedBox(width: 12),
            Text('Two-Factor Authentication'),
          ],
        ),
        content: const Text(
          '2FA setup will be available in the next update. This will require integration with an authenticator app like Google Authenticator.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Reset the switch back to false
              setState(() => _is2FAEnabled = false);
              Navigator.pop(context);
            },
            child: const Text('Got it', style: TextStyle(color: _primaryColor)),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 12),
            Text('Logout'),
          ],
        ),
        content: const Text('Are You Sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);

              try {
                await _firebaseService.signOut();

                if (mounted) {
                  context.go(AppRoutes.login);
                }
              } catch (e) {
                setState(() => _isLoading = false);
                _showError('failed to sign out: $e');
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
    showDialog(context: context, builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [Icon(Icons.delete_forever, color: Colors.red), SizedBox(width: 12), Text('Delete Account')]),
      content: const Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('This action is permanent and cannot be undone.', style: TextStyle(fontWeight: FontWeight.w600)),
        SizedBox(height: 12),
        Text('All your data including:'),
        SizedBox(height: 8),
        Text('• Profile information'),
        Text('• Transaction history'),
        Text('• Friends and messages'),
        SizedBox(height: 12),
        Text('will be permanently deleted.'),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600))),
        ElevatedButton(
            onPressed: () { Navigator.pop(context); _showError('Account deletion requires contacting support.'); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Delete Account')),
      ],
    ));
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [const Icon(Icons.check_circle, color: Colors.white), const SizedBox(width: 12), Expanded(child: Text(message))]),
        backgroundColor: _primaryColor, behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), margin: const EdgeInsets.all(16)));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [const Icon(Icons.error_outline, color: Colors.white), const SizedBox(width: 12), Expanded(child: Text(message))]),
        backgroundColor: Colors.red.shade400, behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), margin: const EdgeInsets.all(16)));
  }
}