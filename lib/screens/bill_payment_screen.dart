import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_button.dart';

class BillPaymentScreen extends StatelessWidget {
  const BillPaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Bill Details'),
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
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: const Icon(Icons.play_arrow, color: Colors.red),
                      ),
                      SizedBox(width: 16.w),
                       Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Youtube Premium', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16.sp)),
                          SizedBox(height: 4.h),
                          Text('Feb 28, 2022', style: TextStyle(color: AppColors.textSecondary, fontSize: 13.sp)),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 32.h),
                  _buildDetailRow('Price', '\$ 11.99'),
                  SizedBox(height: 12.h),
                  _buildDetailRow('Fee', '\$ 1.99'),
                  SizedBox(height: 24.h),
                  const Divider(),
                  SizedBox(height: 24.h),
                  _buildDetailRow('Total', '\$ 13.98', isBold: true),
                  SizedBox(height: 32.h),
                  const Text('Select payment method', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  SizedBox(height: 16.h),
                  _buildPaymentMethodOption('Debit Card', Icons.credit_card, true),
                  SizedBox(height: 12.h),
                  _buildPaymentMethodOption('Paypal', Icons.payment, false),
                  SizedBox(height: 32.h),
                  CustomButton(
                    text: 'Pay Now',
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp)),
        Text(
          value,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            fontSize: isBold ? 16 : 14,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodOption(String title, IconData icon, bool isSelected) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.scaffoldBackground,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.textPrimary),
              SizedBox(width: 12.w),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
          if (isSelected)
            const Icon(Icons.check_circle, color: AppColors.primary)
          else
            const Icon(Icons.radio_button_unchecked, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}
