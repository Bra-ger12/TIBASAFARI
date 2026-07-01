import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/format.dart';
import '../widgets/data_table.dart';
import '../widgets/status_badge.dart';
import '../widgets/shared.dart';
import '../widgets/nav.dart';

class BillingInvoicesScreen extends StatefulWidget {
  final NavState nav;
  const BillingInvoicesScreen({super.key, required this.nav});
  @override
  State<BillingInvoicesScreen> createState() => _BillingInvoicesScreenState();
}

class _BillingInvoicesScreenState extends State<BillingInvoicesScreen> {
  late Future<List<Invoice>> _future;
  String _status = 'all';
  String _search = '';
  
  @override
  void initState() {
    super.initState();
    _future = _load();
  }
  
  Future<List<Invoice>> _load() async {
    final path = _status == 'all'
        ? '/billing/invoices/'
        : '/billing/invoices/?status=${_status.toUpperCase()}';
    final items = await ApiService.list(path);
    return items.map(Invoice.fromJson).toList();
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Invoices',
      description: 'Billing overview and invoice management.',
      actions: [_statusDropdown()],
      child: FutureBuilder<List<Invoice>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const LoadingRows();
          }
          final invoices = snap.data ?? [];
          final collected = invoices
              .where((i) => i.status == 'paid')
              .fold(0.0, (s, i) => s + i.amount);
          final outstanding = invoices
              .where((i) => i.status != 'paid')
              .fold(0.0, (s, i) => s + i.amount);
          var rows = invoices;
          if (_search.isNotEmpty) {
            final q = _search.toLowerCase();
            rows = rows
                .where((i) =>
                    i.number.toLowerCase().contains(q) ||
                    (i.patient?.name.toLowerCase().contains(q) ?? false))
                .toList();
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(builder: (context, c) {
                final cols = c.maxWidth > 700 ? 3 : 1;
                return GridView.count(
                  crossAxisCount: cols,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.4,
                  children: [
                    _summaryCard(Icons.account_balance_wallet, 'Collected',
                        formatCurrency(collected), AppTheme.primary),
                    _summaryCard(Icons.receipt, 'Outstanding',
                        formatCurrency(outstanding), const Color(0xFFF59E0B)),
                    _summaryCard(Icons.receipt_long, 'Total Invoices',
                        invoices.length.toString(), const Color(0xFF7C3AED)),
                  ],
                );
              }),
              const SizedBox(height: 16),
              SearchField(
                  hintText: 'Search invoices...',
                  onChanged: (v) => setState(() => _search = v)),
              const SizedBox(height: 16),
              DataTable2<Invoice>(
                columns: const [
                  DataColumn2(label: 'Invoice', key: 'number', width: 140),
                  DataColumn2(label: 'Patient', key: 'patient', width: 160),
                  DataColumn2(label: 'Issued', key: 'issued', width: 120, hideOnSmall: true),
                  DataColumn2(label: 'Due', key: 'due', width: 110, hideOnSmall: true),
                  DataColumn2(label: 'Amount', key: 'amount', width: 110, numeric: true),
                  DataColumn2(label: 'Status', key: 'status', width: 110),
                ],
                rows: rows,
                rowKey: (i) => i.id,
                onRowTap: (i) => widget.nav.openDetail('invoice', i.id),
                cellValues: (i) => [
                  Text(i.number,
                      style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF7C3AED))),
                  Text(i.patient?.name ?? '—',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500)),
                  formatDate(i.issuedAt),
                  formatDate(i.dueDate),
                  formatCurrency(i.amount),
                  () {
                    final m = invoiceStatus(i.status);
                    return StatusBadge(tone: m.tone, label: m.label, dot: true);
                  }(),
                ],
                emptyMessage: 'No invoices found.',
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryCard(IconData icon, String label, String value, Color accent) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1), // ✅ FIXED
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 20),
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
                Text(value,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ]),
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
          DropdownMenuItem(value: 'all', child: Text('All invoices')),
          DropdownMenuItem(value: 'unpaid', child: Text('Unpaid')),
          DropdownMenuItem(
              value: 'partially_paid', child: Text('Partially Paid')),
          DropdownMenuItem(value: 'paid', child: Text('Paid')),
          DropdownMenuItem(value: 'overdue', child: Text('Overdue')),
        ],
        onChanged: (v) {
          if (v == null) return;
          setState(() => _status = v);
          _future = _load();
        },
      ),
    );
  }
}