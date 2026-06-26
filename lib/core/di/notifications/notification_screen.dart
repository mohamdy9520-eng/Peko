import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_colors.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<Map<String, dynamic>> _notifications = [];  // ← شيل final
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _markAllAsRead();
  }

  Future<void> _loadNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      setState(() {
        _notifications = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          data['read'] = data['read'] ?? false;
          return data;
        }).toList();
        _loading = false;
      });
    });
  }

  Future<void> _markAllAsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final unread = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (var doc in unread.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  Future<void> _deleteNotification(String docId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .doc(docId)
        .delete();
  }

  Future<void> _clearAll() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'budget': return Icons.account_balance_wallet;
      case 'goal': return Icons.flag;
      case 'transaction': return Icons.receipt;
      case 'transfer': return Icons.swap_horiz;
      case 'summary': return Icons.pie_chart;
      case 'reminder': return Icons.alarm;
      default: return Icons.notifications;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'budget': return Colors.orange;
      case 'goal': return Colors.green;
      case 'transaction': return Colors.blue;
      case 'transfer': return Colors.purple;
      case 'summary': return Colors.teal;
      case 'reminder': return Colors.amber;
      default: return Colors.grey;
    }
  }

  void _onNotificationTap(Map<String, dynamic> notification) {
    final screen = notification['screen'] as String?;
    if (screen == null) return;

    switch (screen) {
      case '/budget':
        final tab = notification['tab'] as String?;
        context.push('/budget', extra: {'initialTab': tab});
        break;
      case '/stats':
        context.push('/stats');
        break;
      case '/transactions':
        context.push('/transactions');
        break;
      default:
        context.push(screen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !(n['read'] ?? true)).length;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: Text(
          'Notifications',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          if (_notifications.isNotEmpty)
            TextButton(
              onPressed: _clearAll,
              child: Text(
                'Clear All',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14.sp,
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? _buildEmptyState()
          : _buildNotificationList(unreadCount),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 80.sp,
            color: Colors.grey[300],
          ),
          SizedBox(height: 16.h),
          Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: 18.sp,
              color: Colors.grey[500],
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'We\'ll notify you about budgets & goals',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationList(int unreadCount) {
    return Column(
      children: [
        if (unreadCount > 0)
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 16.w),
            color: AppColors.primary.withOpacity(0.1),
            child: Text(
              '$unreadCount unread',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(16.w),
            itemCount: _notifications.length,
            itemBuilder: (context, index) {
              final notification = _notifications[index];
              final isRead = notification['read'] ?? true;
              final type = notification['type'] ?? 'general';
              final createdAt = (notification['createdAt'] as Timestamp?)?.toDate();

              return Dismissible(
                key: Key(notification['id']),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: EdgeInsets.only(right: 20.w),
                  color: Colors.red,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) => _deleteNotification(notification['id']),
                child: Card(
                  margin: EdgeInsets.only(bottom: 12.h),
                  elevation: isRead ? 0 : 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                    side: isRead
                        ? BorderSide.none
                        : BorderSide(color: AppColors.primary.withOpacity(0.3), width: 1.5),
                  ),
                  child: InkWell(
                    onTap: () => _onNotificationTap(notification),
                    borderRadius: BorderRadius.circular(16.r),
                    child: Padding(
                      padding: EdgeInsets.all(16.w),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icon
                          Container(
                            padding: EdgeInsets.all(12.w),
                            decoration: BoxDecoration(
                              color: _getColorForType(type).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Icon(
                              _getIconForType(type),
                              color: _getColorForType(type),
                              size: 24.sp,
                            ),
                          ),
                          SizedBox(width: 16.w),

                          // Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        notification['title'] ?? 'Notification',
                                        style: TextStyle(
                                          fontSize: 15.sp,
                                          fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    if (!isRead)
                                      Container(
                                        width: 8.w,
                                        height: 8.w,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  notification['body'] ?? '',
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 8.h),
                                Text(
                                  createdAt != null
                                      ? _formatTimeAgo(createdAt)
                                      : '',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM dd').format(date);
  }
}