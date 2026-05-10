import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../theme/app_colors.dart';
import '../../../../widgets/transaction_item.dart';

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
        .limit(10)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddOptionsBottomSheet(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _buildHeader(context),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Transactions History',
                          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () => context.push('/transactions'),
                          child: const Text('See all'),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    _buildTransactionList(),
                    SizedBox(height: 24.h),
                    _buildSectionTitle('Send Again', 'See all'),
                    SizedBox(height: 16.h),
                    _buildSendAgainList(context),
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

  void _showAddOptionsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        padding: const EdgeInsets.all(24),
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
                'What would you like to add?',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 24.h),
              _buildOptionTile(
                context: context,
                icon: Icons.arrow_upward,
                iconColor: AppColors.expense,
                title: 'Add Expenses',
                subtitle: 'Add multiple expenses at once',
                onTap: () {
                  Navigator.pop(context);
                  context.push('/add-expense');
                },
              ),
              SizedBox(height: 12.h),
              _buildOptionTile(
                context: context,
                icon: Icons.arrow_downward,
                iconColor: AppColors.income,
                title: 'Add Income',
                subtitle: 'Add multiple income sources',
                onTap: () {
                  Navigator.pop(context);
                  context.push('/add-income');
                },
              ),
              SizedBox(height: 12.h),
              _buildOptionTile(
                context: context,
                icon: Icons.send,
                iconColor: AppColors.primary,
                title: 'Transfer',
                subtitle: 'Send money to a contact',
                onTap: () {
                  Navigator.pop(context);
                  _showTransferBottomSheet(context);
                },
              ),
              SizedBox(height: 16.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
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
        padding: const EdgeInsets.all(10),
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
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13.sp,
          color: AppColors.textSecondary,
        ),
      ),
      trailing: Icon(Icons.arrow_forward_ios, size: 16.sp, color: Colors.grey),
    );
  }

  void _showTransferBottomSheet(BuildContext context) {
    final amountController = TextEditingController();
    String? selectedContactId;
    String? selectedContactName;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final user = FirebaseAuth.instance.currentUser;

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
              ),
              padding: const EdgeInsets.all(24),
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
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 16.h),

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
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(12.r),
                            color: Colors.grey[50],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: Colors.grey),
                              SizedBox(width: 12.w),
                              const Expanded(
                                child: Text(
                                  'No contacts yet. Add contacts from "Send Again" section.',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final contacts = snapshot.data!.docs;

                      return DropdownButtonFormField<String>(
                        value: selectedContactId,
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
                          final email = data['email'] ?? '';

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
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (email.isNotEmpty)
                                        Text(
                                          email,
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
                        }).toList(),
                        onChanged: (value) {
                          setModalState(() {
                            selectedContactId = value;
                            final selectedDoc = contacts.firstWhere(
                                  (doc) => doc.id == value,
                            );
                            selectedContactName = (selectedDoc.data()
                            as Map<String, dynamic>)['name'] ?? 'Unknown';
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
                      prefixText: '\$ ',
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
                    child: ElevatedButton(
                      onPressed: selectedContactId == null ||
                          amountController.text.isEmpty
                          ? null
                          : () {
                        final amount = double.tryParse(amountController.text) ?? 0;
                        if (amount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter valid amount!'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        Navigator.pop(context);
                        _submitTransfer(
                          context: context,
                          toUser: selectedContactName!,
                          amount: amount,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: Colors.grey[300],
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Text(
                        'Send',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: getUserData(),
      builder: (context, snapshot) {
        String userName = 'User';
        double totalBalance = 0;
        double totalIncome = 0;
        double totalExpense = 0;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          userName = data['name'] ?? 'User';
          totalBalance = (data['totalBalance'] ?? 0).toDouble();
          totalIncome = (data['totalIncome'] ?? 0).toDouble();
          totalExpense = (data['totalExpense'] ?? 0).toDouble();
        } else {
          final user = FirebaseAuth.instance.currentUser;
          userName = user?.displayName ?? user?.email?.split('@')[0] ?? 'User';
        }

        return Container(
          padding: EdgeInsets.only(top: 20.h, left: 20.w, right: 20.w, bottom: 30.h),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Good afternoon,',
                          style: TextStyle(color: Colors.white70, fontSize: 14.sp),
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
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.notifications_none, color: Colors.white),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24.h),
              Text(
                'Total Balance',
                style: TextStyle(color: Colors.white70, fontSize: 16.sp),
              ),
              SizedBox(height: 8.h),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '\$ ${totalBalance.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              Row(
                children: [
                  Expanded(
                    child: _buildIncomeExpenseCard(
                      title: 'Income',
                      amount: '\$ ${totalIncome.toStringAsFixed(2)}',
                      icon: Icons.arrow_downward,
                      color: AppColors.income,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildIncomeExpenseCard(
                      title: 'Expense',
                      amount: '\$ ${totalExpense.toStringAsFixed(2)}',
                      icon: Icons.arrow_upward,
                      color: AppColors.expense,
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
    required String amount,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
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
                  amount,
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

  Widget _buildSectionTitle(String title, String action) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        TextButton(
          onPressed: () {},
          child: Text(
            action,
            style: TextStyle(
              fontSize: 14.sp,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionList() {
    return StreamBuilder<QuerySnapshot>(
      stream: getTransactions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Text(
                'No transactions yet\nTap + to add one!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16.sp),
              ),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          separatorBuilder: (_, __) => SizedBox(height: 12.h),
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

            final categoriesText = categories.isEmpty
                ? 'other'
                : categories.join(', ');

            final displayCategory =
            categories.length > 1 ? 'multiple' : categories.firstOrNull ?? 'other';

            return GestureDetector(
              onTap: () => _showTransactionDetails(context, doc.id, data),
              child: TransactionItem(
                icon: _getIconForCategory(displayCategory),
                iconBackgroundColor: _getColorForCategory(displayCategory),
                title: data['title'] ?? 'Unknown',
                subtitle: categoriesText,
                amount: (data['amount'] ?? 0).toDouble(),
                isIncome: data['type'] == 'income',
              ),
            );
          },
        );
      },
    );
  }

  void _showTransactionDetails(BuildContext context, String docId, Map<String, dynamic> data) {
    final bool isIncome = data['type'] == 'income';
    final String title = data['title'] ?? 'Unknown';
    final double amount = (data['amount'] ?? 0).toDouble();
    final String category = data['category'] ?? 'other';
    final int? itemCount = data['itemCount'];
    final Timestamp? date = data['date'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    margin: EdgeInsets.only(bottom: 24.h),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),

                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getColorForCategory(category).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: Icon(
                        _getIconForCategory(category),
                        color: _getColorForCategory(category),
                        size: 28.sp,
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (itemCount != null)
                            Text(
                              '$itemCount items',
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 24.h),

                Center(
                  child: Text(
                    '${isIncome ? '+' : '-'}\$${amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 36.sp,
                      fontWeight: FontWeight.bold,
                      color: isIncome ? AppColors.income : AppColors.expense,
                    ),
                  ),
                ),

                SizedBox(height: 24.h),

                _buildDetailRow('Type', isIncome ? 'Income' : 'Expense'),
                Divider(height: 16.h),
                _buildDetailRow('Category', category.toUpperCase()),
                Divider(height: 16.h),
                _buildDetailRow('Date', date != null ? _formatDate(date) : 'Unknown'),
                Divider(height: 16.h),
                _buildDetailRow('Transaction ID', docId.substring(0, 8) + '...'),

                SizedBox(height: 24.h),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _deleteTransaction(context, docId, amount, isIncome),
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text(
                      'Delete Transaction',
                      style: TextStyle(color: Colors.red),
                    ),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
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
        const SnackBar(content: Text('Transaction deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSendAgainList(BuildContext context) {
    return SizedBox(
      height: 80.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 6,
        padding: EdgeInsets.only(right: 16.w),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: GestureDetector(
                onTap: () => _showAddContactDialog(context),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56.w,
                      height: 56.h,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.divider,
                        border: Border.all(color: AppColors.primary, width: 2.w),
                      ),
                      child: Icon(Icons.person_add, color: AppColors.primary, size: 24.sp),
                    ),
                    SizedBox(height: 4.h),
                    Text('Add', style: TextStyle(fontSize: 11.sp, color: AppColors.primary)),
                  ],
                ),
              ),
            );
          }
          return Padding(
            padding: EdgeInsets.only(right: 12.w),
            child: GestureDetector(
              onTap: () => _showTransferDialog(context, 'User $index'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56.w,
                    height: 56.h,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withOpacity(0.1),
                    ),
                    child: Center(
                      child: Text(
                        'A$index',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp),
                      ),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text('User $index', style: TextStyle(fontSize: 11.sp)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddContactDialog(BuildContext context) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('contacts')
                    .add({
                  'name': nameController.text,
                  'email': emailController.text,
                  'createdAt': Timestamp.now(),
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showTransferDialog(BuildContext context, String contactName) {
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Transfer to $contactName'),
        content: TextField(
          controller: amountController,
          decoration: const InputDecoration(
            labelText: 'Amount',
            prefixText: '\$ ',
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _submitTransfer(
                context: context,
                toUser: contactName,
                amount: double.tryParse(amountController.text) ?? 0,
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
    required String toUser,
    required double amount,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User data not found!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final data = userDoc.data()!;
      double balance = (data['totalBalance'] ?? 0).toDouble();

      if (amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter valid amount!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (amount > balance) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Insufficient balance! You have only \$${balance.toStringAsFixed(2)}',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .add({
        'title': 'Transfer to $toUser',
        'amount': amount,
        'type': 'expense',
        'category': 'transfer',
        'date': Timestamp.now(),
      });

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'totalBalance': balance - amount,
        'totalExpense': (data['totalExpense'] ?? 0).toDouble() + amount,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transferred \$${amount.toStringAsFixed(2)} to $toUser'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  IconData _getIconForCategory(String category) {
    switch (category) {
      case 'work': return Icons.work_outline;
      case 'transfer': return Icons.person_outline;
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