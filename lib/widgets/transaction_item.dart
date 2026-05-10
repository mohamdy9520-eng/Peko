import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';

class TransactionItem extends StatelessWidget {
  final IconData icon;
  final Color iconBackgroundColor;
  final String title;
  final String subtitle;
  final double amount;
  final bool isIncome;

  const TransactionItem({
    super.key,
    required this.icon,
    required this.iconBackgroundColor,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isIncome,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding:EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: iconBackgroundColor.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Icon(
          icon,
          color: iconBackgroundColor,
        ),
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
        style:TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13.sp,
        ),
      ),
      trailing: Text(
        '${isIncome ? '+' : '-'} \$${amount.toStringAsFixed(2)}',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16.sp,
          color: isIncome ? AppColors.income : AppColors.expense,
        ),
      ),
    );
  }
}
