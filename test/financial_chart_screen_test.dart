import 'package:dompetku/data/dummy_transactions.dart';
import 'package:dompetku/screens/financial_chart_screen.dart';
import 'package:dompetku/services/app_clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('empty chart shows zero totals for selected period', (
    WidgetTester tester,
  ) async {
    final store = TransactionStore(initialTransactions: []);
    await tester.pumpWidget(
      MaterialApp(
        home: FinancialChartScreen(
          store: store,
          isLoading: false,
          errorMessage: null,
          onRefresh: () async => null,
        ),
      ),
    );

    expect(find.text('Grafik Keuangan'), findsOneWidget);
    expect(find.text('Belum ada transaksi pada periode ini'), findsOneWidget);
    expect(find.text('Rp 0'), findsNWidgets(3));

    await tester.tap(find.widgetWithText(ChoiceChip, 'Tahun Ini'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Tahun Ini'))
          .selected,
      isTrue,
    );
    expect(find.text('Belum ada transaksi pada periode ini'), findsOneWidget);

    store.dispose();
  });

  testWidgets('shows loading and API error states without transactions', (
    WidgetTester tester,
  ) async {
    final store = TransactionStore(initialTransactions: []);
    await tester.pumpWidget(
      MaterialApp(
        home: FinancialChartScreen(
          store: store,
          isLoading: true,
          errorMessage: null,
          onRefresh: () async => null,
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: FinancialChartScreen(
          store: store,
          isLoading: false,
          errorMessage: 'Server sedang bermasalah.',
          onRefresh: () async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Server sedang bermasalah.'), findsOneWidget);
    expect(find.text('Belum ada transaksi pada periode ini'), findsOneWidget);

    store.dispose();
  });

  for (final (period, lastLabel) in [
    ('7 Hari', '${AppClock.now().day}/${AppClock.now().month}'),
    (
      'Bulan Ini',
      '${DateTime.utc(AppClock.now().year, AppClock.now().month + 1, 0).day}',
    ),
    ('Tahun Ini', 'Des'),
  ]) {
    testWidgets('$period chart fits a phone screen without scrolling', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2220);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final store = TransactionStore(
        initialTransactions: [
          TransactionItem(
            category: 'Gaji',
            amount: 500000,
            date: AppClock.now(),
            isIncome: true,
            icon: Icons.savings,
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: FinancialChartScreen(
            store: store,
            isLoading: false,
            errorMessage: null,
            onRefresh: () async => null,
          ),
        ),
      );
      await tester.tap(find.widgetWithText(ChoiceChip, period));
      await tester.pumpAndSettle();

      final frame = find.byKey(const ValueKey('financial-chart-frame'));
      final frameRect = tester.getRect(frame);
      expect(frameRect.right, lessThanOrEqualTo(360));
      expect(
        find.descendant(of: frame, matching: find.byType(Scrollable)),
        findsNothing,
      );
      final lastLabelRect = tester.getRect(
        find.descendant(of: frame, matching: find.text(lastLabel)).last,
      );
      expect(lastLabelRect.left, greaterThanOrEqualTo(frameRect.left));
      expect(lastLabelRect.right, lessThanOrEqualTo(frameRect.right));

      store.dispose();
    });
  }

  for (final period in ['Bulan Ini', 'Tahun Ini']) {
    testWidgets('keeps the top amount label inside the $period chart', (
      WidgetTester tester,
    ) async {
      final store = TransactionStore(
        initialTransactions: [
          TransactionItem(
            category: 'Gaji',
            amount: 6000000,
            // Today always falls inside both "Bulan Ini" and "Tahun Ini".
            date: AppClock.now(),
            isIncome: true,
            icon: Icons.savings,
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: FinancialChartScreen(
            store: store,
            isLoading: false,
            errorMessage: null,
            onRefresh: () async => null,
          ),
        ),
      );
      await tester.tap(find.widgetWithText(ChoiceChip, period));
      await tester.pumpAndSettle();

      final chartRect = tester.getRect(
        find.byKey(const ValueKey('financial-chart-frame')),
      );
      final topAxisLabel = find.text('8 jt');
      expect(topAxisLabel, findsWidgets);
      final labelRects =
          tester
              .widgetList<Text>(topAxisLabel)
              .map((label) => tester.getRect(find.byWidget(label)))
              .toList()
            ..sort((first, second) => first.top.compareTo(second.top));
      final amountLabelRect = labelRects.first;
      expect(amountLabelRect.top, greaterThanOrEqualTo(chartRect.top));
      expect(amountLabelRect.bottom, lessThanOrEqualTo(chartRect.bottom));
      expect(amountLabelRect.top, greaterThan(chartRect.top + 12));

      store.dispose();
    });
  }
}
