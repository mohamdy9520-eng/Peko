import 'package:ai_expense_tracker/profile/screens_profile/profile_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/di/notifications/notification_screen.dart';
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
import '../screens/bill_payment_screen.dart';
import '../screens/currency_screen.dart';
import '../screens/language_screen.dart';
import '../screens/transaction_details_screen.dart';
import '../stats_screen/statistic_screen.dart';

class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const language = '/language';
  static const currency = '/currency';

  static const login = '/login';
  static const signup = '/signup';
  static const verifyEmail = '/verify-email';
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

    redirect: (context, state) async {
      final user = FirebaseAuth.instance.currentUser;
      final location = state.matchedLocation;

      final publicRoutes = [
        AppRoutes.splash,
        AppRoutes.onboarding,
        AppRoutes.login,
        AppRoutes.signup,
        AppRoutes.verifyEmail,
        AppRoutes.language,
        AppRoutes.currency,
        AppRoutes.forgotPassword,
        AppRoutes.verifyOtp,
        AppRoutes.resetPassword,
      ];

      if (publicRoutes.contains(location)) return null;

      // Not logged in → login
      if (user == null) return AppRoutes.login;

      // Email not verified
      if (!user.emailVerified) return AppRoutes.verifyEmail;

      // ⬅️ Check currency selection (AFTER auth)
      final prefs = await SharedPreferences.getInstance();
      final hasSelectedCurrency = prefs.getBool('has_selected_currency') ?? false;

      if (!hasSelectedCurrency && location != AppRoutes.currency) {
        return AppRoutes.currency;
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

      /// Notifications
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationScreen(),
      ),

      /// Contacts
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

      /// ⬅️ NEW: Currency Selection Screen
      GoRoute(
        path: AppRoutes.currency,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return CurrencySelectionScreen(
            isFirstTime: extra?['isFirstTime'] ?? true,
          );
        },
      ),

      /// Forgot Password Screens
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, __) => const ForgotPasswordScreen(),
      ),

      /// Main Shell (Bottom Navigation)
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
        path: '/add-income',
        builder: (context, state) => const AddIncomeScreen(),
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

      /// Statistic (duplicate route - for direct access)
      GoRoute(
        path: '/statisticScreen',
        builder: (context, state) => const StatisticScreen(),
      ),

      /// Edit Transaction
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

      /// All Transactions
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