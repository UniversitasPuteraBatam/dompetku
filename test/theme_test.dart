import 'package:dompetku/data/dummy_transactions.dart';
import 'package:dompetku/screens/financial_chart_screen.dart';
import 'package:dompetku/screens/monthly_financial_report_screen.dart';
import 'package:dompetku/screens/settings_screen.dart';
import 'package:dompetku/screens/transactions_screen.dart';
import 'package:dompetku/services/app_clock.dart';
import 'package:dompetku/theme/app_theme.dart';
import 'package:dompetku/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget themedApp(ThemeController controller, Widget home) => ThemeScope(
    controller: controller,
    child: ListenableBuilder(
      listenable: controller,
      builder: (context, _) => MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: controller.mode,
        home: home,
      ),
    ),
  );

  testWidgets('settings switches the whole app to dark and back', (
    WidgetTester tester,
  ) async {
    final controller = ThemeController(initialMode: ThemeMode.light);
    await tester.pumpWidget(
      themedApp(controller, SettingsScreen(onChangePassword: () {})),
    );

    BuildContext screen() => tester.element(find.text('Tema aplikasi'));
    expect(Theme.of(screen()).brightness, Brightness.light);

    await tester.tap(find.text('Gelap'));
    await tester.pumpAndSettle();
    expect(controller.mode, ThemeMode.dark);
    expect(Theme.of(screen()).brightness, Brightness.dark);
    expect(screen().palette.surface, AppPalette.dark.surface);
    expect(find.text('Selalu memakai tema gelap'), findsOneWidget);

    await tester.tap(find.text('Terang'));
    await tester.pumpAndSettle();
    expect(Theme.of(screen()).brightness, Brightness.light);
  });

  test('remembers the chosen theme on the device', () async {
    final controller = ThemeController();
    await controller.setMode(ThemeMode.dark);

    final reloaded = await ThemeController.load();
    expect(reloaded.mode, ThemeMode.dark);
  });

  test('follows the system theme when nothing valid is saved', () async {
    expect((await ThemeController.load()).mode, ThemeMode.system);

    SharedPreferences.setMockInitialValues({'theme_mode': 'purple'});
    expect((await ThemeController.load()).mode, ThemeMode.system);
  });

  group('dark theme screens use dark surfaces', () {
    final store = TransactionStore(
      initialTransactions: [
        TransactionItem(
          id: 1,
          category: 'Gaji',
          amount: 500000,
          date: AppClock.now(),
          isIncome: true,
          icon: Icons.savings,
        ),
        TransactionItem(
          id: 2,
          category: 'Belanja',
          amount: 2000,
          date: AppClock.now(),
          isIncome: false,
          icon: Icons.shopping_bag_outlined,
        ),
      ],
    );
    final dark = ThemeController(initialMode: ThemeMode.dark);

    Color? boxColor(WidgetTester tester, Finder finder) =>
        (tester.widget<Container>(finder).decoration as BoxDecoration?)?.color;

    testWidgets('financial chart', (WidgetTester tester) async {
      await tester.pumpWidget(
        themedApp(
          dark,
          FinancialChartScreen(
            store: store,
            isLoading: false,
            errorMessage: null,
            onRefresh: () async => null,
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        boxColor(tester, find.byKey(const ValueKey('financial-chart-frame'))),
        AppPalette.dark.surface,
      );
      final income = tester.widget<Text>(find.text('Rp 500.000').first);
      expect(income.style?.color, AppPalette.dark.success);
    });

    testWidgets('monthly report', (WidgetTester tester) async {
      await tester.pumpWidget(
        themedApp(
          dark,
          MonthlyFinancialReportScreen(
            store: store,
            isLoading: false,
            errorMessage: null,
            onRefresh: () async => null,
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor ??
            Theme.of(
              tester.element(find.byType(Scaffold)),
            ).scaffoldBackgroundColor,
        AppPalette.dark.background,
      );
    });

    testWidgets('transaction list', (WidgetTester tester) async {
      await tester.pumpWidget(
        themedApp(
          dark,
          Scaffold(
            body: TransactionsScreen(
              store: store,
              isLoading: false,
              errorMessage: null,
              onRefresh: () async {},
              onEditTransaction: (_) {},
              onDeleteTransaction: (_) async {},
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final expense = tester.widget<Text>(find.text('-Rp 2.000'));
      expect(expense.style?.color, AppPalette.dark.danger);
      final title = tester.widget<Text>(find.text('Gaji').first);
      expect(title.style?.color, AppPalette.dark.text);
    });
  });
}
