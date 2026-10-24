import 'package:dompetku/data/dummy_transactions.dart';
import 'package:dompetku/data/monthly_financial_report.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MonthlyFinancialReport', () {
    test('calculates monthly income, expense, difference, and count', () {
      final report = MonthlyFinancialReport.fromTransactions(
        transactions: [
          _transaction(2026, 10, 1, 250000, true, 'Gaji'),
          _transaction(2026, 10, 10, 90000, false, 'Makanan'),
          _transaction(2026, 10, 12, 40000, false, 'Transportasi'),
          _transaction(2026, 9, 30, 500000, true, 'Bonus'),
          _transaction(2025, 10, 1, 150000, false, 'Belanja'),
        ],
        year: 2026,
        month: 10,
      );

      expect(report.income, 250000);
      expect(report.expense, 130000);
      expect(report.difference, 120000);
      expect(report.transactionCount, 3);
      expect(
        report.transactions.every((item) => item.date.year == 2026),
        isTrue,
      );
      expect(
        report.transactions.every((item) => item.date.month == 10),
        isTrue,
      );
    });

    test('groups expenses by category and orders the largest first', () {
      final report = MonthlyFinancialReport.fromTransactions(
        transactions: [
          _transaction(2026, 10, 2, 30000, false, 'Makanan'),
          _transaction(2026, 10, 8, 40000, false, 'Makanan'),
          _transaction(2026, 10, 12, 100000, false, 'Belanja'),
          _transaction(2026, 10, 15, 900000, true, 'Gaji'),
        ],
        year: 2026,
        month: 10,
      );

      expect(
        report.expensesByCategory
            .map((item) => (item.category, item.amount))
            .toList(),
        [('Belanja', 100000), ('Makanan', 70000)],
      );
      expect(report.largestExpenseCategory, 'Belanja');
    });

    test('includes the first day and excludes the next month boundary', () {
      final report = MonthlyFinancialReport.fromTransactions(
        transactions: [
          _transaction(2026, 10, 1, 10000, true, 'Gaji'),
          _transaction(2026, 10, 31, 20000, false, 'Tagihan'),
          _transaction(2026, 11, 1, 30000, false, 'Makanan'),
        ],
        year: 2026,
        month: 10,
      );

      expect(report.transactionCount, 2);
      expect(report.income, 10000);
      expect(report.expense, 20000);
    });

    test(
      'returns zero totals, no categories, and no false account balances',
      () {
        final report = MonthlyFinancialReport.fromTransactions(
          transactions: [_transaction(2026, 9, 30, 50000, true, 'Bonus')],
          year: 2026,
          month: 10,
        );

        expect(report.hasTransactions, isFalse);
        expect(report.income, 0);
        expect(report.expense, 0);
        expect(report.difference, 0);
        expect(report.expensesByCategory, isEmpty);
        expect(report.largestExpenseCategory, isNull);
        expect(report.openingBalance, isNull);
        expect(report.closingBalance, isNull);
      },
    );

    test(
      'reflects store additions, edits, and deletions for a chosen month',
      () {
        final store = TransactionStore(initialTransactions: []);

        MonthlyFinancialReport reportFromStore() =>
            MonthlyFinancialReport.fromTransactions(
              transactions: store.transactions,
              year: 2026,
              month: 10,
            );

        expect(reportFromStore().income, 0);
        store.add(_transaction(2026, 10, 3, 50000, true, 'Gaji'));
        expect(reportFromStore().income, 50000);

        store.updateAt(0, _transaction(2026, 10, 3, 20000, false, 'Makanan'));
        expect(reportFromStore().income, 0);
        expect(reportFromStore().expense, 20000);

        store.removeAt(0);
        expect(reportFromStore().transactionCount, 0);
        store.dispose();
      },
    );
  });
}

TransactionItem _transaction(
  int year,
  int month,
  int day,
  int amount,
  bool income,
  String category,
) => TransactionItem(
  id: day,
  category: category,
  amount: amount,
  date: DateTime.utc(year, month, day, 12),
  isIncome: income,
  icon: income ? Icons.savings : Icons.receipt,
);
