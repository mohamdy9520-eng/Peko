import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Message Center'),
        backgroundColor: _primaryColor, foregroundColor: Colors.white, elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark all as read',
            onPressed: _markAllAsRead,
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
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyState();

          final messages = snapshot.data!.docs;

          return RefreshIndicator(
            onRefresh: () async => await Future.delayed(const Duration(milliseconds: 500)),
            color: _primaryColor,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final doc = messages[index];
                final data = doc.data() as Map<String, dynamic>;
                final isRead = data['isRead'] ?? false;
                final timestamp = data['createdAt'] as Timestamp?;

                return Dismissible(
                  key: Key(doc.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(16)),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Icon(Icons.delete_outline, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ]),
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
          );
        },
      ),
    );
  }

  Future<void> _markAsRead(String messageId, bool currentlyRead) async {
    if (currentlyRead) return;
    HapticFeedback.lightImpact();
    try { await _firebaseService.markMessageAsRead(messageId); }
    catch (e) { _showError('Failed to mark as read: $e'); }
  }

  Future<void> _markAllAsRead() async {
    HapticFeedback.mediumImpact();
    _showSuccess('All messages marked as read');
  }

  Future<void> _deleteMessage(String messageId) async {
    HapticFeedback.mediumImpact();
    try {
      await _firebaseService.deleteMessage(messageId);
      _showSuccess('Message deleted');
    } catch (e) { _showError('Failed to delete: $e'); }
  }

  Widget _buildLoadingState() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300, highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 8), height: 80,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
        const SizedBox(height: 16),
        Text('Failed to load messages', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
        const SizedBox(height: 8),
        Text(error, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
      ]),
    ));
  }

  Widget _buildEmptyState() {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.mark_email_read_outlined, size: 80, color: Colors.grey.shade300),
        const SizedBox(height: 24),
        Text('No Messages Yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
        const SizedBox(height: 8),
        Text("You'll see notifications and updates here when they arrive.",
            textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
      ]),
    ));
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message), backgroundColor: _primaryColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16), duration: const Duration(seconds: 2),
    ));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message), backgroundColor: Colors.red.shade400,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }
}

class _MessageCard extends StatelessWidget {
  final String title, body;
  final bool isRead;
  final Timestamp? timestamp;
  final VoidCallback onTap;
  const _MessageCard({required this.title, required this.body, required this.isRead,
    required this.timestamp, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isRead ? Colors.white : const Color(0xFFE8F5F3),
      borderRadius: BorderRadius.circular(16),
      elevation: isRead ? 0 : 2,
      shadowColor: isRead ? Colors.transparent : const Color(0xFF2E8B7B).withOpacity(0.1),
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: isRead ? Colors.grey.shade100 : const Color(0xFF2E8B7B).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(isRead ? Icons.mark_email_read : Icons.mark_email_unread,
                  color: isRead ? Colors.grey.shade500 : const Color(0xFF2E8B7B), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(title,
                    style: TextStyle(fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                        fontSize: 16, color: const Color(0xFF1A1A2E)))),
                if (!isRead) Container(width: 8, height: 8,
                    decoration: const BoxDecoration(color: Color(0xFF2E8B7B), shape: BoxShape.circle)),
              ]),
              const SizedBox(height: 4),
              Text(body, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.4)),
              const SizedBox(height: 8),
              Text(_formatTime(timestamp), style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
            ])),
          ]),
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