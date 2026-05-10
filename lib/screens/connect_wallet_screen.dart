import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
            icon: Icon(Icons.arrow_back_ios, size: 20.sp),
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
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                child: Container(
                  height: 48.h,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(24.r),
                  ),
                  child: TabBar(
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24.r),
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
          Container(
            height: 180.h,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20.r),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Debit Card', style: TextStyle(color: Colors.white, fontSize: 16.sp)),
                    Row(
                      children: [
                        Container(width: 16.w, height: 16.h, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                        Transform.translate(
                          offset: Offset(-8.w, 0),
                          child: Container(width: 16.w, height: 16.h, decoration: BoxDecoration(color: Colors.orange.withOpacity(0.8), shape: BoxShape.circle)),
                        ),
                      ],
                    ),
                  ],
                ),
                Text('**** **** **** 3478', style: TextStyle(color: Colors.white, fontSize: 22.sp, letterSpacing: 2.sp)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                     Text('11/24', style: TextStyle(color: Colors.white, fontSize: 16.sp)),
                     Text('11/25', style: TextStyle(color: Colors.white, fontSize: 16.sp)),
                  ],
                ),
              ],
            ),
          ),
           SizedBox(height: 32.h),
          const Text('Add your debit card', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
           SizedBox(height: 8.h),
          const Text('This card must be linked to a bank account.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
           SizedBox(height: 24.h),
          _buildTextField('NAME ON CARD', 'ENJELIN MORGEANA'),
           SizedBox(height: 16.h),
          _buildTextField('DEBIT CARD NUMBER', '**** **** **** 3478'),
           SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(child: _buildTextField('EXPIRATION DATE', '11/25')),
              SizedBox(width: 16.w),
              Expanded(child: _buildTextField('CVV', '***')),
            ],
          ),
          SizedBox(height: 32.h),
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
        SizedBox(height: 16.h),
        _buildAccountOption(
          icon: Icons.attach_money,
          title: 'Microdeposits',
          subtitle: 'Connect bank in 5-7 days',
          isSelected: false,
        ),
        SizedBox(height: 16.h),
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
        borderRadius: BorderRadius.circular(8.r),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10.sp, color: AppColors.textTertiary)),
          TextField(
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.only(top: 4.h),
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
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppColors.scaffoldBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.textSecondary),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16.sp)),
                SizedBox(height: 4.h),
                Text(subtitle, style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp)),
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
