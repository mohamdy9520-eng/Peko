import 'package:ai_expense_tracker/profile/screens_profile/profile_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/pages/login_screen.dart';
import '../features/auth/presentation/pages/register_screen.dart';
import '../features/auth/presentation/pages/verification/verify.dart';

import '../features/budget/AiResult_Screen/AiResult_screen.dart';
import '../features/budget/budget_screen.dart';

import '../features/expenses/add_expense_screen.dart';

import '../features/home/allTransactions/AllTransactionsScreen.dart';
import '../features/home/presentation/pages/home_screen.dart';

import '../features/onboarding/onboarding_screen.dart';

import '../features/splash/splash_screen.dart';

import '../income/add_income_screen.dart';

import '../main_navigation_screen/main_navScreen.dart';

import '../profile/screens_profile/personal_profile_screen.dart';
import '../screens/bill_payment_screen.dart';
import '../screens/transaction_details_screen.dart';

import '../stats_screen/statistic_screen.dart';

class AppRoutes {

  static const splash = '/';

  static const onboarding = '/onboarding';

  static const login = '/login';
  static const signup = '/signup';
  static const verifyEmail = '/verify-email';

  static const home = '/home';

  static const statistic = '/statistic';

  static const budget = '/budget';

  static const profile = '/profile';

  static const addExpense = '/add-expense';

  static const addIncome = '/add-income';

  static const transactionDetails =
      '/transaction-details';

  static const billPayment = '/bill-payment';

  static const transactions = '/transactions';

  static const aiResult = '/ai-result';

  static const main = '/main';
}

class AppRouter {

  static final GlobalKey<NavigatorState>
  rootNavigatorKey =
  GlobalKey<NavigatorState>();

  static final GlobalKey<NavigatorState>
  shellNavigatorKey =
  GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(

    navigatorKey: rootNavigatorKey,

    initialLocation: AppRoutes.splash,

    debugLogDiagnostics: true,

    errorBuilder: (context, state) {

      return Scaffold(
        backgroundColor: Colors.red[50],

        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),

            child: Column(
              mainAxisSize: MainAxisSize.min,

              children: [

                Icon(
                  Icons.error_outline,
                  size: 60.sp,
                  color: Colors.red[300],
                ),

                SizedBox(height: 16.h),

                Text(
                  'Navigation Error',

                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[800],
                  ),
                ),

                SizedBox(height: 8.h),

                Text(
                  '${state.error}',

                  textAlign: TextAlign.center,

                  style: TextStyle(
                    color: Colors.red[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },

    redirect: (context, state) {

      final user =
          FirebaseAuth.instance.currentUser;

      final location =
          state.matchedLocation;

      final publicRoutes = [

        AppRoutes.splash,

        AppRoutes.onboarding,

        AppRoutes.login,

        AppRoutes.signup,

        AppRoutes.verifyEmail,
      ];

      if (publicRoutes.contains(location)) {
        return null;
      }

      // المستخدم غير مسجل
      if (user == null) {
        return AppRoutes.login;
      }

      // الإيميل غير متحقق
      if (!user.emailVerified) {
        return AppRoutes.verifyEmail;
      }

      // منع الرجوع لشاشات الـ auth
      final authRoutes = [

        AppRoutes.login,

        AppRoutes.signup,

        AppRoutes.onboarding,
      ];

      if (authRoutes.contains(location)) {
        return AppRoutes.home;
      }

      return null;
    },

    routes: [

      /// Splash
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) =>
        const SplashScreen(),
      ),

      /// Onboarding
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, __) =>
        const OnboardingScreen(),
      ),

      /// Login
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) =>
        const LoginScreen(),
      ),

      /// Register
      GoRoute(
        path: AppRoutes.signup,
        builder: (_, __) =>
        const SignUpScreen(),
      ),

      /// Verify Email
      GoRoute(
        path: AppRoutes.verifyEmail,
        builder: (_, __) =>
        const VerifyEmailScreen(),
      ),

