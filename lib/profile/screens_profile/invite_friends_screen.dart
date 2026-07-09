import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ai_expense_tracker/core/di/services/ai_access_service.dart';

import '../fireBase_service/fireBase_service.dart';

class InviteFriendsScreen extends StatefulWidget {
  const InviteFriendsScreen({super.key});

  @override
  State<InviteFriendsScreen> createState() => _InviteFriendsScreenState();
}

class _InviteFriendsScreenState extends State<InviteFriendsScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const Color _primaryColor = Color(0xFF2E8B7B);
  static const int _maxBonusInvites = 5;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Invite Friends'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search friends...',
                prefixIcon: const Icon(Icons.search, color: _primaryColor),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: () => _showInviteFriendDialog(),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Invite a Friend'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firebaseService.getFriends(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return _buildLoadingState();
                }
                if (snapshot.hasError) {
                  return _buildErrorState(snapshot.error.toString());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }
                final friends = snapshot.data!.docs.where((doc) {
                  if (_searchQuery.isEmpty) return true;
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  final phone = (data['phone'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) ||
                      email.contains(_searchQuery) ||
                      phone.contains(_searchQuery);
                }).toList();
                if (friends.isEmpty) {
                  return _buildNoSearchResults();
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: friends.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final friend = friends[index];
                    final data = friend.data() as Map<String, dynamic>;
                    return _FriendCard(
                      name: data['name'] ?? 'Unknown',
                      email: data['email'] ?? '',
                      phone: data['phone'] ?? '',
                      image: data['image'],
                      addedAt: data['addedAt'] != null
                          ? (data['addedAt'] as Timestamp).toDate()
                          : null,
                      onDelete: () => _confirmDeleteFriend(friend.id, data['name'] ?? 'this friend'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // INVITE DIALOG
  // ─────────────────────────────────────────────
  void _showInviteFriendDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.person_add_alt_1, color: _primaryColor),
              SizedBox(width: 12),
              Text('Invite a Friend'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: "Friend's Name *",
                    prefixIcon: const Icon(Icons.person, color: _primaryColor),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email, color: _primaryColor),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: InputDecoration(
                    labelText: 'WhatsApp Number',
                    hintText: '+20xxxxxxxxxx',
                    prefixIcon: const Icon(Icons.chat, color: _primaryColor),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 6),
                Text(
                  'Enter at least an email or a WhatsApp number.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.card_giftcard, color: _primaryColor, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Get +1 free AI Plan trial for every friend you invite '
                              '(up to $_maxBonusInvites)!',
                          style: TextStyle(
                            fontSize: 12,
                            color: _primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                final name = nameController.text.trim();
                final email = emailController.text.trim();
                final phone = phoneController.text.trim();

                if (name.isEmpty) {
                  _showError("Friend's name is required");
                  return;
                }
                if (email.isEmpty && phone.isEmpty) {
                  _showError('Add an email or a WhatsApp number');
                  return;
                }

                setDialogState(() => isLoading = true);
                try {
                  await _inviteFriend(name: name, email: email, phone: phone);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  setDialogState(() => isLoading = false);
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
                  : const Text('Send Invite'),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // GENERATE INVITE CODE
  // ─────────────────────────────────────────────
  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
  }

  // ─────────────────────────────────────────────
  // BUILD INVITE MESSAGE (with invite code)
  // ─────────────────────────────────────────────
  String _buildInviteMessage(String friendName, String inviteCode) {
    // TODO: استبدل الرابط ده لما تنشر التطبيق على Store
    // Android: https://play.google.com/store/apps/details?id=com.peko.app
    // iOS: https://apps.apple.com/app/idYOUR_APP_ID
    const appLink = '';

    return "Hi $friendName! \u{1F44B}\n\n"
        "I've been using Peko \u{2013} AI Expense Tracker to plan my budget and reach my "
        "savings goals with the help of AI. It's honestly really helpful!\n\n"
        "Join me and let's manage our money smarter together \u{1F4B0}\u{1F4CA}\n\n"
        "Use my invite code: *$inviteCode* when you sign up!\n"
        "${appLink.isNotEmpty ? '\nDownload: $appLink\n' : ''}"
        "See you there!";
  }

  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  // ─────────────────────────────────────────────
  // SEND INVITE (EMAIL + WHATSAPP) - NO REWARD HERE
  // ─────────────────────────────────────────────
  Future<void> _inviteFriend({
    required String name,
    required String email,
    required String phone,
  }) async {
    final inviteCode = _generateInviteCode();
    final message = _buildInviteMessage(name, inviteCode);
    bool sentAny = false;
    final List<String> errors = [];

    // ─── EMAIL ───
    if (email.isNotEmpty) {
      final emailUri = Uri(
        scheme: 'mailto',
        path: email,
        query: _encodeQueryParameters({
          'subject': 'Join me on Peko – AI Expense Tracker!',
          'body': message,
        }),
      );
      try {
        if (await canLaunchUrl(emailUri)) {
          await launchUrl(emailUri);
          sentAny = true;
        } else {
          errors.add('Email app not found');
        }
      } catch (e) {
        errors.add('Email error: $e');
      }
    }

    // ─── WHATSAPP ───
    if (phone.isNotEmpty) {
      final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
      final formattedPhone = cleanPhone.startsWith('+') ? cleanPhone : '+$cleanPhone';
      final phoneWithoutPlus = formattedPhone.replaceFirst('+', '');

      try {
        final whatsappUri = Uri.parse(
          'https://wa.me/$phoneWithoutPlus?text=${Uri.encodeComponent(message)}',
        );
        final launched = await launchUrl(
          whatsappUri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) sentAny = true;
      } catch (e) {
        errors.add('WhatsApp error: $e');
      }
    }

    // ─── لو مفيش app متاح → Copy to Clipboard ───
    if (!sentAny) {
      await Clipboard.setData(ClipboardData(text: message));
      if (mounted) {
        _showSuccess(
          'Message copied to clipboard! 📋\n'
              'Please open WhatsApp or Email and paste it manually.',
        );
      }
    } else {
      if (mounted) {
        _showSuccess('Invite sent! 🎉');
      }
    }

    // ─── Save to Firestore (من غير مكافئة) ───
    final currentUserId = _firebaseService.uid;
    await _firebaseService.addFriend({
      'name': name,
      'email': email,
      'phone': phone,
      'invited': true,
      'inviteCode': inviteCode,
      'invitedBy': currentUserId,
      'rewarded': false,
      'friendRegistered': false,
      'invitedAt': FieldValue.serverTimestamp(),
    });
  }

  void _confirmDeleteFriend(String friendId, String friendName) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red),
            SizedBox(width: 12),
            Text('Remove Friend'),
          ],
        ),
        content: Text('Are you sure you want to remove $friendName from your friends list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _firebaseService.removeFriend(friendId);
                _showSuccess('Friend removed');
              } catch (e) {
                _showError('Failed to remove: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 5,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text('Failed to load friends', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 24),
            Text(
              'No Friends Yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Text(
              'Invite friends via email or WhatsApp and earn free AI Plan trials.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSearchResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
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
        content: Text(message),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

class _FriendCard extends StatelessWidget {
  final String name;
  final String email;
  final String phone;
  final String? image;
  final DateTime? addedAt;
  final VoidCallback onDelete;

  const _FriendCard({
    required this.name,
    required this.email,
    this.phone = '',
    this.image,
    this.addedAt,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final subtitleText = email.isNotEmpty
        ? email
        : (phone.isNotEmpty ? phone : '');

    return Dismissible(
      key: Key(name + email + phone),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.delete_outline, color: Colors.white),
            SizedBox(width: 8),
            Text('Remove', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFF2E8B7B).withOpacity(0.1),
            backgroundImage: image != null ? NetworkImage(image!) : null,
            child: image == null
                ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Color(0xFF2E8B7B),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            )
                : null,
          ),
          title: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              if (subtitleText.isNotEmpty)
                Text(subtitleText, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
              if (addedAt != null)
                Text(
                  'Added ${_formatDate(addedAt!)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                ),
            ],
          ),
          trailing: IconButton(
            icon: Icon(Icons.more_vert, color: Colors.grey.shade400),
            onPressed: onDelete,
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays < 1) return 'today';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}