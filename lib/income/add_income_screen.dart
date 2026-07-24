import 'package:ai_expense_tracker/generated/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../theme/app_colors.dart';
import '../providers/currency_provider.dart';

class AddIncomeScreen extends StatefulWidget {
  const AddIncomeScreen({super.key});

  @override
  State<AddIncomeScreen> createState() => _AddIncomeScreenState();
}

class _AddIncomeScreenState extends State<AddIncomeScreen> {
  final List<TextEditingController> titleControllers = [];
  final List<TextEditingController> amountControllers = [];
  final List<TextEditingController> categoryControllers = [];

  @override
  void initState() {
    super.initState();
    _addNewItem();
  }

  void _addNewItem() {
    setState(() {
      titleControllers.add(TextEditingController());

      final amountController = TextEditingController();
      amountController.addListener(() {
        setState(() {});
      });
      amountControllers.add(amountController);

      categoryControllers.add(TextEditingController());
    });
  }

  void _removeItem(int index) {
    if (titleControllers.length == 1) return;

    setState(() {
      titleControllers[index].dispose();
      amountControllers[index].dispose();
      categoryControllers[index].dispose();

      titleControllers.removeAt(index);
      amountControllers.removeAt(index);
      categoryControllers.removeAt(index);
    });
  }

  double get _totalAmount {
    double total = 0;
    for (var c in amountControllers) {
      total += double.tryParse(c.text) ?? 0;
    }
    return total;
  }

  bool get _isValid {
    for (int i = 0; i < titleControllers.length; i++) {
      final amount = double.tryParse(amountControllers[i].text) ?? 0;

      if (titleControllers[i].text.trim().isEmpty) return false;
      if (amount <= 0) return false;
      if (categoryControllers[i].text.trim().isEmpty) return false;
    }
    return titleControllers.isNotEmpty;
  }

  Future<void> _submitAll() async {
    if (!_isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LocaleKeys.income_Please_fill_all_fields_correctly.tr()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LocaleKeys.income_User_not_logged_in.tr()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final total = _totalAmount;
    final navigator = GoRouter.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final userDoc = await userRef.get();

      double currentBalance = 0;
      double currentIncome = 0;

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        currentBalance = (data['totalBalance'] as num?)?.toDouble() ?? 0;
        currentIncome = (data['totalIncome'] as num?)?.toDouble() ?? 0;
      }

      // إغلاق الصفحة فوراً بسلاسة
      navigator.pop();

      final batch = FirebaseFirestore.instance.batch();
      final transactionsRef = userRef.collection('transactions');

      for (int i = 0; i < titleControllers.length; i++) {
        final title = titleControllers[i].text.trim();
        final amount = double.parse(amountControllers[i].text);

        final categories = categoryControllers[i]
            .text
            .split(',')
            .map((e) => e.trim().toLowerCase())
            .where((e) => e.isNotEmpty)
            .toList();

        final docRef = transactionsRef.doc();

        batch.set(docRef, {
          'title': title,
          'amount': amount,
          'type': 'income',
          'category': categories,
          'date': Timestamp.now(),
        });
      }

      batch.set(
        userRef,
        {
          'uid': user.uid,
          'totalBalance': currentBalance + total,
          'totalIncome': currentIncome + total,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();
    } catch (e, s) {
      debugPrint('ERROR: ' + e.toString());
      debugPrintStack(stackTrace: s);

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error: ' + e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    for (var c in titleControllers) c.dispose();
    for (var c in amountControllers) c.dispose();
    for (var c in categoryControllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: Text(
          LocaleKeys.Home_categories_add_income.tr(),
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // رأس الصفحة المماثل لشاشة المصروفات مع تدرج اللون ولون مميز للإجمالي
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: AppColors.primary.withOpacity(0.1),
            child: Column(
              children: [
                Text(
                  LocaleKeys.income_Total.tr(),
                  style: TextStyle(color: Colors.grey, fontSize: 14.sp),
                ),
                SizedBox(height: 4.h),
                Text(
                  currency.formatAmount(_totalAmount),
                  style: TextStyle(
                    fontSize: 32.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  '${titleControllers.length} ${titleControllers.length == 1 ? LocaleKeys.Home_categories_expense_item.tr() : LocaleKeys.Home_categories_expense_items.tr()}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: titleControllers.length,
              itemBuilder: (_, i) => _buildItemCard(i),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // زر إضافة دخل جديد مطابق لتصميم المصروفات
                OutlinedButton.icon(
                  onPressed: _addNewItem,
                  icon: const Icon(Icons.add),
                  label: Text(LocaleKeys.Home_categories_add_income.tr()),
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50.h),
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ),
                SizedBox(height: 12.h),
                // زر إرسال الكل السفلي
                ElevatedButton.icon(
                  onPressed: _submitAll,
                  icon: const Icon(Icons.check),
                  label: Text(
                    LocaleKeys.Home_categories_expense_submit_all.tr(),
                    style: TextStyle(fontSize: 16.sp),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: Size(double.infinity, 50.h),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(int index) {
    final currency = context.read<CurrencyProvider>();

    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: titleControllers[index],
                    decoration: InputDecoration(
                      labelText: LocaleKeys.income_Title.tr(),
                      prefixIcon: const Icon(Icons.label_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                IconButton(
                  onPressed: () => _removeItem(index),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: amountControllers[index],
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: LocaleKeys.Home_amount.tr(),
                prefixText: '${currency.symbol} ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: categoryControllers[index],
              decoration: InputDecoration(
                labelText: LocaleKeys.income_categories_comma_separated.tr(),
                hintText: '${LocaleKeys.work.tr()}, ${LocaleKeys.freelance.tr()}, ${LocaleKeys.gift.tr()}',
                prefixIcon: const Icon(Icons.category_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}