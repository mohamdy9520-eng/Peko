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
import '../profile/screens_profile/change_Currency.dart';
import '../screens/bill_payment_screen.dart';
import '../screens/biometricLoginScreen.dart';
import '../screens/currency_screen.dart';
import '../screens/language_screen.dart';
import '../screens/transaction_details_screen.dart';
import '../stats_screen/statistic_screen.dart';

class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const language = '/language';
  static const currency = '/currency';
  static const changeCurrency = '/change-currency';

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

  // ✅ STATIC keys for StatefulShellBranch navigators
  static final GlobalKey<NavigatorState> _homeNavKey = GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> _statsNavKey = GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> _budgetNavKey = GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> _profileNavKey = GlobalKey<NavigatorState>();

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

      if (user == null) return AppRoutes.login;
      if (!user.emailVerified) return AppRoutes.verifyEmail;

      final prefs = await SharedPreferences.getInstance();
      final hasSelectedCurrency = prefs.getBool('has_selected_currency') ?? false;

      if (!hasSelectedCurrency && location != AppRoutes.currency) {
        return AppRoutes.currency;
      }

      return null;
    },

    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (_, __) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationScreen(),
      ),
      GoRoute(
        path: AppRoutes.contacts,
        parentNavigatorKey: AppRouter.rootNavigatorKey,
        builder: (_, __) => const ContactsScreen(),
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        builder: (_, __) => const VerifyEmailScreen(),
      ),
      GoRoute(
        path: AppRoutes.language,
        builder: (_, __) => const LanguageScreen(),
      ),
      GoRoute(
        path: AppRoutes.currency,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return CurrencySelectionScreen(
            isFirstTime: extra?['isFirstTime'] ?? true,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.changeCurrency,
        builder: (_, __) => const ChangeCurrencyScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, __) => const ForgotPasswordScreen(),
      ),

      // ✅ Main Shell with STATIC navigator keys
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainNavigationScreen(
            navigationShell: navigationShell,
          );
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: _homeNavKey,
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (_, __) => HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _statsNavKey,
            routes: [
              GoRoute(
                path: AppRoutes.statistic,
                builder: (_, __) => const StatisticScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _budgetNavKey,
            routes: [
              GoRoute(
                path: AppRoutes.budget,
                builder: (_, __) => const BudgetScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _profileNavKey,
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (_, __) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      GoRoute(
        path: AppRoutes.addExpense,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const AddExpenseScreen(),
      ),
      GoRoute(
        path: '/add-income',
        builder: (context, state) => const AddIncomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.transactionDetails,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const TransactionDetailsScreen(),
      ),
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
      GoRoute(
        path: AppRoutes.transactions,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const AllTransactionsScreen(),
      ),

      GoRoute(
        path: '/biometric-login',
        builder: (context, state) => const BiometricLoginScreen(),
      ),


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
      GoRoute(
        path: AppRoutes.main,
        redirect: (_, __) => AppRoutes.home,
      ),
    ],
  );
}