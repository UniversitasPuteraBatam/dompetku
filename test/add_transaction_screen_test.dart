import 'package:dompetku/data/dummy_transactions.dart';
import 'package:dompetku/screens/add_transaction_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('edits a transaction whose category is not in the default list', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AddTransactionScreen(
          transaction: TransactionItem(
            id: 9,
            category: 'Pendidikan',
            amount: 250000,
            date: DateTime.utc(2026, 10, 7, 9),
            isIncome: false,
            icon: Icons.payments_outlined,
            note: 'Buku kuliah',
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Edit Transaksi'), findsOneWidget);
    expect(find.text('Pendidikan'), findsOneWidget);

    await tester.tap(find.text('Pendidikan'));
    await tester.pumpAndSettle();
    expect(find.text('Makanan'), findsWidgets);
    expect(find.text('Pendidikan'), findsWidgets);
  });

  testWidgets('switching type drops a category from the other type', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AddTransactionScreen(
          transaction: TransactionItem(
            id: 9,
            category: 'Pendidikan',
            amount: 250000,
            date: DateTime.utc(2026, 10, 7, 9),
            isIncome: false,
            icon: Icons.payments_outlined,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Pemasukan'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Pendidikan'), findsNothing);
    expect(find.text('Pilih kategori'), findsOneWidget);
  });
}
