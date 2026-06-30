import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AskAIFab extends StatelessWidget {
  const AskAIFab({
    super.key,
    required this.loading,
    required this.onPressed,
  });

  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: "ai_btn",
      onPressed: loading ? null : onPressed,
      backgroundColor: Colors.orange.shade600,
      icon: loading
          ? SizedBox(
        width: 20.w,
        height: 20.h,
        child: CircularProgressIndicator(
          strokeWidth: 2.w,
          color: Colors.white,
        ),
      )
          : const Icon(
        Icons.auto_awesome,
        color: Colors.white,
      ),
      label: Text(
        "Ask AI",
        style: TextStyle(
          fontSize: 15.sp,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

class AddSavingsFab extends StatelessWidget {
  const AddSavingsFab({
    super.key,
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: "add_savings_btn",
      onPressed: onPressed,
      backgroundColor: Colors.teal,
      icon: const Icon(Icons.savings, color: Colors.white),
      label: Text(
        "Add Savings",
        style: TextStyle(
          fontSize: 15.sp,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

class AddIncomeFab extends StatelessWidget {
  const AddIncomeFab({
    super.key,
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      backgroundColor: Colors.green,
      heroTag: "add_income_btn",
      onPressed: onPressed,
      icon: const Icon(Icons.add, color: Colors.white),
      label: Text(
        "Add Income",
        style: TextStyle(
          fontSize: 15.sp,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

class AddGoalFab extends StatelessWidget {
  const AddGoalFab({
    super.key,
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: "add_goal_btn",
      onPressed: onPressed,
      backgroundColor: Colors.amber,
      icon: const Icon(Icons.add, color: Colors.white),
      label: Text(
        "Add Goal",
        style: TextStyle(
          fontSize: 15.sp,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

class IncomeFABs extends StatelessWidget {
  const IncomeFABs({
    super.key,
    required this.loadingAi,
    required this.onAskAi,
    required this.onAddSavings,
    required this.onAddIncome,
  });

  final bool loadingAi;
  final VoidCallback onAskAi;
  final VoidCallback onAddSavings;
  final VoidCallback onAddIncome;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      reverse: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          AskAIFab(
            loading: loadingAi,
            onPressed: onAskAi,
          ),
          SizedBox(height: 12.h),
          AddSavingsFab(
            onPressed: onAddSavings,
          ),
          SizedBox(height: 12.h),
          AddIncomeFab(
            onPressed: onAddIncome,
          ),
        ],
      ),
    );
  }
}