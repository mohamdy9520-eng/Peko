import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../fireBase_service/fireBase_service.dart';

class MessageCenterScreen extends StatefulWidget {
  const MessageCenterScreen({super.key});
  @override State<MessageCenterScreen> createState() => _MessageCenterScreenState();
}

class _MessageCenterScreenState extends State<MessageCenterScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  static const Color _primaryColor = Color(0xFF2E8B7B);

  bool _hasMessages = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text('Message Center', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w600)),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.done_all, size: 24.r),
            tooltip: 'Mark all as read',
            onPressed: _hasMessages ? _markAllAsRead : null,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firebaseService.getMessages(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return _buildLoadingState();
          }
          if (snapshot.hasError) return _buildErrorState(snapshot.error.toString());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _hasMessages != false) {
                setState(() => _hasMessages = false);
              }
            });
            return _buildEmptyState();
          }

          final messages = snapshot.data!.docs;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _hasMessages != true) {
              setState(() => _hasMessages = true);
            }
          });

          return RefreshIndicator(
            onRefresh: () async => await Future.delayed(const Duration(milliseconds: 500)),
            color: _primaryColor,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 600.w),
                child: ListView.separated(
                  padding: EdgeInsets.all(16.r),
                  itemCount: messages.length,
                  separatorBuilder: (_, __) => SizedBox(height: 8.h),
                  itemBuilder: (context, index) {
                    final doc = messages[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final isRead = data['isRead'] ?? false;
                    final timestamp = data['createdAt'] as Timestamp?;

                    return Dismissible(
                      key: Key(doc.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        decoration: BoxDecoration(
                          color: Colors.red.shade400,
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        alignment: Alignment.centerRight,
                        padding: EdgeInsets.only(right: 24.w),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(Icons.delete_outline, color: Colors.white, size: 24.r),
                            SizedBox(width: 8.w),
                            Text(
                              'Delete',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      onDismissed: (_) => _deleteMessage(doc.id),
                      child: _MessageCard(
                        title: data['title'] ?? 'No Title',
                        body: data['body'] ?? '',
                        isRead: isRead,
                        timestamp: timestamp,
                        onTap: () => _markAsRead(doc.id, isRead),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _markAsRead(String messageId, bool currentlyRead) async {
    if (currentlyRead) return;
    HapticFeedback.lightImpact();
    try {
      await _firebaseService.markMessageAsRead(messageId);
    } catch (e) {
      _showError('Failed to mark as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    HapticFeedback.mediumImpact();
    try {
      final messagesSnapshot = await _firebaseService.getMessages().first;

      final unreadDocs = messagesSnapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return (data['isRead'] ?? false) == false;
      }).toList();

      if (unreadDocs.isEmpty) {
        _showSuccess('All messages are already read');
        return;
      }

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in unreadDocs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
      _showSuccess('All messages marked as read');
    } catch (e) {
      _showError('Failed to mark all as read: $e');
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    HapticFeedback.mediumImpact();
    try {
      await _firebaseService.deleteMessage(messageId);
      _showSuccess('Message deleted');
    } catch (e) {
      _showError('Failed to delete: $e');
    }
  }

  Widget _buildLoadingState() {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 600.w),
        child: Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: ListView.builder(
            padding: EdgeInsets.all(16.r),
            itemCount: 5,
            itemBuilder: (_, __) => Container(
              margin: EdgeInsets.only(bottom: 8.h),
              height: 80.h,
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

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.r),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64.r, color: Colors.red.shade300),
            SizedBox(height: 16.h),
            Text(
              'Failed to load messages',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.r),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mark_email_read_outlined, size: 80.r, color: Colors.grey.shade300),
            SizedBox(height: 24.h),
            Text(
              'No Messages Yet',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              "You'll see notifications and updates here when they arrive.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade500),
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
        duration: const Duration(seconds: 2),
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

class _MessageCard extends StatelessWidget {
  final String title, body;
  final bool isRead;
  final Timestamp? timestamp;
  final VoidCallback onTap;

  const _MessageCard({
    required this.title,
    required this.body,
    required this.isRead,
    required this.timestamp,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isRead ? Colors.white : const Color(0xFFE8F5F3),
      borderRadius: BorderRadius.circular(16.r),
      elevation: isRead ? 0 : 2,
      shadowColor: isRead ? Colors.transparent : const Color(0xFF2E8B7B).withOpacity(0.1),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Padding(
          padding: EdgeInsets.all(16.r),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48.r,
                height: 48.r,
                decoration: BoxDecoration(
                  color: isRead ? Colors.grey.shade100 : const Color(0xFF2E8B7B).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isRead ? Icons.mark_email_read : Icons.mark_email_unread,
                  color: isRead ? Colors.grey.shade500 : const Color(0xFF2E8B7B),
                  size: 24.r,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                              fontSize: 16.sp,
                              color: const Color(0xFF1A1A2E),
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8.r,
                            height: 8.r,
                            decoration: const BoxDecoration(
                              color: Color(0xFF2E8B7B),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      _formatTime(timestamp),
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12.sp),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d, yyyy').format(date);
  }
}