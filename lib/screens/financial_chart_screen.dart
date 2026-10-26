import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../data/dummy_transactions.dart';
import '../data/financial_chart_data.dart';
import '../services/app_clock.dart';
import '../theme/app_theme.dart';
import '../widgets/cash_flow_summary.dart';
import '../widgets/error_notice.dart';

class FinancialChartScreen extends StatefulWidget {
  const FinancialChartScreen({
    super.key,
    required this.store,
    required this.isLoading,
    required this.errorMessage,
    required this.onRefresh,
    this.onMonthlyReportTap,
  });

  final TransactionStore store;
  final bool isLoading;
  final String? errorMessage;
  final Future<String?> Function() onRefresh;
  final VoidCallback? onMonthlyReportTap;

  @override
  State<FinancialChartScreen> createState() => _FinancialChartScreenState();
}

class _FinancialChartScreenState extends State<FinancialChartScreen> {
  FinancialChartPeriod _period = FinancialChartPeriod.last7Days;
  bool _isRefreshing = false;
  String? _refreshError;

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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Grafik Keuangan'),
      actions: [
        if (widget.onMonthlyReportTap != null)
          IconButton(
            tooltip: 'Laporan Bulanan',
            onPressed: widget.onMonthlyReportTap,
            icon: const Icon(Icons.summarize_outlined),
          ),
      ],
    ),
    body: AnimatedBuilder(
      animation: widget.store,
      builder: (context, child) {
        final chartData = FinancialChartData.fromTransactions(
          transactions: widget.store.transactions,
          period: _period,
          now: AppClock.now(),
        );
        final isLoading = widget.isLoading || _isRefreshing;
        if (isLoading && widget.store.transactions.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
            children: [
              if (isLoading) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 12),
              ],
              if (_refreshError != null || widget.errorMessage != null) ...[
                ErrorNotice(
                  message: _refreshError ?? widget.errorMessage!,
                  onRetry: _refresh,
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<FinancialChartPeriod>(
                  key: const ValueKey('financial-chart-period'),
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    minimumSize: const Size.fromHeight(42),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  selected: {_period},
                  onSelectionChanged: (selection) =>
                      setState(() => _period = selection.first),
                  segments: [
                    for (final period in FinancialChartPeriod.values)
                      ButtonSegment(
                        value: period,
                        label: Text(
                          period.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              CashFlowSummary(
                income: chartData.income,
                expense: chartData.expense,
                difference: chartData.difference,
              ),
              const SizedBox(height: 24),
              if (chartData.hasTransactions) ...[
                Text(
                  'Pemasukan & Pengeluaran',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: context.palette.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                _FinancialBarChart(data: chartData),
              ] else
                const _EmptyChart(),
            ],
          ),
        );
      },
    ),
  );
}

class _FinancialBarChart extends StatelessWidget {
  const _FinancialBarChart({required this.data});

  final FinancialChartData data;

  static const _leftAxisWidth = 44.0;

  @override
  Widget build(BuildContext context) {
    final peak = data.buckets.fold<int>(
      0,
      (value, bucket) => [
        value,
        bucket.income,
        bucket.expense,
      ].reduce((a, b) => a > b ? a : b),
    );
    // Round the axis to tidy steps (1, 2, 2.5, 5 × 10ⁿ) and keep ~10% headroom
    // above the tallest bar so it never touches the top edge.
    final interval = peak == 0 ? 1000.0 : _niceInterval(peak / 4);
    final maxY = peak == 0
        ? interval * 4
        : (peak * 1.1 / interval).ceil() * interval;
    final labelStep = data.period == FinancialChartPeriod.thisMonth ? 5 : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          key: const ValueKey('financial-chart-frame'),
          height: 270,
          // Extra top padding: the top axis label is centred on the top grid
          // line, so half of it sits above the plot area.
          padding: const EdgeInsets.fromLTRB(4, 28, 14, 8),
          decoration: BoxDecoration(
            color: context.palette.surface,
            border: Border.all(color: context.palette.border),
            borderRadius: BorderRadius.circular(16),
          ),
          // The chart always fits the available width so every day or month,
          // including today on the far right, is visible without scrolling.
          child: LayoutBuilder(
            builder: (context, constraints) {
              final groupCount = data.buckets.length;
              final groupWidth =
                  (constraints.maxWidth - _leftAxisWidth) / groupCount;
              final barsSpace = groupCount > 12 ? 1.0 : 4.0;
              final rodWidth = ((groupWidth * 0.8 - barsSpace) / 2).clamp(
                2.0,
                12.0,
              );
              return BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  minY: 0,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: interval,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: context.palette.border,
                      strokeWidth: 1,
                      dashArray: const [4, 4],
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      tooltipPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      getTooltipColor: (_) => context.palette.background,
                      tooltipBorder: BorderSide(color: context.palette.border),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                          BarTooltipItem(
                            formatRupiah(rod.toY.round()),
                            TextStyle(
                              color: rod.color,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: _leftAxisWidth,
                        interval: interval,
                        getTitlesWidget: (value, meta) => SideTitleWidget(
                          meta: meta,
                          child: Text(
                            _shortAmount(value),
                            style: TextStyle(
                              color: context.palette.secondaryText,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= data.buckets.length) {
                            return const SizedBox.shrink();
                          }
                          if (index % labelStep != 0 &&
                              index != data.buckets.length - 1) {
                            return const SizedBox.shrink();
                          }
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              data.buckets[index].label,
                              style: TextStyle(
                                color: context.palette.secondaryText,
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var index = 0; index < data.buckets.length; index++)
                      BarChartGroupData(
                        x: index,
                        barsSpace: barsSpace,
                        barRods: [
                          BarChartRodData(
                            toY: data.buckets[index].income.toDouble(),
                            color: context.palette.success,
                            width: rodWidth,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(rodWidth / 2.5),
                            ),
                          ),
                          BarChartRodData(
                            toY: data.buckets[index].expense.toDouble(),
                            color: context.palette.danger,
                            width: rodWidth,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(rodWidth / 2.5),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 20,
          children: [
            _ChartLegend(color: context.palette.success, label: 'Pemasukan'),
            _ChartLegend(color: context.palette.danger, label: 'Pengeluaran'),
          ],
        ),
      ],
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: TextStyle(color: context.palette.secondaryText, fontSize: 12),
      ),
    ],
  );
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
    decoration: BoxDecoration(
      color: context.palette.surface,
      border: Border.all(color: context.palette.border),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        Icon(
          Icons.bar_chart_rounded,
          size: 38,
          color: context.palette.secondaryText,
        ),
        SizedBox(height: 10),
        Text(
          'Belum ada transaksi pada periode ini',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.palette.secondaryText),
        ),
      ],
    ),
  );
}

double _niceInterval(double raw) {
  final magnitude = math
      .pow(10, (math.log(raw) / math.ln10).floor())
      .toDouble();
  final normalized = raw / magnitude;
  for (final step in const [1.0, 2.0, 2.5, 5.0]) {
    if (normalized <= step) return step * magnitude;
  }
  return 10 * magnitude;
}

String _shortAmount(double value) {
  if (value >= 1000000) return '${_trimDecimal(value / 1000000)} jt';
  if (value >= 1000) return '${_trimDecimal(value / 1000)} rb';
  return value.round().toString();
}

// 2.5 -> "2,5", 3.0 -> "3".
String _trimDecimal(double value) {
  final rounded = (value * 10).round() / 10;
  return rounded == rounded.roundToDouble()
      ? rounded.round().toString()
      : rounded.toString().replaceAll('.', ',');
}
