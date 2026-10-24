import 'package:dompetku/data/dummy_transactions.dart';
import 'package:dompetku/data/user_profile.dart';
import 'package:dompetku/services/app_clock.dart';
import 'package:dompetku/screens/transactions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('date and category filters wrap without overlapping', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(616, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = TransactionStore(initialTransactions: []);
    await tester.pumpWidget(_screen(store));

    final allDatesRect = tester.getRect(
      find.byKey(const ValueKey('transaction-date-allDates')),
    );
    final categoryRect = tester.getRect(
      find.byKey(const ValueKey('transaction-category-filter')),
    );

    expect(allDatesRect.overlaps(categoryRect), isFalse);
    expect(allDatesRect.right, lessThanOrEqualTo(594));
    expect(categoryRect.right, lessThanOrEqualTo(594));

    store.dispose();
  });

  testWidgets('search filters transactions and reset restores full results', (
    WidgetTester tester,
  ) async {
    final store = TransactionStore(
      initialTransactions: [
        _transaction(category: 'Makanan', note: 'Makan siang', income: false),
        _transaction(category: 'Gaji', note: 'Gaji bulanan', income: true),
      ],
    );
    await tester.pumpWidget(_screen(store));

    expect(find.text('2 transaksi ditemukan'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('transaction-search')),
      'bulanan',
    );
    await tester.pumpAndSettle();
    expect(find.text('1 transaksi ditemukan'), findsOneWidget);
    expect(find.text('Gaji bulanan'), findsOneWidget);
    expect(find.text('Makan siang'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('transaction-reset-filters')));
    await tester.pumpAndSettle();
    expect(find.text('2 transaksi ditemukan'), findsOneWidget);
    expect(find.text('Gaji bulanan'), findsOneWidget);
    expect(find.text('Makan siang'), findsOneWidget);

    store.dispose();
  });

  testWidgets('shows category with absolute date and time', (
    WidgetTester tester,
  ) async {
    final store = TransactionStore(
      initialTransactions: [
        _transaction(
          category: 'Gaji',
          note: '',
          income: true,
          date: DateTime.utc(2026, 10, 7),
        ),
      ],
    );
    await tester.pumpWidget(_screen(store));

    expect(find.text('Gaji · 7 Okt 2026, 00:00'), findsOneWidget);

    store.dispose();
  });

  testWidgets('shows no-match and no-transactions empty states', (
    WidgetTester tester,
  ) async {
    final store = TransactionStore(
      initialTransactions: [
        _transaction(category: 'Makanan', note: 'Makan siang', income: false),
      ],
    );
    await tester.pumpWidget(_screen(store));

    await tester.enterText(
      find.byKey(const ValueKey('transaction-search')),
      'tidak ada',
    );
    await tester.pumpAndSettle();
    expect(find.text('0 transaksi ditemukan'), findsOneWidget);
    expect(
      find.text('Tidak ada transaksi yang cocok dengan filter.'),
      findsOneWidget,
    );

    store.replaceAll([]);
    await tester.pumpAndSettle();
    expect(find.text('Belum ada transaksi'), findsOneWidget);

    store.dispose();
  });

  testWidgets('type and category controls combine and reset together', (
    WidgetTester tester,
  ) async {
    final store = TransactionStore(
      initialTransactions: [
        _transaction(category: 'Makanan', note: 'Makan siang', income: false),
        _transaction(category: 'Gaji', note: 'Gaji bulanan', income: true),
      ],
    );
    await tester.pumpWidget(_screen(store));

    await tester.tap(find.byKey(const ValueKey('transaction-type-income')));
    await tester.pumpAndSettle();
    expect(find.text('1 transaksi ditemukan'), findsOneWidget);
    expect(find.text('Gaji bulanan'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('transaction-category-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gaji').last);
    await tester.pumpAndSettle();
    expect(find.text('1 transaksi ditemukan'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('transaction-reset-filters')));
    await tester.pumpAndSettle();
    expect(find.text('2 transaksi ditemukan'), findsOneWidget);
    expect(find.text('Kategori'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const ValueKey('transaction-type-all')),
          )
          .selected,
      isTrue,
    );

    store.dispose();
  });

  testWidgets('filtered results react to transaction add edit and delete', (
    WidgetTester tester,
  ) async {
    final store = TransactionStore(
      initialTransactions: [
        _transaction(category: 'Makanan', note: 'Makan siang', income: false),
      ],
    );
    await tester.pumpWidget(_screen(store));

    await tester.enterText(
      find.byKey(const ValueKey('transaction-search')),
      'makan',
    );
    await tester.pumpAndSettle();
    expect(find.text('1 transaksi ditemukan'), findsOneWidget);

    store.add(
      _transaction(category: 'Makanan', note: 'Makan malam', income: false),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 transaksi ditemukan'), findsOneWidget);

    store.updateAt(
      0,
      _transaction(category: 'Camilan', note: 'Biskuit', income: false),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 transaksi ditemukan'), findsOneWidget);
    expect(find.text('Makan siang'), findsOneWidget);
    expect(find.text('Makan malam'), findsNothing);
    expect(find.text('Biskuit'), findsNothing);

    store.removeAt(1);
    await tester.pumpAndSettle();
    expect(find.text('0 transaksi ditemukan'), findsOneWidget);
    expect(
      find.text('Tidak ada transaksi yang cocok dengan filter.'),
      findsOneWidget,
    );

    store.dispose();
  });
}

Widget _screen(TransactionStore store) => MaterialApp(
  home: Scaffold(
    body: TransactionsScreen(
      store: store,
      profile: const UserProfile(name: 'User', email: 'user@example.com'),
      isLoading: false,
      errorMessage: null,
      onRefresh: () async {},
      onProfileTap: () {},
      onEditTransaction: (_) {},
      onDeleteTransaction: (_) async {},
    ),
  ),
);

TransactionItem _transaction({
  required String category,
  required String note,
  required bool income,
  DateTime? date,
}) => TransactionItem(
  id: 1,
  category: category,
  amount: 10000,
  date: date ?? AppClock.now(),
  isIncome: income,
  icon: income ? Icons.savings : Icons.restaurant,
  note: note,
);
