import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_colors.dart';

mixin TransactionHelpers {
  String safeCategory(dynamic categoryData) {
    if (categoryData == null) return 'other';
    if (categoryData is String) return categoryData;
    if (categoryData is List && categoryData.isNotEmpty) {
      return categoryData.first.toString();
    }
    return 'other';
  }

  Color getCategoryColor(String category) {
    switch (category) {
      case 'food': return Colors.orange;
      case 'shopping': return Colors.purple;
      case 'transport': return Colors.blue;
      case 'bills': return Colors.red;
      case 'entertainment': return Colors.pink;
      case 'work': return AppColors.income;
      case 'transfer': return AppColors.expense;
      case 'multiple': return AppColors.primary;
      case 'health': return Colors.cyan;
      default: return Colors.grey;
    }
  }

  IconData getIconForCategory(String category) {
    switch (category) {
      case 'food': return Icons.restaurant;
      case 'shopping': return Icons.shopping_bag;
      case 'transport': return Icons.directions_bus;
      case 'bills': return Icons.receipt;
      case 'entertainment': return Icons.movie;
      case 'work': return Icons.work_outline;
      case 'transfer': return Icons.person_outline;
      case 'multiple': return Icons.format_list_bulleted;
      case 'health': return Icons.health_and_safety;
      default: return Icons.attach_money;
    }
  }

  String formatDate(dynamic date) {
    if (date == null) return 'Unknown';
    if (date is Timestamp) {
      final dt = date.toDate();
      return DateFormat('MMM dd, yyyy').format(dt);
    }
    return date.toString();
  }
}