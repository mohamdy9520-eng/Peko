import 'package:ai_expense_tracker/profile/screens_profile/profile_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/pages/forgetPassword_screen/forget_password.dart';
import '../features/auth/presentation/pages/login_screen.dart';
import '../features/auth/presentation/pages/register_screen.dart';
import '../features/auth/presentation/pages/verification/verify.dart';

import '../features/budget/AiResult_Screen/AiResult_screen.dart';
import '../features/budget/budget_screen.dart';

import '../features/contacts_Screen/contacts_screen.dart';
import '../features/expenses/add_expense_screen.dart';

import '../features/home/allTransactions/AllTransactionsScreen.dart';
import '../features/home/allTransactions/edit_transaction.dart';
import '../features/home/presentation/pages/home_screen.dart';

import '../features/onboarding/onboarding_screen.dart';

import '../features/splash/splash_screen.dart';

import '../income/add_income_screen.dart';

import '../main_navigation_screen/main_navScreen.dart';

import '../profile/screens_profile/personal_profile_screen.dart';
import '../screens/bill_payment_screen.dart';
import '../screens/language_screen.dart';
import '../screens/transaction_details_screen.dart';

import '../stats_screen/statistic_screen.dart';

class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';

  static const login = '/login';
  static const signup = '/signup';
  static const verifyEmail = '/verify-email';

  // ✅ Forgot Password Routes
  static const forgotPassword = '/forgot-password';
  static const verifyOtp = '/verify-otp';
  static const resetPassword = '/reset-password';

  static const home = '/home';
  static const statistic = '/statistic';
  static const budget = '/budget';
  static const profile = '/profile';
  static const contacts = '/contacts';

  static const addExpense = '/add-expense';
  static const addIncome = '/add-income';

  static const transactionDetails = '/transaction-details';
  static const billPayment = '/bill-payment';
  static const transactions = '/transactions';

  static const aiResult = '/ai-result';

  static const main = '/main';

  static const language = '/language';
}

class AppRouter {
  static final GlobalKey<NavigatorState> rootNavigatorKey =
  GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,

    errorBuilder: (context, state) {
      return Scaffold(
        backgroundColor: Colors.red[50],
        body: Center(
          child: Text('${state.error}'),
        ),
      );
    },

    redirect: (context, state) {
      final user = FirebaseAuth.instance.currentUser;
      final location = state.matchedLocation;

      final publicRoutes = [
        AppRoutes.splash,
        AppRoutes.onboarding,
        AppRoutes.login,
        AppRoutes.signup,
        AppRoutes.verifyEmail,
        AppRoutes.language,
        // ✅ Added forgot password routes
        AppRoutes.forgotPassword,
        AppRoutes.verifyOtp,
        AppRoutes.resetPassword,
      ];

      // لو داخل public route سيب المستخدم
      if (publicRoutes.contains(location)) {
        return null;
      }

      // غير مسجل
      if (user == null) {
        return AppRoutes.login;
      }

      // الإيميل غير متحقق
      if (!user.emailVerified) {
        return AppRoutes.verifyEmail;
      }

      return null;
    },

    routes: [
      /// Splash
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashScreen(),
      ),

      /// Onboarding
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, __) => const OnboardingScreen(),
      ),

      /// Login
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),

      /// Signup
      GoRoute(
        path: AppRoutes.signup,
        builder: (_, __) => const SignUpScreen(),
      ),

      GoRoute(
        path: AppRoutes.contacts,
        parentNavigatorKey: AppRouter.rootNavigatorKey,
        builder: (_, __) => const ContactsScreen(),
      ),

      /// Verify
      GoRoute(
        path: AppRoutes.verifyEmail,
        builder: (_, __) => const VerifyEmailScreen(),
      ),

      /// Language Screen
      GoRoute(
        path: AppRoutes.language,
        builder: (_, __) => const LanguageScreen(),
      ),

      // ✅ Forgot Password Screens
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, __) => const ForgotPasswordScreen(),
      ),


      /// Main Shell
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainNavigationScreen(
            navigationShell: navigationShell,
          );
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: GlobalKey<NavigatorState>(),
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (_, __) => HomeScreen(),
              ),
            ],
          ),

          StatefulShellBranch(
            navigatorKey: GlobalKey<NavigatorState>(),
            routes: [
              GoRoute(
                path: AppRoutes.statistic,
                builder: (_, __) => const StatisticScreen(),
              ),
            ],
          ),

          StatefulShellBranch(
            navigatorKey: GlobalKey<NavigatorState>(),
            routes: [
              GoRoute(
                path: AppRoutes.budget,
                builder: (_, __) => const BudgetScreen(),
              ),
            ],
          ),

          StatefulShellBranch(
            navigatorKey: GlobalKey<NavigatorState>(),
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (_, __) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      /// Add Expense
      GoRoute(
        path: AppRoutes.addExpense,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const AddExpenseScreen(),
      ),

      /// Add Income
      GoRoute(
        path: AppRoutes.addIncome,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const AddIncomeScreen(),
      ),

      /// Transaction Details
      GoRoute(
        path: AppRoutes.transactionDetails,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const TransactionDetailsScreen(),
      ),

      /// Bill Payment
      GoRoute(
        path: AppRoutes.billPayment,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const BillPaymentScreen(),
      ),

      GoRoute(
        path: '/statisticScreen',
        builder: (context, state) => const StatisticScreen(),
      ),

      GoRoute(
        path: '/edit-transaction',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;

          return EditTransactionScreen(
            docId: extra['docId'],
            data: extra['data'],
          );
        },
      ),

      /// Transactions
      GoRoute(
        path: AppRoutes.transactions,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const AllTransactionsScreen(),
      ),

      /// AI Result
      GoRoute(
        path: AppRoutes.aiResult,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;

          if (extra == null) {
            return const Scaffold(
              body: Center(child: Text('No data received')),
            );
          }

          return AIResultScreen(
            plan: extra['plan'],
            planType: extra['planType'],
          );
        },
      ),

      /// Main redirect
      GoRoute(
        path: AppRoutes.main,
        redirect: (_, __) => AppRoutes.home,
      ),
    ],
  );
}