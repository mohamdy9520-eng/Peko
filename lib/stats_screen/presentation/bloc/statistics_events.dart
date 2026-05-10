import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';



abstract class StatisticsEvent {}

class LoadStatistics extends StatisticsEvent {
  final int filterIndex;
  final String type;

  LoadStatistics({this.filterIndex = 2, this.type = 'expense'});
}

class StatisticsUpdated extends StatisticsEvent {
  final List<Map<String, dynamic>> transactions;
  StatisticsUpdated(this.transactions);
}

class ChangeFilter extends StatisticsEvent {
  final int filterIndex;
  ChangeFilter(this.filterIndex);
}

class ChangeType extends StatisticsEvent {
  final String type;
  ChangeType(this.type);
}



abstract class StatisticsState {}

class StatisticsInitial extends StatisticsState {}

class StatisticsLoading extends StatisticsState {}

class StatisticsLoaded extends StatisticsState {
  final List<Map<String, dynamic>> allTransactions;
  final List<Map<String, dynamic>> filteredTransactions;
  final Map<String, double> pieData;
  final Map<String, double> barData;
  final Map<String, double> lineData;
  final Map<String, dynamic> summary;
  final String topInsight;
  final int filterIndex;
  final String selectedType;
  final List<String> filters;

  StatisticsLoaded({
    required this.allTransactions,
    required this.filteredTransactions,
    required this.pieData,
    required this.barData,
    required this.lineData,
    required this.summary,
    required this.topInsight,
    required this.filterIndex,
    required this.selectedType,
    this.filters = const ['Day', 'Week', 'Month', 'Year'],
  });
}

class StatisticsError extends StatisticsState {
  final String message;
  StatisticsError(this.message);
}



class StatisticsBloc extends Bloc<StatisticsEvent, StatisticsState> {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  StreamSubscription<QuerySnapshot>? _transactionsSubscription;

  final List<String> _filters = ['Day', 'Week', 'Month', 'Year'];
  int _currentFilterIndex = 2;
  String _currentType = 'expense';

  StatisticsBloc({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        super(StatisticsInitial()) {
    on<LoadStatistics>(_onLoad);
    on<StatisticsUpdated>(_onUpdated);
    on<ChangeFilter>(_onChangeFilter);
    on<ChangeType>(_onChangeType);
  }



  Future<void> _onLoad(LoadStatistics event, Emitter<StatisticsState> emit) async {
    emit(StatisticsLoading());

    _currentFilterIndex = event.filterIndex;
    _currentType = event.type;

    await _transactionsSubscription?.cancel();

    final user = _auth.currentUser;
    if (user == null) {
      emit(StatisticsError('User not authenticated'));
      return;
    }

    final startDate = _getStartDate(_currentFilterIndex);

    _transactionsSubscription = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('transactions')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .orderBy('date', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
        final transactions = snapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
        add(StatisticsUpdated(transactions));
      },
      onError: (error) => emit(StatisticsError(error.toString())),
    );
  }

  void _onUpdated(StatisticsUpdated event, Emitter<StatisticsState> emit) {
    final all = event.transactions;
    final filtered = all.where((t) => t['type'] == _currentType).toList();

    emit(StatisticsLoaded(
      allTransactions: all,
      filteredTransactions: filtered,
      pieData: _calculatePieData(filtered),
      barData: _calculateBarData(filtered),
      lineData: _calculateLineData(filtered),
      summary: _calculateSummary(all),
      topInsight: _generateInsight(all),
      filterIndex: _currentFilterIndex,
      selectedType: _currentType,
      filters: _filters,
    ));
  }

  void _onChangeFilter(ChangeFilter event, Emitter<StatisticsState> emit) {
    _currentFilterIndex = event.filterIndex;
    add(LoadStatistics(filterIndex: _currentFilterIndex, type: _currentType));
  }

  void _onChangeType(ChangeType event, Emitter<StatisticsState> emit) {
    _currentType = event.type;
    add(LoadStatistics(filterIndex: _currentFilterIndex, type: _currentType));
  }



  DateTime _getStartDate(int filterIndex) {
    final now = DateTime.now();
    switch (_filters[filterIndex]) {
      case 'Day':
        return DateTime(now.year, now.month, now.day);
      case 'Week':
        return now.subtract(Duration(days: now.weekday - 1));
      case 'Year':
        return DateTime(now.year, 1, 1);
      case 'Month':
      default:
        return DateTime(now.year, now.month, 1);
    }
  }



  Map<String, double> _calculatePieData(List<Map<String, dynamic>> transactions) {
    final Map<String, double> categoryData = {};
    for (final t in transactions) {
      final cat = t['category']?.toString() ?? 'other';
      final amount = (t['amount'] ?? 0).toDouble();
      categoryData[cat] = (categoryData[cat] ?? 0) + amount;
    }
    return categoryData;
  }

  Map<String, double> _calculateBarData(List<Map<String, dynamic>> transactions) {
    final Map<String, double> categoryData = {};
    for (final t in transactions) {
      final cat = t['category']?.toString() ?? 'other';
      final amount = (t['amount'] ?? 0).toDouble();
      categoryData[cat] = (categoryData[cat] ?? 0) + amount;
    }
    final sorted = Map.fromEntries(
      categoryData.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
    return sorted;
  }

  Map<String, double> _calculateLineData(List<Map<String, dynamic>> transactions) {
    final Map<String, double> dailyData = {};
    for (final t in transactions) {
      final date = (t['date'] as Timestamp?)?.toDate();
      if (date == null) continue;
      final key = DateFormat('MM/dd').format(date);
      dailyData[key] = (dailyData[key] ?? 0) + (t['amount'] ?? 0).toDouble();
    }
    final sortedKeys = dailyData.keys.toList()..sort();
    return {for (final k in sortedKeys) k: dailyData[k]!};
  }

  Map<String, dynamic> _calculateSummary(List<Map<String, dynamic>> transactions) {
    double totalIncome = 0;
    double totalExpense = 0;
    int count = transactions.length;

    for (final t in transactions) {
      final amount = (t['amount'] ?? 0).toDouble();
      if (t['type'] == 'income') {
        totalIncome += amount;
      } else {
        totalExpense += amount;
      }
    }

    return {
      'totalIncome': totalIncome,
      'totalExpense': totalExpense,
      'net': totalIncome - totalExpense,
      'count': count,
    };
  }

  String _generateInsight(List<Map<String, dynamic>> transactions) {
    final Map<String, double> categoryTotals = {};
    for (final t in transactions) {
      if (t['type'] == 'expense') {
        final cat = t['category']?.toString() ?? 'other';
        final amount = (t['amount'] ?? 0).toDouble();
        categoryTotals[cat] = (categoryTotals[cat] ?? 0) + amount;
      }
    }

    if (categoryTotals.isEmpty) return 'No expense data yet';

    final topCategory = categoryTotals.entries
        .reduce((a, b) => a.value > b.value ? a : b);

    return 'You spent most on ${topCategory.key.toUpperCase()} (\$${topCategory.value.toStringAsFixed(0)})';
  }



  @override
  Future<void> close() {
    _transactionsSubscription?.cancel();
    return super.close();
  }
}