      /// Bottom Navigation Shell
      StatefulShellRoute.indexedStack(

        builder: (
            context,
            state,
            navigationShell,
            ) {

          return MainNavigationScreen(
            navigationShell:
            navigationShell,
          );
        },

        branches: [

          /// Home Branch
          StatefulShellBranch(

            navigatorKey:
            GlobalKey<NavigatorState>(
              debugLabel: 'homeBranch',
            ),

            routes: [

              GoRoute(
                path: AppRoutes.home,

                builder: (_, __) =>
                    HomeScreen(),
              ),
            ],
          ),

          /// Statistics Branch
          StatefulShellBranch(

            navigatorKey:
            GlobalKey<NavigatorState>(
              debugLabel: 'statsBranch',
            ),

            routes: [

              GoRoute(
                path: AppRoutes.statistic,

                builder: (_, __) =>
                const StatisticScreen(),
              ),
            ],
          ),

          /// Budget Branch
          StatefulShellBranch(

            navigatorKey:
            GlobalKey<NavigatorState>(
              debugLabel: 'budgetBranch',
            ),

            routes: [

              GoRoute(
                path: AppRoutes.budget,

                builder: (_, __) =>
                const BudgetScreen(),
              ),
            ],
          ),

          /// Profile Branch
          StatefulShellBranch(

            navigatorKey:
            GlobalKey<NavigatorState>(
              debugLabel:
              'profileBranch',
            ),

            routes: [

              GoRoute(
                path: AppRoutes.profile,

                builder: (_, __) =>
                const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      /// Add Expense
      GoRoute(

        path: AppRoutes.addExpense,

        parentNavigatorKey:
        rootNavigatorKey,

        builder: (_, __) =>
        const AddExpenseScreen(),
      ),

      /// Add Income
      GoRoute(

        path: AppRoutes.addIncome,

        parentNavigatorKey:
        rootNavigatorKey,

        builder: (_, __) =>
        const AddIncomeScreen(),
      ),

      /// Transaction Details
      GoRoute(

        path:
        AppRoutes.transactionDetails,

        parentNavigatorKey:
        rootNavigatorKey,

        builder: (_, __) =>
        const TransactionDetailsScreen(),
      ),

      /// Bill Payment
      GoRoute(

        path: AppRoutes.billPayment,

        parentNavigatorKey:
        rootNavigatorKey,

        builder: (_, __) =>
        const BillPaymentScreen(),
      ),

      /// All Transactions
      GoRoute(

        path: AppRoutes.transactions,

        parentNavigatorKey:
        rootNavigatorKey,

        builder: (_, __) =>
        const AllTransactionsScreen(),
      ),

      /// AI Result
      GoRoute(

        path: AppRoutes.aiResult,

        parentNavigatorKey:
        rootNavigatorKey,

        builder: (context, state) {

          final extra = state.extra;

          if (extra == null) {

            return const Scaffold(
              body: Center(
                child: Text(
                  'No data received',
                ),
              ),
            );
          }

          if (extra
          is! Map<String, dynamic>) {

            return const Scaffold(
              body: Center(
                child: Text(
                  'Invalid data format',
                ),
              ),
            );
          }

          final plan = extra['plan'];

          final planType =
          extra['planType'];

          if (plan == null ||
              planType == null) {

            return const Scaffold(
              body: Center(
                child: Text(
                  'Missing plan or planType',
                ),
              ),
            );
          }

          if (plan is! String ||
              planType is! String) {

            return const Scaffold(
              body: Center(
                child: Text(
                  'Invalid data types',
                ),
              ),
            );
          }

          return AIResultScreen(
            plan: plan,
            planType: planType,
          );
        },
      ),

      /// Main Redirect
      GoRoute(
        path: AppRoutes.main,

        redirect: (_, __) =>
        AppRoutes.home,
      ),
    ],
  );
}