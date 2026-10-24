import 'package:flutter/material.dart';

import '../services/app_clock.dart';
import '../theme/app_theme.dart';
import 'month_names.dart';

class TransactionItem {
  const TransactionItem({
    this.id,
    required this.category,
    required this.amount,
    required this.date,
    required this.isIncome,
    required this.icon,
    this.hasTime = true,
    this.note = '',
  });

  final int? id;
  final String category;
  final int amount;
  final DateTime date;
  final bool isIncome;
  final IconData icon;
  final bool hasTime;
  final String note;

  factory TransactionItem.fromApiJson(Map<String, dynamic> json) {
    final type = json['type'];
    final category = json['category'];
    final amountValue = json['amount'];
    final description = json['description'];
    final dateValue = json['transaction_date'];
    final idValue = json['id'];
    final id = idValue is num
        ? idValue.toInt()
        : int.tryParse(idValue?.toString() ?? '');
    final amount = amountValue is num
        ? amountValue.toInt()
        : num.tryParse(amountValue?.toString() ?? '')?.toInt();
    final timestamp = dateValue is String
        ? AppClock.parseJakartaTimestamp(dateValue)
        : null;
    final date =
        timestamp ?? (dateValue is String ? _calendarDate(dateValue) : null);

    if ((type != 'income' && type != 'expense') ||
        category is! String ||
        id == null ||
        amount == null ||
        date == null ||
        (description != null && description is! String)) {
      throw const FormatException('Data transaksi dari server tidak valid.');
    }

    final isIncome = type == 'income';
    return TransactionItem(
      id: id,
      category: category,
      amount: amount,
      date: date,
      isIncome: isIncome,
      icon: iconForCategory(category, isIncome),
      hasTime: timestamp != null,
      note: description as String? ?? '',
    );
  }

  String get title => note.trim().isEmpty ? category : note.trim();
  Color get color => isIncome ? AppColors.success : AppColors.danger;
  String get amountLabel => formatRupiah(amount);
  String get signedAmount => '${isIncome ? '+' : '-'}${formatRupiah(amount)}';
  String get dateLabel => formatTransactionDate(date, includeTime: hasTime);
}

/// Date-only values such as `2026-10-07`. Values with a time part, including
/// ISO strings like `2026-10-06T20:00:00.000Z`, go through
/// [AppClock.parseJakartaTimestamp] so they are shifted to Jakarta time.
DateTime? _calendarDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
  try {
    return AppClock.calendarDate(value);
  } on FormatException {
    return null;
  }
}

class TransactionStore extends ChangeNotifier {
  TransactionStore({List<TransactionItem>? initialTransactions})
    : _transactions = List.of(initialTransactions ?? dummyTransactions);

  final List<TransactionItem> _transactions;

  List<TransactionItem> get transactions => List.unmodifiable(_transactions);

  int get totalIncome => _totalForType(isIncome: true);
  int get totalExpense => _totalForType(isIncome: false);
  int get balance => totalIncome - totalExpense;

  int _totalForType({required bool isIncome}) => _transactions
      .where((transaction) => transaction.isIncome == isIncome)
      .fold(0, (total, transaction) => total + transaction.amount);

  void add(TransactionItem transaction) {
    _transactions.insert(0, transaction);
    notifyListeners();
  }

  void replaceAll(List<TransactionItem> transactions) {
    _transactions
      ..clear()
      ..addAll(transactions);
    notifyListeners();
  }

  void updateAt(int index, TransactionItem transaction) {
    _transactions[index] = transaction;
    notifyListeners();
  }

  void removeAt(int index) {
    _transactions.removeAt(index);
    notifyListeners();
  }
}

IconData iconForCategory(String category, bool isIncome) => switch (category) {
  'Gaji' => Icons.account_balance_rounded,
  'Bonus' => Icons.card_giftcard_rounded,
  'Investasi' => Icons.trending_up_rounded,
  'Freelance' => Icons.laptop_mac_rounded,
  'Makanan' => Icons.restaurant_outlined,
  'Transportasi' => Icons.directions_car_outlined,
  'Belanja' => Icons.shopping_bag_outlined,
  'Tagihan' => Icons.receipt_long_outlined,
  'Kesehatan' => Icons.health_and_safety_outlined,
  'Hiburan' => Icons.movie_outlined,
  _ => isIncome ? Icons.savings_outlined : Icons.payments_outlined,
};

final dummyTransactions = <TransactionItem>[
  TransactionItem(
    category: 'Gaji',
    amount: 5000000,
    date: AppClock.now(),
    isIncome: true,
    icon: Icons.account_balance_rounded,
    note: 'Gaji bulanan',
  ),
  TransactionItem(
    category: 'Belanja',
    amount: 450000,
    date: AppClock.now(),
    isIncome: false,
    icon: Icons.shopping_bag_outlined,
    note: 'Belanja bulanan',
  ),
  TransactionItem(
    category: 'Makanan',
    amount: 38000,
    date: AppClock.now().subtract(const Duration(days: 1)),
    isIncome: false,
    icon: Icons.local_cafe_outlined,
    note: 'Kopi & sarapan',
  ),
  TransactionItem(
    category: 'Freelance',
    amount: 850000,
    date: AppClock.now().subtract(const Duration(days: 2)),
    isIncome: true,
    icon: Icons.laptop_mac_rounded,
    note: 'Freelance desain',
  ),
];

String formatRupiah(int amount) {
  if (amount < 0) return '-${formatRupiah(-amount)}';
  final digits = amount.toString();
  final formatted = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    formatted.write(digits[index]);
    final remainingDigits = digits.length - index - 1;
    if (remainingDigits > 0 && remainingDigits % 3 == 0) {
      formatted.write('.');
    }
  }
  return 'Rp $formatted';
}

String formatTransactionDate(DateTime date, {bool includeTime = true}) {
  final label = '${date.day} ${shortMonthNames[date.month - 1]} ${date.year}';
  if (!includeTime) return label;
  final time =
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
  return '$label, $time';
}
