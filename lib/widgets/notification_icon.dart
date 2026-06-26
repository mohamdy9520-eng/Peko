// lib/widgets/notification_icon.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';

class NotificationIcon extends StatelessWidget {
  const NotificationIcon({super.key});

  Stream<int> getUnreadCount() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(0);

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: getUnreadCount(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // الـ Icon Button
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.notifications_none,
                  color: Colors.white,
                ),
                onPressed: () => context.push('/notifications'),
              ),
            ),

            // Badge — لو فيه unread
            if (unreadCount > 0)
              Positioned(
                top: -4.h,
                right: -4.w,
                child: Container(
                  padding: EdgeInsets.all(4.w),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  constraints: BoxConstraints(
                    minWidth: 20.w,
                    minHeight: 20.w,
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 99 ? '99+' : unreadCount.toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: unreadCount > 9 ? 9.sp : 11.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}