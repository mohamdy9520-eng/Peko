import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../providers/currency_provider.dart';
import '../fireBase_service/fireBase_service.dart';
import '../user_model/user_model.dart';

class AccountInfoScreen extends StatelessWidget {
  const AccountInfoScreen({super.key});
  static const Color _primaryColor = Color(0xFF2E8B7B);

  @override
  Widget build(BuildContext context) {
    final firebaseService = FirebaseService();
    final currencyProvider = Provider.of<CurrencyProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Account Info'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<UserModel>(
        stream: firebaseService.getUser(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return _buildLoadingState();
          }
          if (snapshot.hasError) return _buildErrorState(snapshot.error.toString());
          final user = snapshot.data;

          return RefreshIndicator(
            onRefresh: () async => await Future.delayed(const Duration(milliseconds: 500)),
            color: _primaryColor,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileSummary(user),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Personal Information'),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    label: 'Currency',
                    value: '${currencyProvider.flag} ${currencyProvider.name} (${currencyProvider.code})',
                    icon: Icons.currency_exchange,
                    iconColor: Colors.teal,
                    trailing: TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/change-currency'),
                      child: const Text('Change', style: TextStyle(color: _primaryColor)),
                    ),
                  ),
                  _buildInfoCard(
                      label: 'Full Name', value: user?.name ?? 'Not set',
                      icon: Icons.person_outline, iconColor: Colors.blue),
                  _buildInfoCard(
                      label: 'Email Address', value: user?.email ?? 'Not set',
                      icon: Icons.email_outlined, iconColor: Colors.orange,
                      verified: user?.isEmailVerified ?? false),
                  _buildInfoCard(
                      label: 'Username', value: user?.username.isNotEmpty == true ? '@${user!.username}' : 'Not set',
                      icon: Icons.alternate_email, iconColor: Colors.purple),
                  _buildInfoCard(
                      label: 'Phone Number', value: user?.phone.isNotEmpty == true ? user!.phone : 'Not set',
                      icon: Icons.phone_outlined, iconColor: Colors.green,
                      verified: user?.isPhoneVerified ?? false),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Preferences'),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    label: 'Currency',
                      value: '${currencyProvider.flag} ${currencyProvider.name} (${currencyProvider.code})',
                    icon: Icons.currency_exchange, iconColor: Colors.teal,
                    trailing: TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/change-currency'),
                      child: const Text('Change', style: TextStyle(color: _primaryColor)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Account Status'),
                  const SizedBox(height: 12),
                  _buildStatusCard(user),
                  const SizedBox(height: 32),
                  Center(
                    child: Text('Account ID: ${user?.uid ?? '...'}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontFamily: 'monospace')),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text('Member since ${user?.createdAt != null ? _formatDate(user!.createdAt!) : '...'}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileSummary(UserModel? user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF2E8B7B), Color(0xFF4A9B8E)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF2E8B7B).withOpacity(0.2),
              blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(children: [
        Hero(
          tag: 'profile-avatar',
          child: Container(
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 3)),
            child: CircleAvatar(
              radius: 40, backgroundColor: Colors.white.withOpacity(0.2),
              backgroundImage: user?.hasImage == true ? NetworkImage(user!.image) : null,
              child: user?.hasImage != true
                  ? Text(user?.initials ?? '?', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white))
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(user?.displayName ?? 'Loading...', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 4),
        Text(user?.email ?? '', style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8))),
      ]),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title.toUpperCase(),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 1.2));
  }

  Widget _buildInfoCard({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
    bool verified = false,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: trailing != null ? () {} : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Icon container with subtle background
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Label row with verified badge
                      Row(
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          if (verified) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.verified, size: 12, color: Colors.green.shade500),
                                  const SizedBox(width: 2),
                                  Text(
                                    'Verified',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Value
                      Text(
                        value.isNotEmpty ? value : 'Not set',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: value.isNotEmpty ? const Color(0xFF1A1A2E) : Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
                // Trailing or arrow
                if (trailing != null)
                  trailing
                else
                  Icon(Icons.chevron_right, color: Colors.grey.shade300, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildStatusCard(UserModel? user) {
    final isComplete = user != null && user.name.isNotEmpty && user.email.isNotEmpty &&
        user.phone.isNotEmpty && user.username.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: isComplete ? Colors.green.shade50 : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isComplete ? Colors.green.shade200 : Colors.orange.shade200)),
      child: Row(children: [
        Icon(isComplete ? Icons.check_circle : Icons.info_outline,
            color: isComplete ? Colors.green.shade500 : Colors.orange.shade500, size: 28),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isComplete ? 'Profile Complete' : 'Profile Incomplete',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                    color: isComplete ? Colors.green.shade700 : Colors.orange.shade700)),
            const SizedBox(height: 4),
            Text(isComplete ? 'Your profile is fully set up and ready to go!' : 'Complete your profile to unlock all features.',
                style: TextStyle(fontSize: 13, color: isComplete ? Colors.green.shade600 : Colors.orange.shade600)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildLoadingState() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300, highlightColor: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Container(height: 180, width: double.infinity, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))),
          const SizedBox(height: 24),
          for (int i = 0; i < 5; i++) ...[
            Container(height: 80, margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
          ],
        ]),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
        const SizedBox(height: 16),
        Text('Failed to load account info', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
        const SizedBox(height: 8),
        Text(error, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
      ]),
    ));
  }

  String _formatDate(DateTime date) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[date.month-1]} ${date.day}, ${date.year}';
  }
}