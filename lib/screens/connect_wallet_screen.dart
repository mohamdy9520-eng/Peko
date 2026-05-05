import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_button.dart';

class ConnectWalletScreen extends StatelessWidget {
  const ConnectWalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        appBar: AppBar(
          title: const Text('Connect Wallet'),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 20),
            onPressed: () {},
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_none),
              onPressed: () {},
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              color: AppColors.primary,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TabBar(
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: Colors.white,
                    tabs: const [
                      Tab(text: 'Cards'),
                      Tab(text: 'Accounts'),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildCardsTab(),
                  _buildAccountsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dummy Card Graphic
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Debit Card', style: TextStyle(color: Colors.white, fontSize: 16)),
                    Row(
                      children: [
                        Container(width: 16, height: 16, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                        Transform.translate(
                          offset: const Offset(-8, 0),
                          child: Container(width: 16, height: 16, decoration: BoxDecoration(color: Colors.orange.withOpacity(0.8), shape: BoxShape.circle)),
                        ),
                      ],
                    ),
                  ],
                ),
                const Text('**** **** **** 3478', style: TextStyle(color: Colors.white, fontSize: 22, letterSpacing: 2)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('11/24', style: TextStyle(color: Colors.white, fontSize: 16)),
                    const Text('11/25', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text('Add your debit card', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('This card must be linked to a bank account.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 24),
          _buildTextField('NAME ON CARD', 'ENJELIN MORGEANA'),
          const SizedBox(height: 16),
          _buildTextField('DEBIT CARD NUMBER', '**** **** **** 3478'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildTextField('EXPIRATION DATE', '11/25')),
              const SizedBox(width: 16),
              Expanded(child: _buildTextField('CVV', '***')),
            ],
          ),
          const SizedBox(height: 32),
          CustomButton(text: 'Next', onPressed: () {}),
        ],
      ),
    );
  }

  Widget _buildAccountsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildAccountOption(
          icon: Icons.account_balance,
          title: 'Bank Link',
          subtitle: 'Connect your bank account to deposit & fund',
          isSelected: true,
        ),
        const SizedBox(height: 16),
        _buildAccountOption(
          icon: Icons.attach_money,
          title: 'Microdeposits',
          subtitle: 'Connect bank in 5-7 days',
          isSelected: false,
        ),
        const SizedBox(height: 16),
        _buildAccountOption(
          icon: Icons.payment,
          title: 'Paypal',
          subtitle: 'Connect your paypal account',
          isSelected: false,
        ),
      ],
    );
  }

  Widget _buildTextField(String label, String hint) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textTertiary)),
          TextField(
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.only(top: 4),
            ),
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.scaffoldBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          if (isSelected)
            const Icon(Icons.check_circle, color: AppColors.primary)
        ],
      ),
    );
  }
}
