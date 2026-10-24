import 'package:flutter/material.dart';

import '../data/dummy_transactions.dart';
import '../theme/app_theme.dart';

/// Pemasukan, Pengeluaran and Selisih cards laid out in one row.
class CashFlowSummary extends StatelessWidget {
  const CashFlowSummary({
    super.key,
    required this.income,
    required this.expense,
    required this.difference,
  });

  final int income;
  final int expense;
  final int difference;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const spacing = 8.0;
      final cardWidth = (constraints.maxWidth - spacing * 2) / 3;
      return Row(
        children: [
          SizedBox(
            width: cardWidth,
            child: _AmountCard(
              label: 'Pemasukan',
              amount: income,
              color: context.palette.success,
            ),
          ),
          const SizedBox(width: spacing),
          SizedBox(
            width: cardWidth,
            child: _AmountCard(
              label: 'Pengeluaran',
              amount: expense,
              color: context.palette.danger,
            ),
          ),
          const SizedBox(width: spacing),
          SizedBox(
            width: cardWidth,
            child: _AmountCard(
              label: 'Selisih',
              amount: difference,
              color: context.palette.accent,
            ),
          ),
        ],
      );
    },
  );
}

class _AmountCard extends StatelessWidget {
  const _AmountCard({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 100),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: context.palette.surface,
      border: Border.all(color: context.palette.border),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: context.palette.secondaryText),
        ),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            formatRupiah(amount),
            maxLines: 1,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}
