import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../services/csv.dart';
import '../services/format.dart';
import '../theme/app_theme.dart';
import '../widgets/nav.dart';
import '../widgets/shared.dart';
import '../widgets/status_badge.dart';

class ReportsRevenueScreen extends StatefulWidget {
  final NavState nav;
  const ReportsRevenueScreen({super.key, required this.nav});

  @override
  State<ReportsRevenueScreen> createState() => _ReportsRevenueScreenState();
}

class _ReportsRevenueScreenState extends State<ReportsRevenueScreen> {
  late Future<Map<String, dynamic>> _future;
  DateTimeRange? _range;
  String _status = 'all';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final params = <String>[];
    if (_status != 'all') params.add('status=${_status.toUpperCase()}');
    if (_range != null) {
      params.add('created_at__gte=${_range!.start.toIso8601String()}');
      params.add('created_at__lte=${_range!.end.toIso8601String()}');
    }
    final q = params.isEmpty ? '' : '?${params.join('&')}';
    final items = await ApiService.list('/billing/invoices/$q');
    final invoices = items.map(Invoice.fromJson).toList();
    final collected = invoices.where((i) => i.status == 'paid').toList();
    final outstanding =
        invoices.where((i) => i.status != 'paid' && i.status != 'cancelled').toList();
    final overdue = invoices.where((i) => i.status == 'overdue').toList();
    return {
      'invoices': items,
      'total_invoiced':
          invoices.fold<double>(0, (s, i) => s + i.amount),
      'collected':
          collected.fold<double>(0, (s, i) => s + i.amountPaid),
      'outstanding':
          outstanding.fold<double>(0, (s, i) => s + i.amountDue),
      'overdue_count': overdue.length,
    };
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Revenue Report',
      description: 'Track collected, outstanding, overdue, and invoice revenue.',
      actions: [
        _statusDropdown(),
        OutlinedButton.icon(
          onPressed: _pickRange,
          icon: const Icon(Icons.date_range, size: 16),
          label: Text(_range == null
              ? 'Pick a date range'
              : '${formatDate(_range!.start.toIso8601String())} - ${formatDate(_range!.end.toIso8601String())}'),
        ),
        OutlinedButton.icon(
          onPressed: _exportCsv,
          icon: const Icon(Icons.download, size: 16),
          label: const Text('Export CSV'),
        ),
        IconButton(
          onPressed: _reload,
          icon: const Icon(Icons.refresh, size: 18),
          tooltip: 'Refresh',
        ),
      ],
      child: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const LoadingRows();
          }
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.error_outline,
              title: 'Revenue report unavailable',
              description: snap.error.toString(),
            );
          }

          final data = snap.data ?? {};
          final summary = _RevenueSummary.fromJson(
            (data['summary'] as Map?)?.cast<String, dynamic>() ?? data,
          );
          final series = _RevenuePoint.listFrom(data['series']);
          final invoices = _invoiceList(data['invoices']);
          final byStatus = _statusTotals(data['byStatus']);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _summaryGrid(summary),
              const SizedBox(height: 16),
              LayoutBuilder(builder: (context, c) {
                final wide = c.maxWidth > 900;
                final chart = _chartCard(series);
                final status = _statusCard(byStatus, summary);
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: chart),
                      const SizedBox(width: 16),
                      Expanded(child: status),
                    ],
                  );
                }
                return Column(children: [
                  chart,
                  const SizedBox(height: 16),
                  status,
                ]);
              }),
              const SizedBox(height: 16),
              _invoiceTable(invoices),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryGrid(_RevenueSummary s) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 1000
          ? 4
          : c.maxWidth > 650
              ? 2
              : 1;
      return GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.2,
        children: [
          _summaryCard(Icons.payments, 'Collected', formatCurrency(s.collected),
              AppTheme.primary),
          _summaryCard(Icons.pending_actions, 'Outstanding',
              formatCurrency(s.outstanding), const Color(0xFFF59E0B)),
          _summaryCard(Icons.warning_amber_rounded, 'Overdue',
              formatCurrency(s.overdue), const Color(0xFFDC2626)),
          _summaryCard(Icons.receipt_long, 'Invoices', s.invoiceCount.toString(),
              const Color(0xFF7C3AED)),
        ],
      );
    });
  }

  Widget _summaryCard(IconData icon, String label, String value, Color accent) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textMuted)),
                const SizedBox(height: 4),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _chartCard(List<_RevenuePoint> series) {
    return SectionCard(
      title: 'Revenue Trend',
      description: 'Collected invoice amount over time.',
      child: SizedBox(
        height: 280,
        child: series.isEmpty
            ? const EmptyState(
                icon: Icons.show_chart, title: 'No revenue trend data.')
            : LineChart(
                LineChartData(
                  minY: 0,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: _chartInterval(series),
                    getDrawingHorizontalLine: (_) =>
                        const FlLine(color: AppTheme.border, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 64,
                        getTitlesWidget: (value, meta) => Text(
                          formatCompactCurrency(value, currency: ''),
                          style: const TextStyle(
                              fontSize: 10, color: AppTheme.textMuted),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: series.length > 6
                            ? (series.length / 4).ceilToDouble()
                            : 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.round();
                          if (index < 0 || index >= series.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              series[index].label,
                              style: const TextStyle(
                                  fontSize: 10, color: AppTheme.textMuted),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: AppTheme.border),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (int i = 0; i < series.length; i++)
                          FlSpot(i.toDouble(), series[i].amount),
                      ],
                      color: AppTheme.primary,
                      barWidth: 3,
                      isCurved: true,
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.primary.withValues(alpha: 0.12),
                      ),
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _statusCard(Map<String, double> byStatus, _RevenueSummary summary) {
    final rows = byStatus.isEmpty
        ? {
            'paid': summary.collected,
            'unpaid': summary.unpaid,
            'partially_paid': summary.partiallyPaid,
            'overdue': summary.overdue,
          }
        : byStatus;
    final visibleRows =
        rows.entries.where((entry) => entry.value > 0).toList(growable: false);

    return SectionCard(
      title: 'Invoice Status Totals',
      child: visibleRows.isEmpty
          ? const EmptyState(
              icon: Icons.pie_chart_outline, title: 'No status totals.')
          : Column(
              children: [
                for (final entry in visibleRows) ...[
                  Row(
                    children: [
                      StatusBadge(
                        tone: invoiceStatus(entry.key).tone,
                        label: invoiceStatus(entry.key).label,
                        dot: true,
                      ),
                      const Spacer(),
                      Text(formatCurrency(entry.value),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  if (entry != visibleRows.last)
                    const Divider(height: 24, color: AppTheme.border),
                ],
              ],
            ),
    );
  }

  Widget _invoiceTable(List<Invoice> invoices) {
    return SectionCard(
      title: 'Revenue Invoices',
      padding: EdgeInsets.zero,
      action: Text('${invoices.length} records',
          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
      child: invoices.isEmpty
          ? const EmptyState(
              icon: Icons.receipt_long, title: 'No invoices in range.')
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(minWidth: MediaQuery.of(context).size.width - 64),
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Invoice')),
                    DataColumn(label: Text('Patient')),
                    DataColumn(label: Text('Issued')),
                    DataColumn(label: Text('Due')),
                    DataColumn(label: Text('Amount'), numeric: true),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: invoices.map((invoice) {
                    final meta = invoiceStatus(invoice.status);
                    return DataRow(
                      onSelectChanged: (_) =>
                          widget.nav.openDetail('invoice', invoice.id),
                      cells: [
                        DataCell(Text(invoice.number,
                            style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                fontWeight: FontWeight.w600))),
                        DataCell(Text(invoice.patient?.name ?? '-')),
                        DataCell(Text(formatDate(invoice.issuedAt))),
                        DataCell(Text(formatDate(invoice.dueDate))),
                        DataCell(Text(formatCurrency(invoice.amount))),
                        DataCell(StatusBadge(
                            tone: meta.tone, label: meta.label, dot: true)),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
    );
  }

  Widget _statusDropdown() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButton<String>(
        value: _status,
        underline: const SizedBox(),
        items: const [
          DropdownMenuItem(value: 'all', child: Text('All revenue')),
          DropdownMenuItem(value: 'paid', child: Text('Paid')),
          DropdownMenuItem(value: 'unpaid', child: Text('Unpaid')),
          DropdownMenuItem(value: 'partially_paid', child: Text('Partially Paid')),
          DropdownMenuItem(value: 'overdue', child: Text('Overdue')),
        ],
        onChanged: (value) {
          if (value == null) return;
          setState(() {
            _status = value;
            _future = _load();
          });
        },
      ),
    );
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _range,
    );
    if (picked == null) return;
    setState(() {
      _range = picked;
      _future = _load();
    });
  }

  Future<void> _exportCsv() async {
    final data = await _future;
    final invoices = _invoiceList(data['invoices']);
    if (invoices.isEmpty) return;
    exportCsv(
      'revenue-report.csv',
      invoices
          .map((invoice) => {
                'Invoice': invoice.number,
                'Patient': invoice.patient?.name ?? '',
                'Issued': formatDate(invoice.issuedAt),
                'Due': formatDate(invoice.dueDate),
                'Amount': invoice.amount,
                'Status': invoice.status,
                'PaidAt': invoice.paidAt != null ? formatDate(invoice.paidAt!) : '',
              })
          .toList(),
    );
  }

  double _chartInterval(List<_RevenuePoint> series) {
    final max = series.fold<double>(
      0,
      (current, point) => point.amount > current ? point.amount : current,
    );
    if (max <= 0) return 1;
    return max / 4;
  }

  List<Invoice> _invoiceList(Object? raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((item) => Invoice.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  Map<String, double> _statusTotals(Object? raw) {
    if (raw is! Map) return {};
    return raw.map((key, value) => MapEntry(
          key.toString(),
          value is num ? value.toDouble() : double.tryParse('$value') ?? 0,
        ));
  }
}

class _RevenueSummary {
  final double collected;
  final double outstanding;
  final double overdue;
  final double unpaid;
  final double partiallyPaid;
  final int invoiceCount;

  const _RevenueSummary({
    required this.collected,
    required this.outstanding,
    required this.overdue,
    required this.unpaid,
    required this.partiallyPaid,
    required this.invoiceCount,
  });

  factory _RevenueSummary.fromJson(Map<String, dynamic> json) {
    final collected = _readDouble(json, ['collected', 'paid', 'paidAmount']);
    final unpaid = _readDouble(json, ['unpaid', 'unpaidAmount']);
    final partiallyPaid =
        _readDouble(json, ['partiallyPaid', 'partially_paid']);
    final overdue = _readDouble(json, ['overdue', 'overdueAmount']);
    final outstanding = _readDouble(
      json,
      ['outstanding', 'outstandingAmount'],
      fallback: unpaid + partiallyPaid + overdue,
    );
    return _RevenueSummary(
      collected: collected,
      outstanding: outstanding,
      overdue: overdue,
      unpaid: unpaid,
      partiallyPaid: partiallyPaid,
      invoiceCount: _readInt(json, ['invoiceCount', 'invoices', 'totalInvoices']),
    );
  }

  static double _readDouble(
    Map<String, dynamic> json,
    List<String> keys, {
    double fallback = 0,
  }) {
    for (final key in keys) {
      final value = json[key];
      if (value is num) return value.toDouble();
      final parsed = double.tryParse('$value');
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  static int _readInt(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      final parsed = int.tryParse('$value');
      if (parsed != null) return parsed;
    }
    return 0;
  }
}

class _RevenuePoint {
  final String label;
  final double amount;

  const _RevenuePoint({required this.label, required this.amount});

  static List<_RevenuePoint> listFrom(Object? raw) {
    if (raw is! List) return [];
    return raw.whereType<Map>().map((item) {
      final data = item.cast<String, dynamic>();
      return _RevenuePoint(
        label: _label(data),
        amount: _amount(data),
      );
    }).toList();
  }

  static String _label(Map<String, dynamic> json) {
    final raw = json['label'] ?? json['date'] ?? json['period'] ?? '';
    if (raw is String && RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(raw)) {
      return formatDate(raw);
    }
    return raw.toString();
  }

  static double _amount(Map<String, dynamic> json) {
    for (final key in ['amount', 'revenue', 'collected', 'total']) {
      final value = json[key];
      if (value is num) return value.toDouble();
      final parsed = double.tryParse('$value');
      if (parsed != null) return parsed;
    }
    return 0;
  }
}
