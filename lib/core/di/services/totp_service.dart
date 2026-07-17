import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:otp/otp.dart';

class TOTPService {
  static const int _interval = 30; // كل 30 ثانية
  static const int _digits = 6;   // 6 أرقام
  static const String _algorithm = 'SHA1';
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get the app secret from Firestore (100% FREE - no extra cost)
  static Future<String> _getAppSecret() async {
    try {
      final doc = await _firestore.collection('app_config').doc('secrets').get();
      final secret = doc.data()?['totp_secret'] as String?;
      if (secret != null && secret.isNotEmpty) {
        return secret;
      }
    } catch (e) {
      // If Firestore fails, throw error (no hardcoded fallback for security)
      throw Exception('Failed to fetch TOTP secret: $e');
    }
    throw Exception('TOTP secret not configured in Firestore. Please contact support.');
  }

  static Future<String> generateUserSecret(String userId) async {
    final appSecret = await _getAppSecret();
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