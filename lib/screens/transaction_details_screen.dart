import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';

class TransactionDetailsScreen extends StatelessWidget {
  const TransactionDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Transaction Details'),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 20.sp),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            height: 150.h,
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
                    offset: Offset(0, 5.h),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60.w,
                    height: 60.h,
                    decoration: BoxDecoration(
                      color: AppColors.income.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.work, color: AppColors.income, size: 30.sp),
                  ),
                  SizedBox(height: 16.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: AppColors.income.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: const Text('Income', style: TextStyle(color: AppColors.income, fontWeight: FontWeight.w600)),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    '\$ 850.00',
                    style: TextStyle(fontSize: 32.sp, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  SizedBox(height: 32.h),
                  _buildDetailRow('Transaction details', isHeader: true),
                  SizedBox(height: 16.h),
                  _buildDetailRow('Status', value: 'Income', valueColor: AppColors.income),
                  SizedBox(height: 12.h),
                  _buildDetailRow('From', value: 'Upwork Escrow'),
                  SizedBox(height: 12.h),
                  _buildDetailRow('Time', value: '10:00 AM'),
                  SizedBox(height: 12.h),
                  _buildDetailRow('Date', value: 'Feb 28, 2022'),
                  SizedBox(height: 24.h),
                  const Divider(),
                  SizedBox(height: 24.h),
                  _buildDetailRow('Earnings', value: '\$ 870.00'),
                  SizedBox(height: 12.h),
                  _buildDetailRow('Fee', value: '- \$ 20.00'),
                  SizedBox(height: 24.h),
                  const Divider(),
                  SizedBox(height: 24.h),
                  _buildDetailRow('Total', value: '\$ 850.00', isBold: true),
                  SizedBox(height: 32.h),
                  OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50.sp),
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25.r)),
                    ),
                    child: Text('Download Receipt', style: TextStyle(color: AppColors.primary, fontSize: 16.sp, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, {String? value, Color? valueColor, bool isHeader = false, bool isBold = false}) {
    if (isHeader) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.textPrimary)),
          const Icon(Icons.keyboard_arrow_up, color: AppColors.textSecondary),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp)),
        Text(
          value ?? '',
          style: TextStyle(
            color: valueColor ?? AppColors.textPrimary,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            fontSize: isBold ? 16 : 14,
          ),
        ),
      ],
    );
  }
}
