import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../widgets/transaction_item.dart';

class AllTransactionsScreen extends StatefulWidget {
  const AllTransactionsScreen({super.key});

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  String _filter = 'all';
  final List<DocumentSnapshot> _transactions = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  final int _limit = 20;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('transactions');

      if (_filter != 'all') {
        query = query.where('type', isEqualTo: _filter);
      }

      query = query.orderBy('date', descending: true).limit(_limit);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        setState(() => _hasMore = false);
      } else {
        setState(() {
          _lastDocument = snapshot.docs.last;
          _transactions.addAll(snapshot.docs);
        });
      }
    } on FirebaseException catch (e) {
      debugPrint('Firestore Error: ${e.code} - ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Firestore Error: ${e.message}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Create Index',
              textColor: Colors.white,
              onPressed: () {
                final url = e.message?.contains('https') == true
                    ? e.message!.split(' ').firstWhere((s) => s.startsWith('https'))
                    : null;
                if (url != null) {
                  debugPrint('Index URL: $url');
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetPagination() {
    setState(() {
      _transactions.clear();
      _lastDocument = null;
      _hasMore = true;
    });
    _loadMore();
  }

  void _changeFilter(String newFilter) {
    if (_filter == newFilter) return;
    setState(() => _filter = newFilter);
    _resetPagination();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'All Transactions',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16.w),
            child: PopupMenuButton<String>(
              initialValue: _filter,
              onSelected: _changeFilter,
              child: Chip(
                backgroundColor: _getFilterColor(_filter).withOpacity(0.1),
                side: BorderSide(color: _getFilterColor(_filter)),
                label: Text(
                  _filter.toUpperCase(),
                  style: TextStyle(
                    color: _getFilterColor(_filter),
                    fontWeight: FontWeight.w600,
                    fontSize: 12.sp,
                  ),
                ),
                avatar: Icon(
                  Icons.filter_list,
                  size: 16.sp,
                  color: _getFilterColor(_filter),
                ),
              ),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'all', child: Text('All')),
                const PopupMenuItem(value: 'income', child: Text('Income')),
                const PopupMenuItem(value: 'expense', child: Text('Expense')),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding:EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: Row(
              children: [
                _buildFilterChip('all', 'All'),
                SizedBox(width: 8.w),
                _buildFilterChip('income', 'Income'),
                SizedBox(width: 8.w),
                _buildFilterChip('expense', 'Expense'),
              ],
            ),
          ),
          Expanded(
            child: _transactions.isEmpty && !_isLoading
                ? _buildEmptyState()
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _transactions.length + (_hasMore && _isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _transactions.length) {
                  if (_hasMore && !_isLoading) {
                    _loadMore();
                  }
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final t = _transactions[index].data() as Map<String, dynamic>;
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
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _filter == value;
    final color = _getFilterColor(value);

    return ChoiceChip(
      selected: isSelected,
      onSelected: (_) => _changeFilter(value),
      selectedColor: color.withOpacity(0.15),
      backgroundColor: Colors.grey[100],
      side: BorderSide(
        color: isSelected ? color : Colors.grey[300]!,
      ),
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? color : Colors.grey[600],
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          fontSize: 13.sp,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80.sp, color: Colors.grey[300]),
          SizedBox(height: 16.h),
          Text(
            'No ${_filter == 'all' ? '' : _filter + ' '}transactions yet',
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
          ),
          SizedBox(height: 8.h),
          Text(
            'Add your first transaction!',
            style: TextStyle(fontSize: 14.sp, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }



  String _safeCategory(dynamic categoryData) {
    if (categoryData == null) return 'other';
    if (categoryData is String) return categoryData;
    if (categoryData is List && categoryData.isNotEmpty) {
      return categoryData.first.toString();
    }
    return 'other';
  }

  Color _getFilterColor(String filter) {
    switch (filter) {
      case 'income':
        return Colors.green;
      case 'expense':
        return Colors.red;
      case 'all':
      default:
        return Colors.blue;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'food':
        return Colors.orange;
      case 'shopping':
        return Colors.purple;
      case 'transport':
      case 'transportation':
        return Colors.blue;
      case 'bills':
        return Colors.red;
      case 'entertainment':
        return Colors.pink;
      case 'work':
      case 'freelance':
        return Colors.green;
      case 'transfer':
        return Colors.teal;
      case 'multiple':
        return Colors.indigo;
      case 'health':
        return Colors.cyan;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconForCategory(String category) {
    switch (category) {
      case 'food':
        return Icons.restaurant;
      case 'shopping':
        return Icons.shopping_bag;
      case 'transport':
      case 'transportation':
        return Icons.directions_bus;
      case 'bills':
        return Icons.receipt;
      case 'entertainment':
        return Icons.movie;
      case 'work':
      case 'freelance':
        return Icons.work_outline;
      case 'transfer':
        return Icons.person_outline;
      case 'multiple':
        return Icons.format_list_bulleted;
      case 'health':
        return Icons.health_and_safety;
      default:
        return Icons.attach_money;
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';
    if (date is Timestamp) {
      final dt = date.toDate();
      return DateFormat('MMM dd, yyyy - hh:mm a').format(dt);
    }
    return date.toString();
  }
}