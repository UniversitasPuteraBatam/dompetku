import 'package:flutter/material.dart';

import '../data/dummy_transactions.dart';
import '../data/user_profile.dart';
import '../data/transaction_filter.dart';
import '../services/app_clock.dart';
import '../theme/app_theme.dart';
import '../widgets/profile_avatar.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({
    super.key,
    required this.store,
    required this.profile,
    required this.isLoading,
    required this.errorMessage,
    required this.onRefresh,
    required this.onProfileTap,
    required this.onEditTransaction,
    required this.onDeleteTransaction,
  });

  final TransactionStore store;
  final UserProfile profile;
  final bool isLoading;
  final String? errorMessage;
  final Future<void> Function() onRefresh;
  final VoidCallback onProfileTap;
  final ValueChanged<int> onEditTransaction;
  final Future<void> Function(int) onDeleteTransaction;

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _searchController = TextEditingController();
  TransactionFilter _filter = const TransactionFilter();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _filter = const TransactionFilter();
    });
  }

  Future<void> _confirmDelete(BuildContext context, int index) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus transaksi ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (shouldDelete == true) await widget.onDeleteTransaction(index);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, child) {
      final allTransactions = widget.store.transactions;
      final filteredTransactions = _filter.apply(
        transactions: allTransactions,
        now: AppClock.now(),
      );
      final categories =
          allTransactions
              .map((transaction) => transaction.category)
              .toSet()
              .toList()
            ..sort();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Transaksi',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: context.palette.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Buka profile',
                  onPressed: widget.onProfileTap,
                  icon: ProfileAvatar(
                    photoBytes: widget.profile.photoBytes,
                    photoUrl: widget.profile.profilePhoto,
                    radius: 18,
                  ),
                ),
              ],
            ),
          ),
          if (widget.errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
            child: TextField(
              key: const ValueKey('transaction-search'),
              controller: _searchController,
              onChanged: (query) =>
                  setState(() => _filter = _filter.copyWith(query: query)),
              decoration: InputDecoration(
                hintText: 'Cari kategori atau deskripsi',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _filter.query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Hapus pencarian',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _filter = _filter.copyWith(query: ''));
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              children: [
                for (final type in TransactionTypeFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: ValueKey('transaction-type-${type.name}'),
                      label: Text(type.label),
                      selected: _filter.type == type,
                      onSelected: (_) => setState(
                        () => _filter = _filter.copyWith(type: type),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final date in TransactionDateFilter.values)
                  ChoiceChip(
                    key: ValueKey('transaction-date-${date.name}'),
                    label: Text(date.label),
                    selected: _filter.date == date,
                    onSelected: (_) =>
                        setState(() => _filter = _filter.copyWith(date: date)),
                  ),
                PopupMenuButton<String?>(
                  key: const ValueKey('transaction-category-filter'),
                  tooltip: 'Filter kategori',
                  initialValue: _filter.category,
                  onSelected: (category) => setState(
                    () => _filter = category == null
                        ? _filter.copyWith(clearCategory: true)
                        : _filter.copyWith(category: category),
                  ),
                  itemBuilder: (context) => [
                    const PopupMenuItem<String?>(
                      value: null,
                      child: Text('Semua kategori'),
                    ),
                    for (final category in categories)
                      PopupMenuItem<String?>(
                        value: category,
                        child: Text(category),
                      ),
                  ],
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 116),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: context.palette.surface,
                      border: Border.all(color: context.palette.border),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            _filter.category ?? 'Kategori',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down_rounded, size: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${filteredTransactions.length} transaksi ditemukan',
                    key: const ValueKey('transaction-result-count'),
                    style: TextStyle(
                      color: context.palette.secondaryText,
                      fontSize: 13,
                    ),
                  ),
                ),
                TextButton(
                  key: const ValueKey('transaction-reset-filters'),
                  onPressed: _filter.isDefault ? null : _resetFilters,
                  child: const Text('Reset filter'),
                ),
              ],
            ),
          ),
          Expanded(
            child: widget.isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: widget.onRefresh,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
                      itemCount: filteredTransactions.isEmpty
                          ? 1
                          : filteredTransactions.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        if (filteredTransactions.isEmpty) {
                          return SizedBox(
                            height: 220,
                            child: Center(
                              child: Text(
                                allTransactions.isEmpty
                                    ? 'Belum ada transaksi'
                                    : 'Tidak ada transaksi yang cocok dengan filter.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }
                        final entry = filteredTransactions[index];
                        return TransactionTile(
                          transaction: entry.transaction,
                          onEdit: () => widget.onEditTransaction(entry.index),
                          onDelete: () => _confirmDelete(context, entry.index),
                        );
                      },
                    ),
                  ),
          ),
        ],
      );
    },
  );
}

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    this.onEdit,
    this.onDelete,
  });

  final TransactionItem transaction;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  Color _amountColor(BuildContext context) =>
      transaction.isIncome ? context.palette.success : context.palette.danger;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(vertical: 4),
    leading: Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: _amountColor(context).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(transaction.icon, color: _amountColor(context), size: 21),
    ),
    title: Text(
      transaction.title,
      style: TextStyle(
        color: context.palette.text,
        fontWeight: FontWeight.w600,
      ),
    ),
    subtitle: Text('${transaction.category} · ${transaction.dateLabel}'),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          transaction.signedAmount,
          style: TextStyle(
            color: _amountColor(context),
            fontWeight: FontWeight.w700,
          ),
        ),
        if (onEdit != null)
          PopupMenuButton<String>(
            tooltip: 'Aksi transaksi',
            onSelected: (action) {
              if (action == 'edit') onEdit!();
              if (action == 'delete') onDelete?.call();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined),
                    SizedBox(width: 12),
                    Text('Edit Transaksi'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      color: context.palette.danger,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Hapus',
                      style: TextStyle(color: context.palette.danger),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    ),
    onTap: onEdit,
  );
}
