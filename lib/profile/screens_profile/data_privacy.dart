// data_privacy_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../fireBase_service/fireBase_service.dart';
import '../user_model/user_model.dart';

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
        title: const Text('Data & Privacy'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildPrivacyCard(
                icon: Icons.download_outlined,
                title: 'Export Your Data',
                subtitle: 'Download a copy of all your data',
                onTap: _exportData,
              ),
              const SizedBox(height: 12),
              _buildPrivacyCard(
                icon: Icons.delete_outline,
                title: 'Clear App Data',
                subtitle: 'Remove cached data from this device',
                onTap: _clearCache,
              ),
              const SizedBox(height: 12),
              _buildPrivacyCard(
                icon: Icons.policy_outlined,
                title: 'Privacy Policy',
                subtitle: 'Read how we handle your data',
                onTap: _showPrivacyPolicy,
              ),
              const SizedBox(height: 32),
              _buildSectionHeader('Danger Zone', color: Colors.red),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(16),
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

  Widget _buildPrivacyCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (iconColor ?? _primaryColor).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor ?? _primaryColor, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // EXPORT DATA - يصدر بيانات المستخدم كملف JSON ويشاركه
  // ═══════════════════════════════════════════════════════════
  Future<void> _exportData() async {
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      // جلب بيانات المستخدم من Firebase
      final userStream = _firebaseService.getUser();
      final user = await userStream.first;

      // تجميع البيانات
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

      // إنشاء ملف JSON مؤقت
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/user_data_export.json';
      final file = File(filePath);
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(exportData));

      // مشاركة الملف
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

  // ═══════════════════════════════════════════════════════════
  // CLEAR CACHE - يمسح الكاش المحلي
  // ═══════════════════════════════════════════════════════════
  Future<void> _clearCache() async {
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      // مسح الكاش من التطبيق
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

      // مسح الكاش من الصور
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

  // ═══════════════════════════════════════════════════════════
  // PRIVACY POLICY - يعرض سياسة الخصوصية
  // ═══════════════════════════════════════════════════════════
  void _showPrivacyPolicy() {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.policy, color: _primaryColor),
            SizedBox(width: 12),
            Text('Privacy Policy'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '1. Data Collection',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              SizedBox(height: 4),
              Text(
                'We collect your name, email, phone number, and financial data (transactions, budgets, goals) to provide the expense tracking service.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              SizedBox(height: 12),
              Text(
                '2. Data Usage',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              SizedBox(height: 4),
              Text(
                'Your data is used solely for the app functionality. We do not sell or share your data with third parties.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              SizedBox(height: 12),
              Text(
                '3. Data Security',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              SizedBox(height: 4),
              Text(
                'All data is encrypted and stored securely using Firebase. We use industry-standard security practices.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              SizedBox(height: 12),
              Text(
                '4. Your Rights',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              SizedBox(height: 4),
              Text(
                'You have the right to export, modify, or delete your data at any time through this screen.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: _primaryColor)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // DELETE ALL DATA - يحذف كل البيانات نهائياً
  // ═══════════════════════════════════════════════════════════
  void _showDeleteDataDialog() {
    HapticFeedback.mediumImpact();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 12),
            Text('Delete All Data'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will permanently delete ALL your data including:\n'
                  '• Your profile and account\n'
                  '• All transactions and budgets\n'
                  '• All savings goals\n'
                  '• All contacts and messages\n\n'
                  'This action CANNOT be undone.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Enter your password to confirm',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.lock),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );
  }

  Future<void> _performDeleteAccount(String password) async {
    setState(() => _isLoading = true);

    try {
      // 1. إعادة المصادقة أولاً
      await _firebaseService.reauthenticate(password);

      // 2. حذف الحساب والبيانات
      await _firebaseService.deleteAccount();

      // 3. التوجيه لشاشة تسجيل الدخول
      if (mounted) {
        _showSuccess('Account deleted successfully');
        // هنا تقدر تستخدم Navigator.pushReplacementNamed(context, '/login')
        // أو أي طريقة تنقل عندك في التطبيق
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