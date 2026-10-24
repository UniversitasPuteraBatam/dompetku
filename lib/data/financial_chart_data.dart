import 'dummy_transactions.dart';
import 'month_names.dart';

enum FinancialChartPeriod { last7Days, thisMonth, thisYear }

extension FinancialChartPeriodLabel on FinancialChartPeriod {
  String get label => switch (this) {
    FinancialChartPeriod.last7Days => '7 Hari',
    FinancialChartPeriod.thisMonth => 'Bulan Ini',
    FinancialChartPeriod.thisYear => 'Tahun Ini',
  };
}

class FinancialChartBucket {
  const FinancialChartBucket({
    required this.label,
    required this.income,
    required this.expense,
  });

  final String label;
  final int income;
  final int expense;
}

class FinancialChartData {
  const FinancialChartData({
    required this.period,
    required this.income,
    required this.expense,
    required this.transactionCount,
    required this.buckets,
  });

  final FinancialChartPeriod period;
  final int income;
  final int expense;
  final int transactionCount;
  final List<FinancialChartBucket> buckets;

  int get difference => income - expense;
  bool get hasTransactions => transactionCount > 0;

  factory FinancialChartData.fromTransactions({
    required List<TransactionItem> transactions,
    required FinancialChartPeriod period,
    required DateTime now,
  }) {
    final today = DateTime.utc(now.year, now.month, now.day);
    final firstDay = switch (period) {
      FinancialChartPeriod.last7Days => today.subtract(const Duration(days: 6)),
      FinancialChartPeriod.thisMonth => DateTime.utc(today.year, today.month),
      FinancialChartPeriod.thisYear => DateTime.utc(today.year),
    };
    // "Bulan Ini" and "Tahun Ini" cover the whole calendar month/year, the same
    // range as the monthly report, so transactions dated later this month or
    // year are counted too.
    final lastDay = switch (period) {
      FinancialChartPeriod.last7Days => today,
      FinancialChartPeriod.thisMonth => DateTime.utc(
        today.year,
        today.month + 1,
        0,
      ),
      FinancialChartPeriod.thisYear => DateTime.utc(today.year, 12, 31),
    };

    final buckets = switch (period) {
      FinancialChartPeriod.last7Days => List<FinancialChartBucket>.generate(7, (
        index,
      ) {
        final date = firstDay.add(Duration(days: index));
        return FinancialChartBucket(
          label: '${date.day}/${date.month}',
          income: 0,
          expense: 0,
        );
      }),
      FinancialChartPeriod.thisMonth => List<FinancialChartBucket>.generate(
        DateTime.utc(today.year, today.month + 1, 0).day,
        (index) =>
            FinancialChartBucket(label: '${index + 1}', income: 0, expense: 0),
      ),
      FinancialChartPeriod.thisYear => List<FinancialChartBucket>.generate(
        12,
        (index) => FinancialChartBucket(
          label: shortMonthNames[index],
          income: 0,
          expense: 0,
        ),
      ),
    };

    var income = 0;
    var expense = 0;
    var transactionCount = 0;
    for (final transaction in transactions) {
      final date = DateTime.utc(
        transaction.date.year,
        transaction.date.month,
        transaction.date.day,
      );
      if (date.isBefore(firstDay) || date.isAfter(lastDay)) continue;

      final bucketIndex = switch (period) {
        FinancialChartPeriod.last7Days => date.difference(firstDay).inDays,
        FinancialChartPeriod.thisMonth => date.day - 1,
        FinancialChartPeriod.thisYear => date.month - 1,
      };
      final bucket = buckets[bucketIndex];
      transactionCount++;
      if (transaction.isIncome) {
        income += transaction.amount;
        buckets[bucketIndex] = FinancialChartBucket(
          label: bucket.label,
          income: bucket.income + transaction.amount,
          expense: bucket.expense,
        );
      } else {
        expense += transaction.amount;
        buckets[bucketIndex] = FinancialChartBucket(
          label: bucket.label,
          income: bucket.income,
          expense: bucket.expense + transaction.amount,
        );
      }
    }

    return FinancialChartData(
      period: period,
      income: income,
      expense: expense,
      transactionCount: transactionCount,
      buckets: List.unmodifiable(buckets),
    );
  }
}
