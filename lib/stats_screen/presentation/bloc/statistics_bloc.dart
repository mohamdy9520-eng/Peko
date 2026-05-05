import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../features/home/domain/repostories/transaction_repository.dart';

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
  final TransactionRepository _repository;
  StreamSubscription<QuerySnapshot>? _subscription;

  final List<String> _filters = ['Day', 'Week', 'Month', 'Year'];
  int _currentFilterIndex = 2;
  String _currentType = 'expense';

  StatisticsBloc(this._repository) : super(StatisticsInitial()) {
    on<LoadStatistics>(_onLoad);
    on<StatisticsUpdated>(_onUpdated);
    on<ChangeFilter>(_onChangeFilter);
    on<ChangeType>(_onChangeType);
  }

  Future<void> _onLoad(LoadStatistics event, Emitter emit) async {
    emit(StatisticsLoading());
    _currentFilterIndex = event.filterIndex;
    _currentType = event.type;

    await _subscription?.cancel();

    final startDate = _getStartDate(_currentFilterIndex);
    _subscription = _repository.getTransactionsByDate(startDate).listen(
          (snapshot) {
        final transactions = snapshot.docs.map((d) => d.data() as Map<String, dynamic>).toList();
        add(StatisticsUpdated(transactions));
      },
      onError: (e) => emit(StatisticsError(e.toString())),
    );
  }

  void _onUpdated(StatisticsUpdated event, Emitter emit) {
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

  void _onChangeFilter(ChangeFilter event, Emitter emit) {
    _currentFilterIndex = event.filterIndex;
    add(LoadStatistics(filterIndex: _currentFilterIndex, type: _currentType));
  }

  void _onChangeType(ChangeType event, Emitter emit) {
    _currentType = event.type;
    add(LoadStatistics(filterIndex: _currentFilterIndex, type: _currentType));
  }

  DateTime _getStartDate(int index) {
    final now = DateTime.now();
    switch (_filters[index]) {
      case 'Day': return DateTime(now.year, now.month, now.day);
      case 'Week': return now.subtract(Duration(days: now.weekday - 1));
      case 'Year': return DateTime(now.year, 1, 1);
      default: return DateTime(now.year, now.month, 1);
    }
  }

  Map<String, double> _calculatePieData(List<Map<String, dynamic>> list) {
    final map = <String, double>{};
    for (final t in list) {
      final cat = t['category']?.toString() ?? 'other';
      map[cat] = (map[cat] ?? 0) + (t['amount'] ?? 0).toDouble();
    }
    return map;
  }

  Map<String, double> _calculateBarData(List<Map<String, dynamic>> list) {
    final map = _calculatePieData(list);
    final sorted = Map.fromEntries(map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
    return sorted;
  }

  Map<String, double> _calculateLineData(List<Map<String, dynamic>> list) {
    final map = <String, double>{};
    for (final t in list) {
      final date = (t['date'] as Timestamp?)?.toDate();
      if (date == null) continue;
      final key = DateFormat('MM/dd').format(date);
      map[key] = (map[key] ?? 0) + (t['amount'] ?? 0).toDouble();
    }
    final sorted = map.keys.toList()..sort();
    return {for (final k in sorted) k: map[k]!};
  }

  Map<String, dynamic> _calculateSummary(List<Map<String, dynamic>> list) {
    double income = 0, expense = 0;
    for (final t in list) {
      final amount = (t['amount'] ?? 0).toDouble();
      if (t['type'] == 'income') income += amount; else expense += amount;
    }
    return {
      'totalIncome': income,
      'totalExpense': expense,
      'net': income - expense,
      'count': list.length,
    };
  }

  String _generateInsight(List<Map<String, dynamic>> list) {
    final totals = <String, double>{};
    for (final t in list) {
      if (t['type'] == 'expense') {
        final cat = t['category']?.toString() ?? 'other';
        totals[cat] = (totals[cat] ?? 0) + (t['amount'] ?? 0).toDouble();
      }
    }
    if (totals.isEmpty) return 'No expense data yet';
    final top = totals.entries.reduce((a, b) => a.value > b.value ? a : b);
    return 'You spent most on ${top.key.toUpperCase()} (\$${top.value.toStringAsFixed(0)})';
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}