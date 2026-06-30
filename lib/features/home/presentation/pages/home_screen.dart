import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../generated/locale_keys.g.dart';
import '../../../../providers/currency_provider.dart';
import '../../../../theme/app_colors.dart';
import '../../../../widgets/transaction_item.dart';
import '../../../../widgets/notification_icon.dart';

class HomeScreen extends StatelessWidget {
  HomeScreen({super.key});

  Stream<DocumentSnapshot> getUserData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots();
  }

  Stream<QuerySnapshot> getTransactions() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('transactions')
        .orderBy('date', descending: true)
        .limit(5)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_home', // ← ADDED: unique heroTag to fix Hero animation conflict
        onPressed: () => _showAddOptionsBottomSheet(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          LocaleKeys.expense_actions_add.tr(),
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _buildHeader(context),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 24.h),

                    _buildSectionHeader(
                      LocaleKeys.transactions_history.tr(),
                      onSeeAll: () => context.push('/transactions'),
                    ),
                    SizedBox(height: 16.h),
                    _buildTransactionList(context),
                    SizedBox(height: 24.h),

                    _buildSectionHeader(
                      LocaleKeys.contacts_title.tr(),
                      onSeeAll: () => context.push('/contacts'),
                    ),
                    SizedBox(height: 16.h),
                    _buildContactsList(context),
                    SizedBox(height: 100.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // HEADER — Balance + Notification Icon
  // ═══════════════════════════════════════════
  Widget _buildHeader(BuildContext context) {
    final currency = context.watch<CurrencyProvider>();

    return StreamBuilder<DocumentSnapshot>(
      stream: getUserData(),
      builder: (context, snapshot) {
        String userName = 'User';
        double totalBalance = 0;
        double totalIncome = 0;
        double totalExpense = 0;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;

          userName = data['name'] ??
              FirebaseAuth.instance.currentUser?.displayName ??
              FirebaseAuth.instance.currentUser?.email?.split('@')[0] ??
              'User';

          totalBalance = (data['totalBalance'] ?? 0).toDouble();
          totalIncome = (data['totalIncome'] ?? 0).toDouble();
          totalExpense = (data['totalExpense'] ?? 0).toDouble();
        } else {
          final user = FirebaseAuth.instance.currentUser;
          userName =
              user?.displayName ?? user?.email?.split('@')[0] ?? 'User';
        }

        return Container(
          padding: EdgeInsets.only(
            top: 20.h,
            left: 20.w,
            right: 20.w,
            bottom: 30.h,
          ),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30.r),
              bottomRight: Radius.circular(30.r),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome + Notification Icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          LocaleKeys.welcome_back.tr(),
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14.sp,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          userName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  const NotificationIcon(),
                ],
              ),

              SizedBox(height: 24.h),

              Text(
                LocaleKeys.expense_total_balance.tr(),
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16.sp,
                ),
              ),
              SizedBox(height: 8.h),

              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  currency.formatAmount(totalBalance),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              SizedBox(height: 20.h),

              // Income / Expense Cards
              Row(
                children: [
                  Expanded(
                    child: _buildIncomeExpenseCard(
                      title: LocaleKeys.common_income.tr(),
                      amount: totalIncome,
                      icon: Icons.arrow_downward,
                      color: AppColors.income,
                      currency: currency,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildIncomeExpenseCard(
                      title: LocaleKeys.expense_title.tr(),
                      amount: totalExpense,
                      icon: Icons.arrow_upward,
                      color: AppColors.expense,
                      currency: currency,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIncomeExpenseCard({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
    required CurrencyProvider currency,
  }) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 14.sp),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.white70, fontSize: 10.sp),
                  overflow: TextOverflow.ellipsis,
                ),

                SizedBox(height: 2.h),

                Text(
                  currency.formatAmountCompact(amount),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // QUICK ACTIONS
  // ═══════════════════════════════════════════

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28.sp),
            SizedBox(height: 8.h),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // SECTION HEADER
  // ═══════════════════════════════════════════
  Widget _buildSectionHeader(String title, {required VoidCallback onSeeAll}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        TextButton(
          onPressed: onSeeAll,
          child: const Text('See All'),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // ADD BOTTOM SHEET
  // ═══════════════════════════════════════════
  void _showAddOptionsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        padding: EdgeInsets.all(24.w),
        child: SingleChildScrollView(
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
                'What did you do?',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Quickly add your transaction',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 24.h),

              // Expense
              _buildAddOption(
                context: context,
                icon: Icons.arrow_upward,
                iconColor: Colors.red,
                title: 'I spent money',
                subtitle: 'Food, shopping, bills...',
                onTap: () {
                  Navigator.pop(context);
                  context.push('/add-expense');
                },
              ),
              SizedBox(height: 12.h),

              // Income
              _buildAddOption(
                context: context,
                icon: Icons.arrow_downward,
                iconColor: Colors.green,
                title: 'I received money',
                subtitle: 'Salary, gift, refund...',
                onTap: () {
                  Navigator.pop(context);
                  context.push('/add-income');
                },
              ),
              SizedBox(height: 12.h),

              // Transfer
              _buildAddOption(
                context: context,
                icon: Icons.swap_horiz,
                iconColor: Colors.purple,
                title: 'Transfer',
                subtitle: 'Send money to contact',
                onTap: () {
                  Navigator.pop(context);
                  _showTransferBottomSheet(context);
                },
              ),
              SizedBox(height: 12.h),

              // Add Contact
              _buildAddOption(
                context: context,
                icon: Icons.person_add,
                iconColor: Colors.blue,
                title: 'Add Contact',
                subtitle: 'Save a new contact',
                onTap: () {
                  Navigator.pop(context);
                  _showAddContactDialog(context);
                },
              ),
              SizedBox(height: 16.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddOption({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      leading: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16.sp,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13.sp,
          color: Colors.grey[600],
        ),
      ),
      trailing: Icon(Icons.arrow_forward_ios, size: 16.sp, color: Colors.grey),
    );
  }

  // ═══════════════════════════════════════════
  // TRANSACTIONS LIST
  // ═══════════════════════════════════════════
  Widget _buildTransactionList(BuildContext context) {
    final currency = context.watch<CurrencyProvider>();

    return StreamBuilder<QuerySnapshot>(
      stream: getTransactions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            width: double.infinity,
            margin: EdgeInsets.symmetric(horizontal: 4.w),
            padding: EdgeInsets.symmetric(vertical: 40.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 64.sp, color: Colors.grey[300]),
                SizedBox(height: 12.h),
                Text(
                  'No transactions yet',
                  style: TextStyle(color: Colors.grey, fontSize: 14.sp),
                ),
              ],
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: snapshot.data!.docs.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              indent: 68.w,
              endIndent: 16.w,
            ),
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final raw = data['category'];
              List<String> categories;
              if (raw is List) {
                categories = List<String>.from(raw);
              } else if (raw is String) {
                categories = [raw];
              } else {
                categories = [];
              }

              final displayCategory = categories.isEmpty ? 'other' : categories.first;

              return InkWell(
                onTap: () => _showTransactionDetails(context, doc.id, data),
                borderRadius: BorderRadius.vertical(
                  top: index == 0 ? Radius.circular(16.r) : Radius.zero,
                  bottom: index == snapshot.data!.docs.length - 1
                      ? Radius.circular(16.r)
                      : Radius.zero,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  child: TransactionItem(
                    icon: _getIconForCategory(displayCategory),
                    iconBackgroundColor: _getColorForCategory(displayCategory),
                    title: data['title'] ?? 'Unknown',
                    subtitle: categories.join(', '),
                    amount: (data['amount'] ?? 0).toDouble(),
                    isIncome: data['type'] == 'income',
                    currencySymbol: currency.symbol,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════
  // TRANSACTION DETAILS
  // ═══════════════════════════════════════════
  void _showTransactionDetails(BuildContext context, String docId, Map<String, dynamic> data) {
    final currency = context.read<CurrencyProvider>();
    final bool isIncome = data['type'] == 'income';
    final String title = data['title'] ?? 'Unknown';
    final double amount = (data['amount'] ?? 0).toDouble();
    final String category = data['category'] ?? 'other';
    final Timestamp? date = data['date'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.7,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: EdgeInsets.all(24.w),
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

                // Amount
                Container(
                  padding: EdgeInsets.all(20.w),
                  decoration: BoxDecoration(
                    color: isIncome ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                    color: isIncome ? Colors.green : Colors.red,
                    size: 40.sp,
                  ),
                ),
                SizedBox(height: 16.h),

                Text(
                  '${isIncome ? '+' : '-'}${currency.symbol}${amount.toStringAsFixed(currency.decimalDigits)}',
                  style: TextStyle(
                    fontSize: 36.sp,
                    fontWeight: FontWeight.bold,
                    color: isIncome ? Colors.green : Colors.red,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 24.h),

                // Details
                _buildDetailRow('Type', isIncome ? 'Income' : 'Expense'),
                Divider(height: 16.h),
                _buildDetailRow('Category', category.toUpperCase()),
                Divider(height: 16.h),
                _buildDetailRow('Date', date != null ? _formatDate(date) : 'Unknown'),

                SizedBox(height: 24.h),

                // Delete
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _deleteTransaction(context, docId, amount, isIncome),
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text('Delete', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTransaction(BuildContext context, String docId, double amount, bool isIncome) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = userDoc.data() ?? {};
      double currentBalance = (data['totalBalance'] ?? 0).toDouble();
      double currentIncome = (data['totalIncome'] ?? 0).toDouble();
      double currentExpense = (data['totalExpense'] ?? 0).toDouble();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .doc(docId)
          .delete();

      if (isIncome) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'totalBalance': currentBalance - amount,
          'totalIncome': currentIncome - amount,
        });
      } else {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'totalBalance': currentBalance + amount,
          'totalExpense': currentExpense - amount,
        });
      }

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction deleted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ═══════════════════════════════════════════
  // CONTACTS
  // ═══════════════════════════════════════════
  Widget _buildContactsList(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return SizedBox(
      height: 100.h,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('contacts')
            .orderBy('name')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final contacts = snapshot.data!.docs;

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: contacts.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: EdgeInsets.only(right: 12.w),
                  child: GestureDetector(
                    onTap: () => _showAddContactDialog(context),
                    child: Column(
                      children: [
                        Container(
                          width: 56.w,
                          height: 56.w,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.add,
                            color: AppColors.primary,
                            size: 24.sp,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        SizedBox(
                          width: 70.w,
                          child: Text(
                            'Add',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final contactIndex = index - 1;
              final data = contacts[contactIndex].data() as Map<String, dynamic>;
              final contactId = contacts[contactIndex].id;
              final name = data['name'] ?? 'Unknown';

              return Padding(
                padding: EdgeInsets.only(right: 12.w),
                child: GestureDetector(
                  onTap: () => _showTransferDialog(
                    context,
                    contactId: contactId,
                    contactName: name,
                    contactEmail: data['email'] ?? '',
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 28.r,
                        backgroundColor: Colors.grey[200],
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18.sp,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      SizedBox(
                        width: 70.w,
                        child: Text(
                          name,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.sp),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════
  // TRANSFER
  // ═══════════════════════════════════════════
  void _showTransferBottomSheet(BuildContext context) {
    final amountController = TextEditingController();
    String? selectedContactId;
    String? selectedContactName;
    String? selectedContactEmail;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final user = FirebaseAuth.instance.currentUser;
          final currency = context.read<CurrencyProvider>();

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
              ),
              padding: EdgeInsets.all(24.w),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40.w,
                        height: 4.h,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2.r),
                        ),
                      ),
                    ),
                    SizedBox(height: 24.h),
                    Text(
                      'Transfer Money',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // Contacts Dropdown
                    StreamBuilder<QuerySnapshot>(
                      stream: user != null
                          ? FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .collection('contacts')
                          .orderBy('name')
                          .snapshots()
                          : null,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Container(
                            padding: EdgeInsets.all(16.w),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(12.r),
                              color: Colors.grey[50],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, color: Colors.grey),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'No contacts found',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14.sp,
                                        ),
                                      ),
                                      SizedBox(height: 4.h),
                                      Text(
                                        'Add your first contact',
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        final contacts = snapshot.data!.docs;

                        return DropdownButtonFormField<String>(
                          value: selectedContactId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Select Contact',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          hint: const Text('Choose a contact'),
                          items: contacts.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final name = data['name'] ?? 'Unknown';

                            return DropdownMenuItem<String>(
                              value: doc.id,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14.r,
                                    backgroundColor: AppColors.primary.withOpacity(0.1),
                                    child: Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Text(name),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setModalState(() {
                              selectedContactId = value;
                              final selectedDoc = contacts.firstWhere(
                                    (doc) => doc.id == value,
                              );
                              final contactData = selectedDoc.data() as Map<String, dynamic>;
                              selectedContactName = contactData['name'] ?? 'Unknown';
                              selectedContactEmail = contactData['email'] ?? '';
                            });
                          },
                        );
                      },
                    ),

                    SizedBox(height: 16.h),

                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        prefixText: '${currency.symbol} ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),

                    SizedBox(height: 24.h),

                    SizedBox(
                      width: double.infinity,
                      height: 50.h,
                      child: ElevatedButton(
                        onPressed: selectedContactId == null ||
                            amountController.text.isEmpty
                            ? null
                            : () {
                          final amount = double.tryParse(amountController.text) ?? 0;
                          if (amount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Enter valid amount'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          Navigator.pop(context);
                          _submitTransfer(
                            context: context,
                            contactId: selectedContactId!,
                            contactName: selectedContactName!,
                            contactEmail: selectedContactEmail ?? '',
                            amount: amount,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor: Colors.grey[300],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: Text(
                          'Send',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 16.h),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showTransferDialog(
      BuildContext context, {
        required String contactId,
        required String contactName,
        required String contactEmail,
      }) {
    final amountController = TextEditingController();
    final currency = context.read<CurrencyProvider>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Transfer to $contactName'),
        content: TextField(
          controller: amountController,
          decoration: InputDecoration(
            labelText: 'Amount',
            prefixText: '${currency.symbol} ',
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _submitTransfer(
                context: context,
                contactId: contactId,
                contactName: contactName,
                contactEmail: contactEmail,
                amount: double.tryParse(amountController.text.trim()) ?? 0,
              );
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitTransfer({
    required BuildContext context,
    required String contactId,
    required String contactName,
    required String contactEmail,
    required double amount,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final userDoc = await userRef.get();

      if (!userDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final data = userDoc.data()!;
      final double balance = (data['totalBalance'] ?? 0).toDouble();
      final double totalExpense = (data['totalExpense'] ?? 0).toDouble();

      if (amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid amount'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (amount > balance) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Insufficient balance: ${context.read<CurrencyProvider>().formatAmount(balance)}'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final batch = FirebaseFirestore.instance.batch();

      final transactionRef = userRef.collection('transactions').doc();
      batch.set(transactionRef, {
        'title': 'Transfer to $contactName',
        'amount': amount,
        'type': 'expense',
        'category': 'transfer',
        'contactId': contactId,
        'contactName': contactName,
        'contactEmail': contactEmail,
        'date': Timestamp.now(),
      });

      final recentTransferRef = userRef.collection('recent_transfers').doc(contactId);
      batch.set(
        recentTransferRef,
        {
          'contactId': contactId,
          'name': contactName,
          'email': contactEmail,
          'lastTransferDate': Timestamp.now(),
          'transferCount': FieldValue.increment(1),
        },
        SetOptions(merge: true),
      );

      batch.update(userRef, {
        'totalBalance': balance - amount,
        'totalExpense': totalExpense + amount,
      });

      await batch.commit();

      if (context.mounted) {
        final currency = context.read<CurrencyProvider>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transferred ${currency.formatAmount(amount)} to $contactName'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddContactDialog(BuildContext context) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email or Phone'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('contacts')
                      .add({
                    'name': nameController.text.trim(),
                    'email': emailController.text.trim(),
                    'createdAt': Timestamp.now(),
                  });
                }
                Navigator.pop(dialogContext);
              } catch (e) {
                debugPrint('Error saving contact: $e');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════
  IconData _getIconForCategory(String category) {
    switch (category) {
      case 'work': return Icons.work_outline;
      case 'transfer': return Icons.swap_horiz;
      case 'payment': return Icons.payment;
      case 'food': return Icons.restaurant;
      case 'shopping': return Icons.shopping_bag;
      case 'multiple': return Icons.format_list_bulleted;
      default: return Icons.attach_money;
    }
  }

  Color _getColorForCategory(String category) {
    switch (category) {
      case 'work': return AppColors.income;
      case 'transfer': return AppColors.expense;
      case 'payment': return Colors.blue;
      case 'food': return Colors.orange;
      case 'shopping': return Colors.purple;
      case 'multiple': return AppColors.primary;
      default: return Colors.grey;
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';
    if (date is Timestamp) {
      final dt = date.toDate();
      return '${dt.day}/${dt.month}/${dt.year}';
    }
    return date.toString();
  }
}