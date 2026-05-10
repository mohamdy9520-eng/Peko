import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';
import '../widgets/transaction_item.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        appBar: AppBar(
          title: const Text('Wallet'),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 20),
            onPressed: () {},
          ),
        ),
        body: Column(
          children: [
            Stack(
              alignment: Alignment.topCenter,
              children: [
                Container(
                  height: 120.h,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(30.r),
                      bottomRight: Radius.circular(30.r),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 20.h, left: 20.w, right: 20.w),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10.r,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                         Text(
                          'Total Balance',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14.sp,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          '\$ 2,548.00',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 32.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 24.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildActionButton(Icons.add, 'Add'),
                            _buildActionButton(Icons.qr_code_scanner, 'Pay'),
                            _buildActionButton(Icons.send_outlined, 'Send'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.divider.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(24.r),
                ),
                child: TabBar(
                  indicator: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(24.r),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textSecondary,
                  tabs: const [
                    Tab(text: 'Transactions'),
                    Tab(text: 'Upcoming Bills'),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Expanded(
              child: TabBarView(
                children: [
                  _buildTransactionsTab(),
                  _buildUpcomingBillsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, color: AppColors.textPrimary),
        ),
        SizedBox(height: 8.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionsTab() {
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical:10.h),
      children: [
        const TransactionItem(
          icon: Icons.work_outline,
          iconBackgroundColor: AppColors.income,
          title: 'Upwork',
          subtitle: 'Today',
          amount: 850.00,
          isIncome: true,
        ),
        SizedBox(height: 16.h),
        const TransactionItem(
          icon: Icons.person_outline,
          iconBackgroundColor: AppColors.expense,
          title: 'Transfer',
          subtitle: 'Yesterday',
          amount: 85.00,
          isIncome: false,
        ),
        SizedBox(height: 16.h),
        TransactionItem(
          icon: Icons.payment,
          iconBackgroundColor: Colors.blue.shade600,
          title: 'Paypal',
          subtitle: 'Jan 30, 2022',
          amount: 1406.00,
          isIncome: true,
        ),
      ],
    );
  }

  Widget _buildUpcomingBillsTab() {
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      children: [
        _buildBillItem(
          icon: Icons.play_arrow,
          color: Colors.red.shade600,
          title: 'Youtube',
          subtitle: 'Feb 28, 2022',
          amount: 11.99,
        ),
        SizedBox(height: 16.h),
        _buildBillItem(
          icon: Icons.electrical_services,
          color: Colors.orange,
          title: 'Electricity',
          subtitle: 'Mar 28, 2022',
          amount: 140.50,
        ),
        SizedBox(height: 16.h),
        _buildBillItem(
          icon: Icons.home,
          color: Colors.green,
          title: 'House Rent',
          subtitle: 'Mar 31, 2022',
          amount: 800.00,
        ),
      ],
    );
  }

  Widget _buildBillItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required double amount,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16.sp,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13.sp,
        ),
      ),
      trailing: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary.withOpacity(0.1),
          foregroundColor: AppColors.primary,
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          minimumSize: const Size(0, 36),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
        ),
        child: const Text('Pay'),
      ),
    );
  }
}
