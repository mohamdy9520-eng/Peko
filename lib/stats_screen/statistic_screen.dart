import 'dart:convert';
import 'dart:io';
import 'package:ai_expense_tracker/core/di/services/groqService.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/env.dart';
import '../generated/codegen_loader.g.dart';
import '../theme/app_colors.dart';
import '../widgets/transaction_item.dart';

class StatisticScreen extends StatefulWidget {
  const StatisticScreen({super.key});

  @override
  State<StatisticScreen> createState() => _StatisticScreenState();
}

class _StatisticScreenState extends State<StatisticScreen> {
  int _selectedFilterIndex = 2;
  late final List<String> _filters;

  String _selectedType = 'expense';
  String? _cachedAdvice;


  Future<String>? _adviceFuture;
  int? _lastFilterIndex;
  int? _lastTransactionCount;

  @override
  void initState() {
    super.initState();
    _filters = [
      LocaleKeys.date_day.tr(),
      LocaleKeys.date_week.tr(),
      LocaleKeys.date_month.tr(),
      LocaleKeys.date_year.tr(),
    ];
    _loadCachedAdvice();
  }

  Future<void> _loadCachedAdvice() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _cachedAdvice = prefs.getString('last_ai_advice');
    });
  }

  Future<void> _saveCachedAdvice(String advice) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_ai_advice', advice);
  }

  String _safeCategory(dynamic categoryData) {
    if (categoryData == null) return 'other';
    if (categoryData is String) return categoryData;
    if (categoryData is List && categoryData.isNotEmpty) {
      return categoryData.first.toString();
    }
    return 'other';
  }

  Stream<QuerySnapshot> getTransactions() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.empty();

    DateTime now = DateTime.now();
    DateTime startDate;

    switch (_selectedFilterIndex) {
      case 0: // Day
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 1: // Week
        startDate = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        break;
      case 2: // Month
        startDate = DateTime(now.year, now.month, 1);
        break;
      case 3: // Year
        startDate = DateTime(now.year, 1, 1);
        break;
      default:
        startDate = DateTime(now.year, now.month, 1);
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('transactions')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .orderBy('date', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedFilterIndex == 2,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectedFilterIndex != 2) {
          setState(() {
            _selectedFilterIndex = 2;
          });
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Center(
            child: Text(
              LocaleKeys.analytics_statistics.tr(),
              style: TextStyle(color: AppColors.textPrimary, fontSize: 25.sp, fontWeight: FontWeight.bold),
            ),
          ),
          backgroundColor: Colors.white,
          iconTheme: const IconThemeData(color: AppColors.textPrimary),
          actions: [
            IconButton(
              icon: const Icon(Icons.download_outlined),
              onPressed: _exportData,
            ),
          ],
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: getTransactions(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyState();
            }

            final transactions = snapshot.data!.docs
                .map((d) => d.data() as Map<String, dynamic>)
                .toList();

            final filteredTransactions = transactions
                .where((t) => t['type'] == _selectedType)
                .toList();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPeriodFilters(),
                  SizedBox(height: 24.h),
                  _buildStatisticsCards(transactions),
                  SizedBox(height: 24.h),
                  _buildTypeToggle(),
                  SizedBox(height: 24.h),
                  _buildLineChart(filteredTransactions),
                  SizedBox(height: 32.h),
                  _buildPieChart(filteredTransactions),
                  SizedBox(height: 32.h),
                  _buildBarChart(filteredTransactions),
                  SizedBox(height: 32.h),
                  _buildTopTransactions(filteredTransactions),
                  SizedBox(height: 32.h),
                  _buildAIInsights(transactions),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPeriodFilters() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(_filters.length, (index) {
        final isSelected = index == _selectedFilterIndex;
        return GestureDetector(
          onTap: () => setState(() => _selectedFilterIndex = index),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(
              _filters[index],
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTypeToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        GestureDetector(
          onTap: () => setState(() => _selectedType = 'expense'),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: _selectedType == 'expense' ? AppColors.expense.withOpacity(0.1) : null,
              border: Border.all(
                color: _selectedType == 'expense' ? AppColors.expense : AppColors.border,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Expense',
              style: TextStyle(
                color: _selectedType == 'expense' ? AppColors.expense : AppColors.textSecondary,
                fontWeight: _selectedType == 'expense' ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
        SizedBox(width: 8.w),
        GestureDetector(
          onTap: () => setState(() => _selectedType = 'income'),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: _selectedType == 'income' ? AppColors.income.withOpacity(0.1) : null,
              border: Border.all(
                color: _selectedType == 'income' ? AppColors.income : AppColors.border,
              ),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              'Income',
              style: TextStyle(
                color: _selectedType == 'income' ? AppColors.income : AppColors.textSecondary,
                fontWeight: _selectedType == 'income' ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticsCards(List<Map<String, dynamic>> transactions) {
    double totalIncome = 0;
    double totalExpense = 0;
    int count = transactions.length;

    for (var t in transactions) {
      double amount = (t['amount'] ?? 0).toDouble();
      if (t['type'] == 'income') {
        totalIncome += amount;
      } else {
        totalExpense += amount;
      }
    }

    double net = totalIncome - totalExpense;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LocaleKeys.expense_summary.tr(),
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 12.h),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildStatCard(
                LocaleKeys.expense_total_expense.tr(),
                '\$${totalExpense.toStringAsFixed(0)}',
                AppColors.expense,
                Icons.arrow_upward,
              ),
              SizedBox(width: 12.w),
              _buildStatCard(
                LocaleKeys.expense_total_income.tr(),
                '\$${totalIncome.toStringAsFixed(0)}',
                AppColors.income,
                Icons.arrow_downward,
              ),
              SizedBox(width: 12.w),
              _buildStatCard(
                LocaleKeys.expense_net.tr(),
                '\$${net.toStringAsFixed(0)}',
                net >= 0 ? AppColors.income : AppColors.expense,
                net >= 0 ? Icons.trending_up : Icons.trending_down,
              ),
              SizedBox(width: 12.w),
              _buildStatCard(
                LocaleKeys.expense_count.tr(),
                '$count',
                Colors.blue,
                Icons.receipt_long,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Container(
      width: 140.w,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24.sp),
          SizedBox(height: 12.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart(List<Map<String, dynamic>> transactions) {
    if (transactions.isEmpty) return const SizedBox.shrink();

    Map<String, double> dailyData = {};
    for (var t in transactions) {
      final date = (t['date'] as Timestamp).toDate();
      final key = DateFormat('MM/dd').format(date);
      dailyData[key] = (dailyData[key] ?? 0) + (t['amount'] ?? 0).toDouble();
    }

    final sortedKeys = dailyData.keys.toList()..sort();
    if (sortedKeys.length < 2) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_selectedType.toUpperCase()} ${LocaleKeys.trend.tr()}',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 16.h),
        SizedBox(
          height: 200.h,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30.w,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= 0 && value.toInt() < sortedKeys.length) {
                        return Text(
                          sortedKeys[value.toInt()],
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10.sp,
                          ),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40.w,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '\$${value.toInt()}',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10.sp,
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: List.generate(sortedKeys.length, (index) {
                    return FlSpot(
                      index.toDouble(),
                      dailyData[sortedKeys[index]]!,
                    );
                  }),
                  isCurved: true,
                  color: _selectedType == 'expense' ? AppColors.expense : AppColors.income,
                  barWidth: 3.w,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 4.r,
                        color: _selectedType == 'expense' ? AppColors.expense : AppColors.income,
                        strokeWidth: 2.w,
                        strokeColor: Colors.white,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: (_selectedType == 'expense' ? AppColors.expense : AppColors.income)
                        .withOpacity(0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPieChart(List<Map<String, dynamic>> transactions) {
    if (transactions.isEmpty) return const SizedBox.shrink();

    Map<String, double> categoryData = {};
    for (var t in transactions) {
      String cat = _safeCategory(t['category']);
      categoryData[cat] = (categoryData[cat] ?? 0) + (t['amount'] ?? 0).toDouble();
    }

    if (categoryData.isEmpty) return const SizedBox.shrink();

    final total = categoryData.values.reduce((a, b) => a + b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LocaleKeys.expense_distribution.tr(),
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 16.h),
        SizedBox(
          height: 200.h,
          child: PieChart(
            PieChartData(
              sections: categoryData.entries.map((entry) {
                final percentage = (entry.value / total) * 100;
                return PieChartSectionData(
                  value: entry.value,
                  color: _getCategoryColor(entry.key),
                  title: '${percentage.toStringAsFixed(0)}%',
                  radius: 80.r,
                  titleStyle: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.sp,
                  ),
                );
              }).toList(),
              sectionsSpace: 2.r,
              centerSpaceRadius: 40.r,
            ),
          ),
        ),
        SizedBox(height: 24.h),
        Wrap(
          spacing: 16.w,
          runSpacing: 12.h,
          alignment: WrapAlignment.center,
          children: categoryData.entries.map((entry) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 6.r,
                  backgroundColor: _getCategoryColor(entry.key),
                ),
                SizedBox(width: 8.w),
                Text(
                  entry.key.toUpperCase(),
                  style: TextStyle(fontSize: 11.sp),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBarChart(List<Map<String, dynamic>> transactions) {
    if (transactions.isEmpty) return const SizedBox.shrink();

    Map<String, double> categoryData = {};
    for (var t in transactions) {
      String cat = _safeCategory(t['category']);
      categoryData[cat] = (categoryData[cat] ?? 0) + (t['amount'] ?? 0).toDouble();
    }

    final sorted = categoryData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxValue = sorted.first.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LocaleKeys.expense_by_category.tr(),
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 16.h),
        SizedBox(
          height: 200.h,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxValue * 1.2,
              barTouchData: BarTouchData(enabled: true),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() < sorted.length) {
                        return Padding(
                          padding: EdgeInsets.only(top: 8.h),
                          child: Text(
                            sorted[value.toInt()].key.substring(0, 3).toUpperCase(),
                            style: TextStyle(fontSize: 10.sp),
                          ),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40.r,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '\$${value.toInt()}',
                        style: TextStyle(fontSize: 10.sp),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(sorted.length, (index) {
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: sorted[index].value,
                      color: _getCategoryColor(sorted[index].key),
                      width: 20.w,
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopTransactions(List<Map<String, dynamic>> transactions) {
    if (transactions.isEmpty) return const SizedBox.shrink();

    transactions.sort((a, b) => (b['amount'] ?? 0).compareTo(a['amount'] ?? 0));

    final top3 = transactions.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              LocaleKeys.transactions_top_transactions.tr(),
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.swap_vert, color: AppColors.textSecondary),
              onPressed: () {},
            ),
          ],
        ),
        SizedBox(height: 16.h),
        ...top3.map((t) {
          final category = _safeCategory(t['category']);
          return Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: TransactionItem(
              icon: _getIconForCategory(category),
              iconBackgroundColor: _getCategoryColor(category),
              title: t['title'] ?? 'Unknown',
              subtitle: _formatDate(t['date']),
              amount: (t['amount'] ?? 0).toDouble(),
              isIncome: t['type'] == 'income',
            ),
          );
        }),
      ],
    );
  }

  Future<String> _getAIAdvice(List<Map<String, dynamic>> transactions) {
    final currentFilter = _selectedFilterIndex;
    final currentCount = transactions.length;

    final isSameData = _adviceFuture != null &&
        _lastFilterIndex == currentFilter &&
        _lastTransactionCount == currentCount;

    if (isSameData) {
      return _adviceFuture!;
    }

    _lastFilterIndex = currentFilter;
    _lastTransactionCount = currentCount;

    _adviceFuture = GroqService(apiKey: Env.groqkey)
        .getExpenseInsight(transactions);

    return _adviceFuture!;
  }

  Widget _buildAIInsights(List<Map<String, dynamic>> transactions) {
    return FutureBuilder<String>(
      future: _getAIAdvice(transactions),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _cachedAdvice != null) {
          return _buildInsightCard(
            _cachedAdvice!,
            isLoading: true,
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingInsightCard();
        }

        if (snapshot.hasError) {
          final error = snapshot.error;
          String errorMessage;
          bool showCached = false;

          if (error is SocketException || error.toString().contains('SocketException')) {
            errorMessage = LocaleKeys.No_Internet.tr();
            showCached = true;
          } else if (error is HttpException) {
            errorMessage = LocaleKeys.No_server.tr();
          } else {
            errorMessage = LocaleKeys.unknown_error.tr();
          }

          if (showCached && _cachedAdvice != null) {
            return _buildInsightCard(
              _cachedAdvice!,
              isCached: true,
            );
          }

          return _buildErrorInsightCard(errorMessage);
        }

        final advice = snapshot.data ?? LocaleKeys.no_internet.tr();
        _saveCachedAdvice(advice);

        return _buildInsightCard(advice);
      },
    );
  }

  Widget _buildInsightCard(String advice, {bool isLoading = false, bool isCached = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade100, Colors.amber.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
              ),
            )
                : const Icon(Icons.lightbulb, color: Colors.amber),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      LocaleKeys.analytics_insight.tr(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                    if (isCached) ...[
                      SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          LocaleKeys.no_internet.tr(),
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  advice,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingInsightCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade100, Colors.amber.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              LocaleKeys.analytics_insight.tr(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorInsightCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wifi_off, color: Colors.red),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LocaleKeys.alert.tr(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.red[800],
                    fontSize: 13.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackInsight(List<Map<String, dynamic>> transactions) {
    Map<String, double> categoryTotals = {};
    for (var t in transactions) {
      if (t['type'] == 'expense') {
        String cat = _safeCategory(t['category']);
        categoryTotals[cat] = (categoryTotals[cat] ?? 0) + (t['amount'] ?? 0).toDouble();
      }
    }

    if (categoryTotals.isEmpty) return const SizedBox.shrink();

    final topCategory = categoryTotals.entries
        .reduce((a, b) => a.value > b.value ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade100, Colors.amber.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lightbulb, color: Colors.amber),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LocaleKeys.analytics_insight.tr(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  LocaleKeys.analytics_you_spent_most_on.tr(
                    args: [
                      topCategory.key.toUpperCase(),
                      topCategory.value.toStringAsFixed(0),
                    ],
                  ),
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.sp,
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart, size: 80, color: Colors.grey[300]),
          SizedBox(height: 16.h),
          Text(
            '${LocaleKeys.analytics_no_data_for.tr()} ${_filters[_selectedFilterIndex]}',
            style: TextStyle(
              fontSize: 16.sp,
              color: Colors.grey[500],
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'add_transactions_first'.tr(),
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  void _exportData() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export feature coming soon!')),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'food': return Colors.orange;
      case 'shopping': return Colors.purple;
      case 'transport': return Colors.blue;
      case 'bills': return Colors.red;
      case 'entertainment': return Colors.pink;
      case 'work': return AppColors.income;
      case 'transfer': return AppColors.expense;
      case 'multiple': return AppColors.primary;
      default: return Colors.grey;
    }
  }

  IconData _getIconForCategory(String category) {
    switch (category) {
      case 'food': return Icons.restaurant;
      case 'shopping': return Icons.shopping_bag;
      case 'transport': return Icons.directions_bus;
      case 'bills': return Icons.receipt;
      case 'entertainment': return Icons.movie;
      case 'work': return Icons.work_outline;
      case 'transfer': return Icons.person_outline;
      case 'multiple': return Icons.format_list_bulleted;
      default: return Icons.attach_money;
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'unknown'.tr();
    if (date is Timestamp) {
      final dt = date.toDate();
      return DateFormat('MMM dd, yyyy').format(dt);
    }
    return date.toString();
  }
}
