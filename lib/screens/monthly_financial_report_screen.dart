import 'package:flutter/material.dart';

import '../data/dummy_transactions.dart';
import '../data/month_names.dart';
import '../data/monthly_financial_report.dart';
import '../services/app_clock.dart';
import '../services/monthly_financial_report_exporter.dart';
import '../theme/app_theme.dart';
import '../widgets/cash_flow_summary.dart';
import '../widgets/error_notice.dart';
import 'transactions_screen.dart';

class MonthlyFinancialReportScreen extends StatefulWidget {
  const MonthlyFinancialReportScreen({
    super.key,
    required this.store,
    required this.isLoading,
    required this.errorMessage,
    required this.onRefresh,
    this.exporter,
  });

  final TransactionStore store;
  final bool isLoading;
  final String? errorMessage;
  final Future<String?> Function() onRefresh;
  final MonthlyFinancialReportExporter? exporter;

  @override
  State<MonthlyFinancialReportScreen> createState() =>
      _MonthlyFinancialReportScreenState();
}

class _MonthlyFinancialReportScreenState
    extends State<MonthlyFinancialReportScreen> {
  late int _selectedMonth;
  late int _selectedYear;
  late bool _isRefreshing;
  String? _exportingFormat;
  String? _refreshError;

  @override
  void initState() {
    super.initState();
    final now = AppClock.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
    _isRefreshing = false;
    _exportingFormat = null;
  }

  Future<void> _refresh() async {
    setState(() {
      _isRefreshing = true;
      _refreshError = null;
    });
    try {
      _refreshError = await widget.onRefresh();
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _export(
    MonthlyFinancialReport report, {
    required bool asPdf,
  }) async {
    setState(() => _exportingFormat = asPdf ? 'PDF' : 'Excel');
    try {
      final exporter = widget.exporter ?? MonthlyFinancialReportExporter();
      String? savedPath;
      if (asPdf) {
        savedPath = await exporter.exportPdf(report);
      } else {
        savedPath = await exporter.exportExcel(report);
      }
      if (!mounted || savedPath == null) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Laporan ${asPdf ? 'PDF' : 'Excel'} berhasil diekspor.',
            ),
          ),
        );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Gagal mengekspor ${asPdf ? 'PDF' : 'Excel'}: $error',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
    } finally {
      if (mounted) setState(() => _exportingFormat = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Laporan Keuangan')),
    body: AnimatedBuilder(
      animation: widget.store,
      builder: (context, child) {
        final allTransactions = widget.store.transactions;
        final report = MonthlyFinancialReport.fromTransactions(
          transactions: allTransactions,
          year: _selectedYear,
          month: _selectedMonth,
        );
        final years = {
          AppClock.now().year,
          ...allTransactions.map((transaction) => transaction.date.year),
        }.toList()..sort((first, second) => second.compareTo(first));
        final isLoading = _isRefreshing || widget.isLoading;
        final errorMessage = _refreshError ?? widget.errorMessage;

        if (isLoading && allTransactions.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
            children: [
              if (isLoading) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 12),
              ],
              if (errorMessage != null) ...[
                ErrorNotice(message: errorMessage, onRetry: _refresh),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<int>(
                      key: const ValueKey('report-month'),
                      initialValue: _selectedMonth,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Bulan'),
                      items: [
                        for (var month = 1; month <= 12; month++)
                          DropdownMenuItem(
                            value: month,
                            child: Text(monthNames[month - 1]),
                          ),
                      ],
                      onChanged: (month) {
                        if (month != null) {
                          setState(() => _selectedMonth = month);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<int>(
                      key: const ValueKey('report-year'),
                      initialValue: _selectedYear,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Tahun'),
                      items: [
                        for (final year in years)
                          DropdownMenuItem(value: year, child: Text('$year')),
                      ],
                      onChanged: (year) {
                        if (year != null) setState(() => _selectedYear = year);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                '${monthNames[_selectedMonth - 1]} $_selectedYear',
                key: const ValueKey('report-period-title'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: context.palette.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              CashFlowSummary(
                income: report.income,
                expense: report.expense,
                difference: report.difference,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('export-report-pdf'),
                      style: _exportButtonStyle,
                      onPressed: _exportingFormat == null
                          ? () => _export(report, asPdf: true)
                          : null,
                      icon: _exportingFormat == 'PDF'
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                      label: Text(
                        _exportingFormat == 'PDF'
                            ? 'Membuat PDF...'
                            : 'Ekspor PDF',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('export-report-excel'),
                      style: _exportButtonStyle,
                      onPressed: _exportingFormat == null
                          ? () => _export(report, asPdf: false)
                          : null,
                      icon: _exportingFormat == 'Excel'
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.table_view_outlined, size: 18),
                      label: Text(
                        _exportingFormat == 'Excel'
                            ? 'Membuat Excel...'
                            : 'Ekspor Excel',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const _BalanceDisclosure(),
              const SizedBox(height: 28),
              _SectionHeader(
                title: 'Pengeluaran per Kategori',
                trailing: '${report.expensesByCategory.length} kategori',
              ),
              const SizedBox(height: 12),
              if (report.expensesByCategory.isEmpty)
                const _InlineEmptyMessage('Belum ada pengeluaran bulan ini.')
              else
                for (final item in report.expensesByCategory)
                  _ExpenseCategoryRow(
                    item: item,
                    total: report.expense,
                    isLargest: item.category == report.largestExpenseCategory,
                  ),
              const SizedBox(height: 16),
              _SectionHeader(
                title: 'Transaksi Bulanan',
                trailing: '${report.transactionCount} transaksi',
                trailingKey: const ValueKey('report-transaction-count'),
              ),
              const SizedBox(height: 8),
              if (!report.hasTransactions)
                const _InlineEmptyMessage('Belum ada transaksi pada bulan ini.')
              else
                for (final transaction in report.transactions)
                  TransactionTile(transaction: transaction),
            ],
          ),
        );
      },
    ),
  );
}

final _exportButtonStyle = OutlinedButton.styleFrom(
  minimumSize: const Size.fromHeight(44),
  padding: const EdgeInsets.symmetric(horizontal: 12),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
);

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.trailing,
    this.trailingKey,
  });

  final String title;
  final String trailing;
  final Key? trailingKey;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: context.palette.text,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      Text(
        trailing,
        key: trailingKey,
        style: TextStyle(color: context.palette.secondaryText, fontSize: 12),
      ),
    ],
  );
}

class _BalanceDisclosure extends StatelessWidget {
  const _BalanceDisclosure();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: context.palette.primarySoft,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: context.palette.primarySoftBorder),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline_rounded,
          color: context.palette.accent,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Saldo awal dan akhir rekening tidak tersedia. Selisih adalah arus bersih transaksi bulan ini, bukan saldo rekening.',
            style: TextStyle(
              color: context.palette.secondaryText,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ExpenseCategoryRow extends StatelessWidget {
  const _ExpenseCategoryRow({
    required this.item,
    required this.total,
    required this.isLargest,
  });

  final MonthlyExpenseCategory item;
  final int total;
  final bool isLargest;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      item.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.palette.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (isLargest)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: context.palette.dangerSoft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Terbesar',
                        style: TextStyle(
                          color: context.palette.danger,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatRupiah(item.amount),
              style: TextStyle(
                color: context.palette.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: total == 0 ? 0 : item.amount / total,
          color: context.palette.danger,
          backgroundColor: context.palette.dangerTrack,
          minHeight: 6,
          borderRadius: BorderRadius.circular(8),
        ),
      ],
    ),
  );
}

class _InlineEmptyMessage extends StatelessWidget {
  const _InlineEmptyMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
    decoration: BoxDecoration(
      color: context.palette.surface,
      border: Border.all(color: context.palette.border),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: TextStyle(color: context.palette.secondaryText),
    ),
  );
}
