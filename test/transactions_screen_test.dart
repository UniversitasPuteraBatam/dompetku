import 'package:dompetku/data/dummy_transactions.dart';
import 'package:dompetku/services/app_clock.dart';
import 'package:dompetku/screens/transactions_screen.dart';
import 'package:dompetku/widgets/profile_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('search and filter share one row and leave room for the list', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2220);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = TransactionStore(
      initialTransactions: [
        _transaction(category: 'Makanan', note: 'Makan siang', income: false),
      ],
    );
    await tester.pumpWidget(_screen(store));

    final search = tester.getRect(
      find.byKey(const ValueKey('transaction-search')),
    );
    final filter = tester.getRect(
      find.byKey(const ValueKey('transaction-filter-button')),
    );
    expect(filter.center.dy, closeTo(search.center.dy, 4));
    expect(filter.right, lessThanOrEqualTo(360 - 22));
    // The profile photo is only shown on Home and Profile.
    expect(find.byType(ProfileAvatar), findsNothing);
    expect(
      find.byKey(const ValueKey('transaction-active-filters')),
      findsNothing,
    );
    // The list starts in the upper third instead of halfway down the screen.
    final list = find.byWidgetPredicate(
      (widget) => widget is ListView && widget.scrollDirection == Axis.vertical,
    );
    expect(tester.getRect(list).top, lessThan(740 / 3));

    store.dispose();
  });

  testWidgets('search filters transactions and clearing it restores results', (
    WidgetTester tester,
  ) async {
    final store = TransactionStore(
      initialTransactions: [
        _transaction(category: 'Makanan', note: 'Makan siang', income: false),
        _transaction(category: 'Gaji', note: 'Gaji bulanan', income: true),
      ],
    );
    await tester.pumpWidget(_screen(store));

    expect(find.text('2 transaksi'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('transaction-search')),
      'bulanan',
    );
    await tester.pumpAndSettle();
    expect(find.text('1 transaksi'), findsOneWidget);
    expect(find.text('Gaji bulanan'), findsOneWidget);
    expect(find.text('Makan siang'), findsNothing);

    await tester.tap(find.byTooltip('Hapus pencarian'));
    await tester.pumpAndSettle();
    expect(find.text('2 transaksi'), findsOneWidget);
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
    expect(find.text('0 transaksi'), findsOneWidget);
    expect(
      find.text('Tidak ada transaksi yang cocok dengan filter.'),
      findsOneWidget,
    );

    store.replaceAll([]);
    await tester.pumpAndSettle();
    expect(find.text('Belum ada transaksi'), findsOneWidget);

    store.dispose();
  });

  testWidgets('filter sheet combines type and category, chips remove them', (
    WidgetTester tester,
  ) async {
    final store = TransactionStore(
      initialTransactions: [
        _transaction(category: 'Makanan', note: 'Makan siang', income: false),
        _transaction(category: 'Gaji', note: 'Gaji bulanan', income: true),
        _transaction(category: 'Bonus', note: 'Bonus proyek', income: true),
      ],
    );
    await tester.pumpWidget(_screen(store));

    await tester.tap(find.byKey(const ValueKey('transaction-filter-button')));
    await tester.pumpAndSettle();
    expect(find.text('Filter transaksi'), findsOneWidget);
    expect(find.text('Tampilkan 3 transaksi'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('filter-type-income')));
    await tester.pumpAndSettle();
    expect(find.text('Tampilkan 2 transaksi'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('filter-category-Gaji')));
    await tester.pumpAndSettle();
    expect(find.text('Tampilkan 1 transaksi'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('filter-sheet-apply')));
    await tester.pumpAndSettle();

    expect(find.text('1 transaksi'), findsOneWidget);
    expect(find.text('Gaji bulanan'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(Badge), matching: find.text('2')),
      findsOneWidget,
    );
    expect(find.widgetWithText(InputChip, 'Pemasukan'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'Gaji'), findsOneWidget);

    await tester.tap(find.byTooltip('Hapus filter Gaji'));
    await tester.pumpAndSettle();
    expect(find.text('2 transaksi'), findsOneWidget);
    expect(find.text('Makan siang'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('transaction-reset-filters')));
    await tester.pumpAndSettle();
    expect(find.text('3 transaksi'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('transaction-active-filters')),
      findsNothing,
    );

    store.dispose();
  });

  testWidgets('closing the filter sheet without applying keeps the filter', (
    WidgetTester tester,
  ) async {
    final store = TransactionStore(
      initialTransactions: [
        _transaction(category: 'Makanan', note: 'Makan siang', income: false),
        _transaction(category: 'Gaji', note: 'Gaji bulanan', income: true),
      ],
    );
    await tester.pumpWidget(_screen(store));

    await tester.tap(find.byKey(const ValueKey('transaction-filter-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filter-type-expense')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.text('Filter transaksi'), findsNothing);
    expect(find.text('2 transaksi'), findsOneWidget);

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
    expect(find.text('1 transaksi'), findsOneWidget);

    store.add(
      _transaction(category: 'Makanan', note: 'Makan malam', income: false),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 transaksi'), findsOneWidget);

    store.updateAt(
      0,
      _transaction(category: 'Camilan', note: 'Biskuit', income: false),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 transaksi'), findsOneWidget);
    expect(find.text('Makan siang'), findsOneWidget);
    expect(find.text('Makan malam'), findsNothing);
    expect(find.text('Biskuit'), findsNothing);

    store.removeAt(1);
    await tester.pumpAndSettle();
    expect(find.text('0 transaksi'), findsOneWidget);
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
      isLoading: false,
      errorMessage: null,
      onRefresh: () async {},
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
