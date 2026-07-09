import 'package:ai_expense_tracker/features/budget/widgets_budgets/plan_option_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../providers/currency_provider.dart';
import '../../../theme/app_colors.dart';

class AskAIBottomSheet {
  static Future<void> show(
      BuildContext context, {
        required Map<String, dynamic> aiResult,
        required ValueChanged<String> onPlanSelected,
      }) async {
    final double totalIncome =
        (aiResult['totalIncome'] as num?)?.toDouble() ?? 0.0;

    final double remaining =
        (aiResult['remaining'] as num?)?.toDouble() ?? 0.0;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        final currencyProvider = bottomSheetContext.watch<CurrencyProvider>();

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(24.r),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),

              SizedBox(height: 24.h),

              Text(
                'Choose Your AI Plan',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 8.h),

              Text(
                'Total Budget: ${currencyProvider.formatAmountCompact(totalIncome)}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14.sp,
                ),
              ),

              Text(
                'Available Budget: ${currencyProvider.formatAmountCompact(remaining)}',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),

              SizedBox(height: 24.h),

              PlanOptionTile(
                icon: Icons.calendar_month,
                title: 'Monthly Saving Plan',
                subtitle: 'Based on your income & expenses',
                color: Colors.deepPurple,
                onTap: () => _selectPlan(bottomSheetContext, onPlanSelected, 'monthly'),
              ),

              SizedBox(height: 12.h),

              PlanOptionTile(
                icon: Icons.calendar_today,
                title: 'Yearly Wealth Plan',
                subtitle: 'Long-term strategy with goals',
                color: Colors.teal,
                onTap: () => _selectPlan(bottomSheetContext, onPlanSelected, 'yearly'),
              ),

              SizedBox(height: 16.h),
            ],
          ),
        );
      },
    );
  }

  static void _selectPlan(BuildContext context, ValueChanged<String> onPlanSelected, String planType) {
    Navigator.of(context).pop();
    onPlanSelected(planType);
  }
}