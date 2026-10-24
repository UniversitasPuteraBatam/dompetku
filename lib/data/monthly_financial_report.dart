import 'dummy_transactions.dart';

class MonthlyExpenseCategory {
  const MonthlyExpenseCategory({required this.category, required this.amount});

  final String category;
  final int amount;
}

class MonthlyFinancialReport {
  const MonthlyFinancialReport({
    required this.year,
    required this.month,
    required this.income,
    required this.expense,
    required this.transactions,
    required this.expensesByCategory,
  });

  final int year;
  final int month;
  final int income;
  final int expense;
  final List<TransactionItem> transactions;
  final List<MonthlyExpenseCategory> expensesByCategory;

  int get difference => income - expense;
  int get transactionCount => transactions.length;
  bool get hasTransactions => transactions.isNotEmpty;

  String? get largestExpenseCategory =>
      expensesByCategory.isEmpty ? null : expensesByCategory.first.category;

  int? get openingBalance => null;
  int? get closingBalance => null;

  factory MonthlyFinancialReport.fromTransactions({
    required List<TransactionItem> transactions,
    required int year,
    required int month,
  }) {
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month', 'Must be between 1 and 12.');
    }

    final monthlyTransactions = transactions
        .where((transaction) =>
            transaction.date.year == year && transaction.date.month == month)
        .toList(growable: false);

    var income = 0;
    var expense = 0;
    final expensesByCategory = <String, int>{};
    for (final transaction in monthlyTransactions) {
      if (transaction.isIncome) {
        income += transaction.amount;
      } else {
        expense += transaction.amount;
        expensesByCategory.update(
          transaction.category,
          (amount) => amount + transaction.amount,
          ifAbsent: () => transaction.amount,
        );
      }
    }

    final categories = expensesByCategory.entries
        .map(
          (entry) =>
              MonthlyExpenseCategory(category: entry.key, amount: entry.value),
        )
        .toList()
      ..sort((first, second) {
        final byAmount = second.amount.compareTo(first.amount);
        return byAmount != 0 ? byAmount : first.category.compareTo(second.category);
      });

    return MonthlyFinancialReport(
      year: year,
      month: month,
      income: income,
      expense: expense,
      transactions: monthlyTransactions,
      expensesByCategory: List.unmodifiable(categories),
    );
  }
}
