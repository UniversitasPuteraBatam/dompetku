import '../services/app_clock.dart';
import 'dummy_transactions.dart';

enum TransactionTypeFilter { all, income, expense }

enum TransactionDateFilter { today, last7Days, thisMonth, allDates }

extension TransactionTypeFilterLabel on TransactionTypeFilter {
  String get label => switch (this) {
    TransactionTypeFilter.all => 'Semua',
    TransactionTypeFilter.income => 'Pemasukan',
    TransactionTypeFilter.expense => 'Pengeluaran',
  };
}

extension TransactionDateFilterLabel on TransactionDateFilter {
  String get label => switch (this) {
    TransactionDateFilter.today => 'Hari Ini',
    TransactionDateFilter.last7Days => '7 Hari Terakhir',
    TransactionDateFilter.thisMonth => 'Bulan Ini',
    TransactionDateFilter.allDates => 'Semua Tanggal',
  };
}

class IndexedTransaction {
  const IndexedTransaction({required this.index, required this.transaction});

  final int index;
  final TransactionItem transaction;
}

class TransactionFilter {
  const TransactionFilter({
    this.query = '',
    this.type = TransactionTypeFilter.all,
    this.category,
    this.date = TransactionDateFilter.allDates,
  });

  final String query;
  final TransactionTypeFilter type;
  final String? category;
  final TransactionDateFilter date;

  bool get isDefault =>
      query.trim().isEmpty &&
      type == TransactionTypeFilter.all &&
      category == null &&
      date == TransactionDateFilter.allDates;

  TransactionFilter copyWith({
    String? query,
    TransactionTypeFilter? type,
    String? category,
    bool clearCategory = false,
    TransactionDateFilter? date,
  }) => TransactionFilter(
    query: query ?? this.query,
    type: type ?? this.type,
    category: clearCategory ? null : category ?? this.category,
    date: date ?? this.date,
  );

  List<IndexedTransaction> apply({
    required List<TransactionItem> transactions,
    required DateTime now,
  }) {
    final today = AppClock.calendarDate(AppClock.dateString(now));
    final firstDate = switch (date) {
      TransactionDateFilter.today => today,
      TransactionDateFilter.last7Days => today.subtract(
        const Duration(days: 6),
      ),
      TransactionDateFilter.thisMonth => DateTime.utc(today.year, today.month),
      TransactionDateFilter.allDates => null,
    };
    final normalizedQuery = query.trim().toLowerCase();
    final results = <IndexedTransaction>[];

    for (var index = 0; index < transactions.length; index++) {
      final transaction = transactions[index];
      if (type == TransactionTypeFilter.income && !transaction.isIncome) {
        continue;
      }
      if (type == TransactionTypeFilter.expense && transaction.isIncome) {
        continue;
      }
      if (category != null && transaction.category != category) continue;

      if (normalizedQuery.isNotEmpty &&
          !transaction.category.toLowerCase().contains(normalizedQuery) &&
          !transaction.note.toLowerCase().contains(normalizedQuery)) {
        continue;
      }

      if (firstDate != null) {
        final transactionDate = DateTime.utc(
          transaction.date.year,
          transaction.date.month,
          transaction.date.day,
        );
        if (transactionDate.isBefore(firstDate) ||
            transactionDate.isAfter(today)) {
          continue;
        }
      }

      results.add(IndexedTransaction(index: index, transaction: transaction));
    }

    return List.unmodifiable(results);
  }
}
