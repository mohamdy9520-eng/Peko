import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../providers/currency_provider.dart';

class TransactionItem extends StatelessWidget {
  final IconData? icon;
  final Color iconBackgroundColor;
  final String title;
  final String subtitle;
  final double amount;
  final bool isIncome;
  final String? currencySymbol; // ✅ جديد
  final String? formattedAmount;

  const TransactionItem({
    super.key,
    this.icon,
    required this.iconBackgroundColor,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isIncome,
    this.currencySymbol, // ✅ جديد
    this.formattedAmount,
  });

  @override
  Widget build(BuildContext context) {
    final currencyProvider = context.watch<CurrencyProvider>();

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        children: [
          // Icon أو Symbol
          Container(
            width: 48.w,
            height: 48.h,
            decoration: BoxDecoration(
              color: iconBackgroundColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Center(
              child: icon != null
                  ? Icon(
                icon,
                color: iconBackgroundColor,
                size: 24.sp,
              )
                  : Text(
                // ✅ استخدم المبعوت أو من الـ Provider
                currencySymbol ?? currencyProvider.symbol,
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: iconBackgroundColor,
                ),
              ),
            ),
          ),
          SizedBox(width: 16.w),

          // Title & Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // Amount
          Text(
            '${isIncome ? '+' : '-'} ${currencyProvider.formatAmount(amount)}',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: isIncome ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}