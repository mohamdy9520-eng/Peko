import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../fireBase_service/fireBase_service.dart';

class DataPrivacyScreen extends StatefulWidget {
  const DataPrivacyScreen({super.key});

  @override
  State<DataPrivacyScreen> createState() => _DataPrivacyScreenState();
}

class _DataPrivacyScreenState extends State<DataPrivacyScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = false;
  static const Color _primaryColor = Color(0xFF2E8B7B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text('Data & Privacy', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w600)),
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
                  _buildPrivacyCard(
                    icon: Icons.download_outlined,
                    title: 'Export Your Data',
                    subtitle: 'Download a copy of all your data',
                    onTap: _exportData,
                  ),
                  SizedBox(height: 12.h),
                  _buildPrivacyCard(
                    icon: Icons.delete_outline,
                    title: 'Clear App Data',
                    subtitle: 'Remove cached data from this device',
                    onTap: _clearCache,
                  ),
                  SizedBox(height: 12.h),
                  _buildPrivacyCard(
                    icon: Icons.policy_outlined,
                    title: 'Privacy Policy',
                    subtitle: 'Read how we handle your data',
                    onTap: _showPrivacyPolicy,
                  ),
                  SizedBox(height: 32.h),
                  _buildSectionHeader('Danger Zone', color: Colors.red),
                  SizedBox(height: 12.h),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: _buildPrivacyCard(
                      icon: Icons.delete_forever,
                      title: 'Delete All Data',
                      subtitle: 'Permanently delete all your app data',
                      iconColor: Colors.red,
                      onTap: _showDeleteDataDialog,
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

  Widget _buildPrivacyCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Padding(
          padding: EdgeInsets.all(16.r),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: (iconColor ?? _primaryColor).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(icon, color: iconColor ?? _primaryColor, size: 22.r),
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
                        color: const Color(0xFF1A1A2E),
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20.r),
            ],
          ),
        ),
      ),
    );
  }


  Future<void> _exportData() async {
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      final userStream = _firebaseService.getUser();
      final user = await userStream.first;

      final exportData = {
        'exportDate': DateTime.now().toIso8601String(),
        'user': {
          'uid': user.uid,
          'name': user.name,
          'email': user.email,
          'username': user.username,
          'phone': user.phone,
          'bio': user.bio,
          'isEmailVerified': user.isEmailVerified,
          'isPhoneVerified': user.isPhoneVerified,
        },
      };

      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/user_data_export.json';
      final file = File(filePath);
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(exportData));

      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Your data export from Expense Tracker',
        subject: 'Data Export',
      );

      _showSuccess('Data exported successfully!');
    } catch (e) {
      _showError('Failed to export data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }


  Future<void> _clearCache() async {
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      final cacheDir = await getTemporaryDirectory();
      if (cacheDir.existsSync()) {
        await for (final entity in cacheDir.list()) {
          if (entity is File) {
            await entity.delete();
          } else if (entity is Directory) {
            await entity.delete(recursive: true);
          }
        }
      }

      final imageCacheDir = Directory('${cacheDir.path}/image_cache');
      if (imageCacheDir.existsSync()) {
        await imageCacheDir.delete(recursive: true);
      }

      _showSuccess('Cache cleared successfully!');
    } catch (e) {
      _showError('Failed to clear cache: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }


  void _showPrivacyPolicy() {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Row(
          children: [
            Icon(Icons.policy, color: _primaryColor, size: 24.r),
            SizedBox(width: 12.w),
            Text('Privacy Policy', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '1. Data Collection',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp),
              ),
              SizedBox(height: 4.h),
              Text(
                'We collect your name, email, phone number, and financial data (transactions, budgets, goals) to provide the expense tracking service.',
                style: TextStyle(fontSize: 13.sp, color: Colors.grey),
              ),
              SizedBox(height: 12.h),
              Text(
                '2. Data Usage',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp),
              ),
              SizedBox(height: 4.h),
              Text(
                'Your data is used solely for the app functionality. We do not sell or share your data with third parties.',
                style: TextStyle(fontSize: 13.sp, color: Colors.grey),
              ),
              SizedBox(height: 12.h),
              Text(
                '3. Data Security',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp),
              ),
              SizedBox(height: 4.h),
              Text(
                'All data is encrypted and stored securely using Firebase. We use industry-standard security practices.',
                style: TextStyle(fontSize: 13.sp, color: Colors.grey),
              ),
              SizedBox(height: 12.h),
              Text(
                '4. Your Rights',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp),
              ),
              SizedBox(height: 4.h),
              Text(
                'You have the right to export, modify, or delete your data at any time through this screen.',
                style: TextStyle(fontSize: 13.sp, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: _primaryColor, fontSize: 14.sp)),
          ),
        ],
      ),
    );
  }


  void _showDeleteDataDialog() {
    HapticFeedback.mediumImpact();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 24.r),
            SizedBox(width: 12.w),
            Text('Delete All Data', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will permanently delete ALL your data including:\n'
                  '• Your profile and account\n'
                  '• All transactions and budgets\n'
                  '• All savings goals\n'
                  '• All contacts and messages\n\n'
                  'This action CANNOT be undone.',
              style: TextStyle(fontSize: 14.sp),
            ),
            SizedBox(height: 16.h),
            TextField(
              controller: passwordController,
              obscureText: true,
              style: TextStyle(fontSize: 14.sp),
              decoration: InputDecoration(
                labelText: 'Enter your password to confirm',
                labelStyle: TextStyle(fontSize: 14.sp),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                prefixIcon: Icon(Icons.lock, size: 20.r),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600, fontSize: 14.sp)),
          ),
          ElevatedButton(
            onPressed: () async {
              final password = passwordController.text.trim();
              if (password.isEmpty) {
                _showError('Please enter your password');
                return;
              }
              Navigator.pop(context);
              await _performDeleteAccount(password);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
            child: Text('Delete Forever', style: TextStyle(fontSize: 14.sp)),
          ),
        ],
      ),
    );
  }

  Future<void> _performDeleteAccount(String password) async {
    setState(() => _isLoading = true);

    try {
      await _firebaseService.reauthenticate(password);

      await _firebaseService.deleteAccount();

      if (mounted) {
        _showSuccess('Account deleted successfully');
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } on NetworkException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Failed to delete account: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20.r),
            SizedBox(width: 12.w),
            Expanded(child: Text(message, style: TextStyle(fontSize: 14.sp))),
          ],
        ),
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
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20.r),
            SizedBox(width: 12.w),
            Expanded(child: Text(message, style: TextStyle(fontSize: 14.sp))),
          ],
        ),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
        margin: EdgeInsets.all(16.r),
      ),
    );
  }
}