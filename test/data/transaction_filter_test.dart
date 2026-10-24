import 'package:dompetku/data/dummy_transactions.dart';
import 'package:dompetku/data/transaction_filter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TransactionFilter', () {
    final now = DateTime.utc(2026, 10, 10, 12);
    final transactions = [
      _transaction(
        category: 'Makanan',
        note: 'Makan siang',
        day: 10,
        income: false,
      ),
      _transaction(
        category: 'Gaji',
        note: 'Gaji bulanan',
        day: 8,
        income: true,
      ),
      _transaction(
        category: 'Freelance',
        note: 'Desain proyek',
        day: 5,
        income: true,
      ),
      _transaction(
        category: 'Belanja',
        note: 'Belanja rumah',
        day: 3,
        income: false,
      ),
      _transaction(
        category: 'Transportasi',
        note: 'Tiket lama',
        day: 30,
        month: 9,
        income: false,
      ),
    ];

    test('searches category and description case-insensitively', () {
      final categoryResults = const TransactionFilter(
        query: 'mAkAn',
      ).apply(transactions: transactions, now: now);
      final descriptionResults = const TransactionFilter(
        query: 'PROYEK',
      ).apply(transactions: transactions, now: now);

      expect(categoryResults.map((entry) => entry.transaction.category), [
        'Makanan',
      ]);
      expect(descriptionResults.map((entry) => entry.transaction.note), [
        'Desain proyek',
      ]);
    });

    test('filters income and expense transaction types', () {
      final incomeResults = const TransactionFilter(
        type: TransactionTypeFilter.income,
      ).apply(transactions: transactions, now: now);
      final expenseResults = const TransactionFilter(
        type: TransactionTypeFilter.expense,
      ).apply(transactions: transactions, now: now);

      expect(incomeResults.map((entry) => entry.transaction.category), [
        'Gaji',
        'Freelance',
      ]);
      expect(expenseResults, hasLength(3));
      expect(
        expenseResults.every((entry) => !entry.transaction.isIncome),
        isTrue,
      );
    });

    test(
      'filters exact category and date periods using Jakarta calendar days',
      () {
        final categoryResults = const TransactionFilter(
          category: 'Gaji',
        ).apply(transactions: transactions, now: now);
        final todayResults = const TransactionFilter(
          date: TransactionDateFilter.today,
        ).apply(transactions: transactions, now: now);
        final last7Results = const TransactionFilter(
          date: TransactionDateFilter.last7Days,
        ).apply(transactions: transactions, now: now);
        final monthResults = const TransactionFilter(
          date: TransactionDateFilter.thisMonth,
        ).apply(transactions: transactions, now: now);
        final allResults = const TransactionFilter(
          date: TransactionDateFilter.allDates,
        ).apply(transactions: transactions, now: now);

        expect(categoryResults.single.transaction.category, 'Gaji');
        expect(todayResults.map((entry) => entry.transaction.category), [
          'Makanan',
        ]);
        expect(last7Results, hasLength(3));
        expect(monthResults, hasLength(4));
        expect(allResults, hasLength(5));
      },
    );

    test('combines query, type, category, and date filters', () {
      final result = const TransactionFilter(
        query: 'makan',
        type: TransactionTypeFilter.expense,
        category: 'Makanan',
        date: TransactionDateFilter.last7Days,
      ).apply(transactions: transactions, now: now);

      expect(result, hasLength(1));
      expect(result.single.index, 0);
    });

    test(
      'returns original store indices for filtered edit and delete actions',
      () {
        final result = const TransactionFilter(
          type: TransactionTypeFilter.income,
        ).apply(transactions: transactions, now: now);

        expect(result.map((entry) => entry.index), [1, 2]);
      },
    );

    test(
      'reflects store additions, updates, and removals on each application',
      () {
        final store = TransactionStore(initialTransactions: transactions);
        const filter = TransactionFilter(query: 'bonus');
        final bonus = _transaction(
          category: 'Bonus',
          note: 'Bonus tahunan',
          day: 10,
          income: true,
        );

        expect(
          filter.apply(transactions: store.transactions, now: now),
          isEmpty,
        );
        store.add(bonus);
        expect(
          filter
              .apply(transactions: store.transactions, now: now)
              .single
              .transaction
              .category,
          'Bonus',
        );
        store.updateAt(
          0,
          _transaction(
            category: 'Premi',
            note: 'Insentif',
            day: 10,
            income: true,
          ),
        );
        expect(
          filter.apply(transactions: store.transactions, now: now),
          isEmpty,
        );
        store.removeAt(0);
        expect(
          filter.apply(transactions: store.transactions, now: now),
          isEmpty,
        );
        store.dispose();
      },
    );
  });
}

TransactionItem _transaction({
  required String category,
  required String note,
  required int day,
  required bool income,
  int month = 10,
  int year = 2026,
}) => TransactionItem(
  id: day,
  category: category,
  amount: 10000,
  date: DateTime.utc(year, month, day, 16),
  isIncome: income,
  icon: income ? Icons.savings : Icons.receipt,
  note: note,
);
