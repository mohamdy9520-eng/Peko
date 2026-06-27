import 'package:flutter/material.dart';

class IncomeCategoryIcon extends StatelessWidget {
  final String category;
  final bool isSavings;
  final double? size;
  final Color? color;

  const IncomeCategoryIcon({
    super.key,
    required this.category,
    this.isSavings = false,
    this.size,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (isSavings) {
      return Icon(
        Icons.savings_rounded,
        size: size,
        color: color ?? Colors.teal,
      );
    }

    return Icon(
      _icon(category),
      size: size,
      color: color,
    );
  }

  IconData _icon(String category) {
    switch (category.toLowerCase()) {
      case 'salary':
        return Icons.work_rounded;
      case 'freelance':
        return Icons.laptop_mac_rounded;
      case 'investment':
        return Icons.trending_up_rounded;
      case 'business':
        return Icons.storefront_rounded;
      case 'gift':
        return Icons.card_giftcard_rounded;
      case 'bonus':
        return Icons.workspace_premium_rounded;
      case 'savings':
        return Icons.savings_rounded;
      case 'passive_income':
        return Icons.payments_rounded;
      case 'rental':
        return Icons.home_work_rounded;
      default:
        return Icons.account_balance_wallet_rounded;
    }
  }
}