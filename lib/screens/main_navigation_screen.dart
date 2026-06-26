import 'package:ai_expense_tracker/generated/codegen_loader.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../generated/locale_keys.g.dart';
import '../theme/app_colors.dart';

class MainNavigationScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainNavigationScreen({
    super.key,
    required this.navigationShell,
  });

  void _onTap(BuildContext context, int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      floatingActionButton: navigationShell.currentIndex == 0
          ? FloatingActionButton(
        onPressed: () => context.push('/add-expense'),
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white),
      )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home_outlined, Icons.home,LocaleKeys.main_navigation_home.tr(), 0),
            _buildNavItem(Icons.bar_chart_outlined, Icons.bar_chart,LocaleKeys.main_navigation_stats.tr(), 1),
            const SizedBox(width: 48),
            _buildNavItem(Icons.account_balance_wallet_outlined, Icons.account_balance_wallet,LocaleKeys.budget.tr(), 2),
            _buildNavItem(Icons.person_outline, Icons.person,LocaleKeys.main_navigation_profile.tr(), 3),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, IconData activeIcon, String label, int index) {
    final isSelected = navigationShell.currentIndex == index;

    return IconButton(
      icon: Icon(
        isSelected ? activeIcon : icon,
        color: isSelected ? AppColors.primary : AppColors.textTertiary,
      ),
      onPressed: () => navigationShell.goBranch(index),
    );
  }
}