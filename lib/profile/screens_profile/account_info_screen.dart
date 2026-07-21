import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';
import '../fireBase_service/fireBase_service.dart';
import '../user_model/user_model.dart';

class AccountInfoScreen extends StatefulWidget {
  const AccountInfoScreen({super.key});

  @override
  State<AccountInfoScreen> createState() => _AccountInfoScreenState();
}

class _AccountInfoScreenState extends State<AccountInfoScreen> {
  final _firebaseService = FirebaseService();
  static const Color _primaryColor = Color(0xFF2E8B7B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text('Account Info', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w600)),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<UserModel>(
        stream: _firebaseService.getUser(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return _buildLoadingState();
          }

          final user = snapshot.data!;
          final authUser = FirebaseAuth.instance.currentUser;
          final isEmailVerified = authUser?.emailVerified ?? false;

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 600.w),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20.r),
                child: Column(
                  children: [
                    _buildInfoCard(
                      'Account Status',
                      isEmailVerified ? 'Verified ✓' : 'Not Verified',
                      isEmailVerified ? Icons.verified : Icons.warning,
                      isEmailVerified ? Colors.green : Colors.orange,
                    ),
                    SizedBox(height: 12.h),
                    _buildInfoCard('Email', user.email, Icons.email, _primaryColor),
                    SizedBox(height: 12.h),
                    _buildInfoCard('User ID', user.uid, Icons.fingerprint, _primaryColor),
                    SizedBox(height: 12.h),
                    _buildInfoCard('Member Since', _formatDate(user.createdAt), Icons.calendar_today, _primaryColor),
                    SizedBox(height: 12.h),
                    _buildInfoCard('Last Updated', _formatDate(user.updatedAt), Icons.update, _primaryColor),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon, Color iconColor) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
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
                  label,
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade500),
                ),
                SizedBox(height: 4.h),
                Text(
                  value,
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A2E)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 600.w),
        child: Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: ListView.separated(
            padding: EdgeInsets.all(20.r),
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 5,
            separatorBuilder: (_, __) => SizedBox(height: 12.h),
            itemBuilder: (_, __) => Container(
              height: 72.h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    return '${date.day}/${date.month}/${date.year}';
  }
}