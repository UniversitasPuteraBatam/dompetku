import 'dart:async';

import 'package:dompetku/data/dummy_transactions.dart';
import 'package:dompetku/services/app_clock.dart';
import 'package:dompetku/services/monthly_financial_report_exporter.dart';
import 'package:dompetku/screens/monthly_financial_report_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows monthly summary, categories and report transactions', (
    WidgetTester tester,
  ) async {
    final store = TransactionStore(
      initialTransactions: [
        _transaction(DateTime.now().toUtc(), 200000, true, 'Gaji'),
        _transaction(DateTime.now().toUtc(), 50000, false, 'Makanan'),
      ],
    );

    await tester.pumpWidget(_screen(store));
    await tester.pumpAndSettle();

    expect(find.text('Laporan Keuangan'), findsOneWidget);
    expect(find.text('Pemasukan'), findsOneWidget);
    expect(find.text('Pengeluaran'), findsOneWidget);
    expect(find.text('Selisih'), findsOneWidget);
    expect(find.text('Rp 200.000'), findsOneWidget);
    expect(find.text('Rp 50.000'), findsNWidgets(2));
    expect(find.text('Rp 150.000'), findsOneWidget);
    expect(find.text('Makanan'), findsOneWidget);
    expect(find.text('Terbesar'), findsOneWidget);
    expect(find.text('2 transaksi'), findsOneWidget);
    expect(
      find.textContaining('Saldo awal dan akhir rekening tidak tersedia'),
      findsOneWidget,
    );

    store.dispose();
  });

  testWidgets('month and year selection filters report data', (
    WidgetTester tester,
  ) async {
    final now = AppClock.now();
    final store = TransactionStore(
      initialTransactions: [
        _transaction(DateTime.utc(now.year, now.month, 2), 25000, true, 'Gaji'),
        _transaction(DateTime.utc(now.year, 1, 2), 40000, false, 'Belanja'),
        _transaction(DateTime.utc(now.year - 1, 1, 2), 30000, true, 'Bonus'),
      ],
    );

    await tester.pumpWidget(_screen(store));
    await tester.pumpAndSettle();
    expect(find.text('Rp 25.000'), findsNWidgets(2));
    expect(find.text('1 transaksi'), findsOneWidget);

    final monthField = tester.widget<DropdownButtonFormField<int>>(
      find.byKey(const ValueKey('report-month')),
    );
    monthField.onChanged!(1);
    await tester.pumpAndSettle();
    expect(find.text('Rp 0'), findsOneWidget);
    expect(find.text('Rp 40.000'), findsNWidgets(2));
    expect(find.text('Januari ${now.year}'), findsOneWidget);

    final yearField = tester.widget<DropdownButtonFormField<int>>(
      find.byKey(const ValueKey('report-year')),
    );
    yearField.onChanged!(now.year - 1);
    await tester.pumpAndSettle();
    expect(find.text('Rp 30.000'), findsNWidgets(2));
    expect(find.text('1 transaksi'), findsOneWidget);

    store.dispose();
  });

  testWidgets('shows loading, error, and empty report state', (
    WidgetTester tester,
  ) async {
    final store = TransactionStore(initialTransactions: []);
    await tester.pumpWidget(
      MaterialApp(
        home: MonthlyFinancialReportScreen(
          store: store,
          isLoading: true,
          errorMessage: null,
          onRefresh: () async => null,
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpWidget(
      _reportScreen(
        store: store,
        isLoading: false,
        errorMessage: 'API tidak tersedia.',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('API tidak tersedia.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Belum ada transaksi pada bulan ini.'),
      240,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Belum ada transaksi pada bulan ini.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Belum ada pengeluaran bulan ini.'),
      240,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Belum ada pengeluaran bulan ini.'), findsOneWidget);

    store.dispose();
  });

  testWidgets('exports the selected period and reports save failures', (
    WidgetTester tester,
  ) async {
    final now = AppClock.now();
    final store = TransactionStore(initialTransactions: []);
    final savedNames = <String>[];
    final saveResult = Completer<String?>();
    final exporter = MonthlyFinancialReportExporter(
      saveFile:
          ({
            required bytes,
            required name,
            required extension,
            required mimeType,
          }) async {
            savedNames.add('$name.$extension');
            return saveResult.future;
          },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MonthlyFinancialReportScreen(
          store: store,
          isLoading: false,
          errorMessage: null,
          onRefresh: () async => null,
          exporter: exporter,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final monthField = tester.widget<DropdownButtonFormField<int>>(
      find.byKey(const ValueKey('report-month')),
    );
    monthField.onChanged!(1);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('export-report-pdf')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Membuat PDF...'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('export-report-excel')),
          )
          .onPressed,
      isNull,
    );
    saveResult.complete('saved-file');
    await tester.pumpAndSettle();
    expect(savedNames, ['dompetku_laporan_keuangan_${now.year}_01.pdf']);
    expect(find.text('Laporan PDF berhasil diekspor.'), findsOneWidget);

    store.dispose();
  });

  testWidgets('shows an error when saving an exported file fails', (
    WidgetTester tester,
  ) async {
    final store = TransactionStore(initialTransactions: []);
    final exporter = MonthlyFinancialReportExporter(
      saveFile:
          ({
            required bytes,
            required name,
            required extension,
            required mimeType,
          }) async => '',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MonthlyFinancialReportScreen(
          store: store,
          isLoading: false,
          errorMessage: null,
          onRefresh: () async => null,
          exporter: exporter,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('export-report-excel')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Gagal mengekspor Excel:'), findsOneWidget);
    expect(find.text('Laporan Excel berhasil diekspor.'), findsNothing);

    store.dispose();
  });
}

Widget _screen(TransactionStore store) => MaterialApp(
  home: MonthlyFinancialReportScreen(
    store: store,
    isLoading: false,
    errorMessage: null,
    onRefresh: () async => null,
  ),
);

Widget _reportScreen({
  required TransactionStore store,
  required bool isLoading,
  required String? errorMessage,
}) => MaterialApp(
  home: MonthlyFinancialReportScreen(
    store: store,
    isLoading: isLoading,
    errorMessage: errorMessage,
    onRefresh: () async => null,
  ),
);

TransactionItem _transaction(
  DateTime date,
  int amount,
  bool income,
  String category,
) => TransactionItem(
  id: date.day,
  category: category,
  amount: amount,
  date: DateTime.utc(date.year, date.month, date.day, 12),
  isIncome: income,
  icon: income ? Icons.savings : Icons.receipt,
);
