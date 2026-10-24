import 'package:dompetku/data/dummy_transactions.dart';
import 'package:dompetku/data/financial_chart_data.dart';
import 'package:dompetku/data/monthly_financial_report.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FinancialChartData', () {
    final now = DateTime.utc(2026, 10, 10, 18);

    test('aggregates transactions from today and the previous six days', () {
      final result = FinancialChartData.fromTransactions(
        transactions: [
          _transaction(day: 10, amount: 150000, income: true),
          _transaction(day: 4, amount: 30000, income: false),
          _transaction(day: 3, amount: 90000, income: true),
        ],
        period: FinancialChartPeriod.last7Days,
        now: now,
      );

      expect(result.income, 150000);
      expect(result.expense, 30000);
      expect(result.difference, 120000);
      expect(result.transactionCount, 2);
      expect(result.buckets, hasLength(7));
      expect(result.buckets.first.label, '4/10');
      expect(result.buckets.last.label, '10/10');
      expect(result.buckets[0].expense, 30000);
      expect(result.buckets[6].income, 150000);
    });

    test('covers the whole current month and year, including later dates', () {
      final transactions = [
        _transaction(day: 1, amount: 100000, income: true),
        _transaction(day: 11, amount: 30000, income: true),
        _transaction(month: 9, day: 30, amount: 50000, income: false),
        _transaction(month: 1, day: 5, amount: 25000, income: false),
        _transaction(month: 12, day: 31, amount: 40000, income: true),
        _transaction(
          year: 2025,
          month: 12,
          day: 31,
          amount: 70000,
          income: true,
        ),
      ];

      final month = FinancialChartData.fromTransactions(
        transactions: transactions,
        period: FinancialChartPeriod.thisMonth,
        now: now,
      );
      final year = FinancialChartData.fromTransactions(
        transactions: transactions,
        period: FinancialChartPeriod.thisYear,
        now: now,
      );

      // Day 11 is after "today" (the 10th) but still in this month.
      expect(month.income, 130000);
      expect(month.expense, 0);
      expect(month.transactionCount, 2);
      expect(month.buckets, hasLength(31));
      expect(month.buckets.first.income, 100000);
      expect(month.buckets[10].income, 30000);
      // 31 December is later this year; 2025 stays out.
      expect(year.income, 170000);
      expect(year.expense, 75000);
      expect(year.difference, 95000);
      expect(year.buckets, hasLength(12));
      expect(year.buckets.first.expense, 25000);
      expect(year.buckets[8].expense, 50000);
      expect(year.buckets[11].income, 40000);
    });

    test('still ends the 7-day range today', () {
      final result = FinancialChartData.fromTransactions(
        transactions: [_transaction(day: 11, amount: 30000, income: true)],
        period: FinancialChartPeriod.last7Days,
        now: now,
      );

      expect(result.hasTransactions, isFalse);
    });

    test('this month matches the monthly report totals', () {
      final transactions = [
        _transaction(day: 1, amount: 100000, income: true),
        _transaction(day: 10, amount: 45000, income: false),
        _transaction(day: 28, amount: 250000, income: false),
        _transaction(day: 31, amount: 30000, income: true),
        _transaction(month: 9, day: 30, amount: 50000, income: false),
      ];

      final chart = FinancialChartData.fromTransactions(
        transactions: transactions,
        period: FinancialChartPeriod.thisMonth,
        now: now,
      );
      final report = MonthlyFinancialReport.fromTransactions(
        transactions: transactions,
        year: now.year,
        month: now.month,
      );

      expect(chart.income, report.income);
      expect(chart.expense, report.expense);
      expect(chart.difference, report.difference);
      expect(chart.transactionCount, report.transactionCount);
    });

    test('returns zero summaries and empty buckets without transactions', () {
      final result = FinancialChartData.fromTransactions(
        transactions: const [],
        period: FinancialChartPeriod.thisMonth,
        now: now,
      );

      expect(result.hasTransactions, isFalse);
      expect(result.income, 0);
      expect(result.expense, 0);
      expect(result.difference, 0);
      expect(result.buckets.every((bucket) => bucket.income == 0), isTrue);
      expect(result.buckets.every((bucket) => bucket.expense == 0), isTrue);
    });
  });
}

TransactionItem _transaction({
  int year = 2026,
  int month = 10,
  required int day,
  required int amount,
  required bool income,
}) => TransactionItem(
  id: day,
  category: income ? 'Gaji' : 'Makanan',
  amount: amount,
  date: DateTime.utc(year, month, day, 12),
  isIncome: income,
  icon: income ? Icons.savings : Icons.restaurant,
);
