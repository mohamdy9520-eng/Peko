import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../features/budget/budget_screen.dart';
import '../main_navigation_screen/main_navScreen.dart';
import '../features/auth/presentation/pages/login_screen.dart';
import '../features/auth/presentation/pages/register_screen.dart';
import '../features/auth/presentation/pages/verification/verify.dart';
import '../features/home/presentation/pages/home_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/splash/splash_screen.dart';
import '../income/add_income_screen.dart';
import '../features/expenses/add_expense_screen.dart';
import '../screens/transaction_details_screen.dart';
import '../screens/bill_payment_screen.dart';
import '../screens/profile_screen.dart';
import '../stats_screen/statistic_screen.dart';

class AppRouter {
  // ✅ Global Keys للـ Navigation
  static final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> shellNavigatorKey = GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    debugLogDiagnostics: true,

    redirect: (context, state) {
      final user = FirebaseAuth.instance.currentUser;
      final location = state.matchedLocation;

      final publicRoutes = ['/', '/onboarding', '/login', '/signup', '/verify-email'];
      if (publicRoutes.contains(location)) return null;

      if (user == null) return '/login';
      if (!user.emailVerified) return '/verify-email';

      final authRoutes = ['/login', '/signup', '/onboarding'];
      if (authRoutes.contains(location)) return '/home';

      return null;
    },

    routes: [
      // ✅ Public Routes (بدون Bottom Nav)
      GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignUpScreen()),
      GoRoute(path: '/verify-email', builder: (_, __) => const VerifyEmailScreen()),

      // ✅ StatefulShellRoute.indexedStack — كل الـ Tabs مع Bottom Nav
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainNavigationScreen(
            navigationShell: navigationShell,
          );
        },
        branches: [
          // 🔹 Home Tab
          StatefulShellBranch(
            navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'homeBranch'),
            routes: [
              GoRoute(
                path: '/home',
                builder: (_, __) => HomeScreen(),
              ),
            ],
          ),
          // 🔹 Stats Tab
          StatefulShellBranch(
            navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'statsBranch'),
            routes: [
              GoRoute(
                path: '/statistic',
                builder: (_, __) => const StatisticScreen(),
              ),
            ],
          ),
          // 🔹 Budget Tab
          StatefulShellBranch(
            navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'budgetBranch'),
            routes: [
              GoRoute(
                path: '/budget',
                builder: (_, __) => const BudgetScreen(),
              ),
            ],
          ),
          // 🔹 Profile Tab
          StatefulShellBranch(
            navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'profileBranch'),
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, __) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // ✅ صفحات خارج الـ BottomNav (تظهر فوق كل حاجة)
      GoRoute(
        path: '/add-expense',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const AddExpenseScreen(),
      ),
      GoRoute(
        path: '/add-income',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const AddIncomeScreen(),
      ),
      GoRoute(
        path: '/transaction-details',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const TransactionDetailsScreen(),
      ),
      GoRoute(
        path: '/bill-payment',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const BillPaymentScreen(),
      ),

      // ✅ Redirects
      GoRoute(path: '/main', redirect: (_, __) => '/home'),
    ],
  );
}