import 'package:flutter/material.dart';

import '../data/dummy_transactions.dart';
import '../data/transaction_filter.dart';
import '../services/app_clock.dart';
import '../theme/app_theme.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({
    super.key,
    required this.store,
    required this.isLoading,
    required this.errorMessage,
    required this.onRefresh,
    required this.onEditTransaction,
    required this.onDeleteTransaction,
  });

  final TransactionStore store;
  final bool isLoading;
  final String? errorMessage;
  final Future<void> Function() onRefresh;
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

  /// Type, period and category; the search text has its own clear button.
  int get _activeFilterCount => [
    _filter.type != TransactionTypeFilter.all,
    _filter.date != TransactionDateFilter.allDates,
    _filter.category != null,
  ].where((active) => active).length;

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _filter = const TransactionFilter();
    });
  }

  Future<void> _openFilterSheet(
    List<TransactionItem> transactions,
    List<String> categories,
  ) async {
    final selected = await showModalBottomSheet<TransactionFilter>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: context.palette.surface,
      builder: (context) => _FilterSheet(
        initialFilter: _filter,
        categories: categories,
        resultCount: (filter) => filter
            .apply(transactions: transactions, now: AppClock.now())
            .length,
      ),
    );
    if (selected != null && mounted) setState(() => _filter = selected);
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
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 16),
            child: Text(
              'Transaksi',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: context.palette.text,
                fontWeight: FontWeight.w700,
              ),
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
          // Search and a single filter button share one row; the type, period
          // and category choices live in a bottom sheet to leave room for the
          // list on phones.
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('transaction-search'),
                    controller: _searchController,
                    onChanged: (query) => setState(
                      () => _filter = _filter.copyWith(query: query),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Cari transaksi',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _filter.query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Hapus pencarian',
                              onPressed: () {
                                _searchController.clear();
                                setState(
                                  () => _filter = _filter.copyWith(query: ''),
                                );
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _FilterButton(
                  activeCount: _activeFilterCount,
                  onPressed: () =>
                      _openFilterSheet(allTransactions, categories),
                ),
              ],
            ),
          ),
          if (_activeFilterCount > 0)
            SizedBox(
              height: 40,
              child: ListView(
                key: const ValueKey('transaction-active-filters'),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                children: [
                  if (_filter.type != TransactionTypeFilter.all)
                    _ActiveFilterChip(
                      label: _filter.type.label,
                      onDeleted: () => setState(
                        () => _filter = _filter.copyWith(
                          type: TransactionTypeFilter.all,
                        ),
                      ),
                    ),
                  if (_filter.date != TransactionDateFilter.allDates)
                    _ActiveFilterChip(
                      label: _filter.date.label,
                      onDeleted: () => setState(
                        () => _filter = _filter.copyWith(
                          date: TransactionDateFilter.allDates,
                        ),
                      ),
                    ),
                  if (_filter.category != null)
                    _ActiveFilterChip(
                      label: _filter.category!,
                      onDeleted: () => setState(
                        () => _filter = _filter.copyWith(clearCategory: true),
                      ),
                    ),
                  TextButton(
                    key: const ValueKey('transaction-reset-filters'),
                    onPressed: _resetFilters,
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 6, 22, 2),
            child: Text(
              '${filteredTransactions.length} transaksi',
              key: const ValueKey('transaction-result-count'),
              style: TextStyle(
                color: context.palette.secondaryText,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: widget.isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: widget.onRefresh,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      // Bottom space lets the last item scroll above the
                      // add-transaction button.
                      padding: const EdgeInsets.fromLTRB(22, 4, 22, 96),
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

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.activeCount, required this.onPressed});

  final int activeCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Badge(
    isLabelVisible: activeCount > 0,
    label: Text('$activeCount'),
    backgroundColor: AppColors.primary,
    child: SizedBox.square(
      dimension: 52,
      child: IconButton.filledTonal(
        key: const ValueKey('transaction-filter-button'),
        tooltip: 'Filter transaksi',
        onPressed: onPressed,
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: const Icon(Icons.tune_rounded),
      ),
    ),
  );
}

class _ActiveFilterChip extends StatelessWidget {
  const _ActiveFilterChip({required this.label, required this.onDeleted});

  final String label;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: InputChip(
      label: Text(label),
      onDeleted: onDeleted,
      deleteButtonTooltipMessage: 'Hapus filter $label',
      visualDensity: VisualDensity.compact,
    ),
  );
}

/// Edits a copy of the filter and returns it on "Tampilkan"; dismissing the
/// sheet keeps the current filter.
class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.initialFilter,
    required this.categories,
    required this.resultCount,
  });

  final TransactionFilter initialFilter;
  final List<String> categories;
  final int Function(TransactionFilter filter) resultCount;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late TransactionFilter _draft = widget.initialFilter;

  @override
  Widget build(BuildContext context) {
    final count = widget.resultCount(_draft);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Filter transaksi',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: context.palette.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _section('Jenis', [
                    for (final type in TransactionTypeFilter.values)
                      _choice(
                        key: 'filter-type-${type.name}',
                        label: type.label,
                        selected: _draft.type == type,
                        onSelected: () => _draft = _draft.copyWith(type: type),
                      ),
                  ]),
                  _section('Periode', [
                    for (final date in TransactionDateFilter.values)
                      _choice(
                        key: 'filter-date-${date.name}',
                        label: date.label,
                        selected: _draft.date == date,
                        onSelected: () => _draft = _draft.copyWith(date: date),
                      ),
                  ]),
                  _section('Kategori', [
                    _choice(
                      key: 'filter-category-all',
                      label: 'Semua',
                      selected: _draft.category == null,
                      onSelected: () =>
                          _draft = _draft.copyWith(clearCategory: true),
                    ),
                    for (final category in widget.categories)
                      _choice(
                        key: 'filter-category-$category',
                        label: category,
                        selected: _draft.category == category,
                        onSelected: () =>
                            _draft = _draft.copyWith(category: category),
                      ),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('filter-sheet-reset'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  onPressed: () => setState(
                    () => _draft = TransactionFilter(query: _draft.query),
                  ),
                  child: const Text('Reset'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  key: const ValueKey('filter-sheet-apply'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  onPressed: () => Navigator.pop(context, _draft),
                  child: Text('Tampilkan $count transaksi'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> choices) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: context.palette.secondaryText,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: choices),
      ],
    ),
  );

  Widget _choice({
    required String key,
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) => ChoiceChip(
    key: ValueKey(key),
    label: Text(label),
    selected: selected,
    onSelected: (_) => setState(onSelected),
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
