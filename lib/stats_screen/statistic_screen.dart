import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../widgets/transaction_item.dart';

class StatisticScreen extends StatefulWidget {
  const StatisticScreen({super.key});

  @override
  State<StatisticScreen> createState() => _StatisticScreenState();
}

class _StatisticScreenState extends State<StatisticScreen> {
  int _selectedFilterIndex = 2; // Default: Month
  final List<String> _filters = ['Day', 'Week', 'Month', 'Year'];
  String _selectedType = 'expense'; // expense or income

  // ═══════════════════════════════════════════════════════
  // FIRESTORE STREAM
  // ═══════════════════════════════════════════════════════

  Stream<QuerySnapshot> getTransactions() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.empty();

    DateTime now = DateTime.now();
    DateTime startDate;

    switch (_filters[_selectedFilterIndex]) {
      case 'Day':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'Week':
        startDate = now.subtract(Duration(days: now.weekday - 1)); // Start of week
        break;
      case 'Year':
        startDate = DateTime(now.year, 1, 1);
        break;
      case 'Month':
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

  // ═══════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedFilterIndex == 2, // 👈 يسمح بالخروج بس لو Month
      onPopInvoked: (didPop) {
        if (!didPop && _selectedFilterIndex != 2) {
          setState(() {
            _selectedFilterIndex = 2;
          });
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            'Statistics',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          backgroundColor: Colors.white,
          iconTheme: const IconThemeData(color: AppColors.textPrimary),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 20),
            onPressed: () {
              if (_selectedFilterIndex != 2) {
                setState(() {
                  _selectedFilterIndex = 2;
                });
              } else {
                context.pop();
              }
            },
          ),
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
                  const SizedBox(height: 24),
                  _buildStatisticsCards(transactions),
                  const SizedBox(height: 24),
                  _buildTypeToggle(),
                  const SizedBox(height: 24),
                  _buildLineChart(filteredTransactions),
                  const SizedBox(height: 32),
                  _buildPieChart(filteredTransactions),
                  const SizedBox(height: 32),
                  _buildBarChart(filteredTransactions),
                  const SizedBox(height: 32),
                  _buildTopTransactions(filteredTransactions),
                  const SizedBox(height: 32),
                  _buildInsights(transactions),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // UI COMPONENTS
  // ═══════════════════════════════════════════════════════

  Widget _buildPeriodFilters() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(_filters.length, (index) {
        final isSelected = index == _selectedFilterIndex;
        return GestureDetector(
          onTap: () => setState(() => _selectedFilterIndex = index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => setState(() => _selectedType = 'income'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: _selectedType == 'income' ? AppColors.income.withOpacity(0.1) : null,
              border: Border.all(
                color: _selectedType == 'income' ? AppColors.income : AppColors.border,
              ),
              borderRadius: BorderRadius.circular(8),
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

  // ═══════════════════════════════════════════════════════
  // STATISTICS CARDS (KPIs)
  // ═══════════════════════════════════════════════════════

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
        const Text(
          'Summary',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildStatCard(
                'Total Expense',
                '\$${totalExpense.toStringAsFixed(0)}',
                AppColors.expense,
                Icons.arrow_upward,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'Total Income',
                '\$${totalIncome.toStringAsFixed(0)}',
                AppColors.income,
                Icons.arrow_downward,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'Net',
                '\$${net.toStringAsFixed(0)}',
                net >= 0 ? AppColors.income : AppColors.expense,
                net >= 0 ? Icons.trending_up : Icons.trending_down,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'Count',
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
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // CHARTS
  // ═══════════════════════════════════════════════════════

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
          '${_selectedType.toUpperCase()} Trend',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= 0 && value.toInt() < sortedKeys.length) {
                        return Text(
                          sortedKeys[value.toInt()],
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
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
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '\$${value.toInt()}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
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
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 4,
                        color: _selectedType == 'expense' ? AppColors.expense : AppColors.income,
                        strokeWidth: 2,
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

  // ✅ الدالة الوحيدة والمصلحة
  Widget _buildPieChart(List<Map<String, dynamic>> transactions) {
    if (transactions.isEmpty) return const SizedBox.shrink();

    Map<String, double> categoryData = {};
    for (var t in transactions) {
      String cat = t['category'] ?? 'other';
      categoryData[cat] = (categoryData[cat] ?? 0) + (t['amount'] ?? 0).toDouble();
    }

    if (categoryData.isEmpty)
      return const SizedBox.shrink();


    final total = categoryData.values.reduce((a, b) => a + b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Distribution',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sections: categoryData.entries.map((entry) {
                final percentage = (entry.value / total) * 100;
                return PieChartSectionData(
                  value: entry.value,
                  color: _getCategoryColor(entry.key),
                  title: '${percentage.toStringAsFixed(0)}%',
                  radius: 80,
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              }).toList(),
              sectionsSpace: 2,
              centerSpaceRadius: 40,
            ),
          ),
        ),
        const SizedBox(height: 24), // ✅ المسافة بين PieChart والـ Legend
        Wrap(
          spacing: 16,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: categoryData.entries.map((entry) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 6,
                  backgroundColor: _getCategoryColor(entry.key),
                ),
                const SizedBox(width: 8),
                Text(
                  entry.key.toUpperCase(),
                  style: const TextStyle(fontSize: 11),
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
      String cat = t['category'] ?? 'other';
      categoryData[cat] = (categoryData[cat] ?? 0) + (t['amount'] ?? 0).toDouble();
    }

    final sorted = categoryData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxValue = sorted.first.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'By Category',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
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
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            sorted[value.toInt()].key.substring(0, 3).toUpperCase(),
                            style: const TextStyle(fontSize: 10),
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
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '\$${value.toInt()}',
                        style: const TextStyle(fontSize: 10),
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
                      width: 20,
                      borderRadius: BorderRadius.circular(4),
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

  // ═══════════════════════════════════════════════════════
  // TOP TRANSACTIONS
  // ═══════════════════════════════════════════════════════

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
            const Text(
              'Top Transactions',
              style: TextStyle(
                fontSize: 18,
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
        const SizedBox(height: 16),
        ...top3.map((t) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TransactionItem(
              icon: _getIconForCategory(t['category'] ?? 'other'),
              iconBackgroundColor: _getCategoryColor(t['category'] ?? 'other'),
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

  // ═══════════════════════════════════════════════════════
  // INSIGHTS (AI)
  // ═══════════════════════════════════════════════════════

  Widget _buildInsights(List<Map<String, dynamic>> transactions) {
    Map<String, double> categoryTotals = {};
    for (var t in transactions) {
      if (t['type'] == 'expense') {
        String cat = t['category'] ?? 'other';
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '💡 Insight',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'You spent most on ${topCategory.key.toUpperCase()} (\$${topCategory.value.toStringAsFixed(0)})',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // EMPTY STATE
  // ═══════════════════════════════════════════════════════

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No data for ${_filters[_selectedFilterIndex]}',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add some transactions first!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // EXPORT
  // ═══════════════════════════════════════════════════════

  void _exportData() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📊 Export feature coming soon!')),
    );
  }

  // ═══════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════

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
    if (date == null) return 'Unknown';
    if (date is Timestamp) {
      final dt = date.toDate();
      return DateFormat('MMM dd, yyyy').format(dt);
    }
    return date.toString();
  }
}