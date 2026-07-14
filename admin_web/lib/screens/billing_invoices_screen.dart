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
  late Future<_FinanceData> _future;
  String _status = 'all';
  String _search = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_FinanceData> _load() async {
    final path = _status == 'all'
        ? '/billing/invoices/'
        : '/billing/invoices/?status=${_status.toUpperCase()}';
    final invoiceItems = await ApiService.list(path);
    final expenseItems =
        await ApiService.list('/operations/vehicle-expenses/');
    final vehicleItems = await ApiService.list('/operations/vehicles/');
    return _FinanceData(
      invoices: invoiceItems.map(Invoice.fromJson).toList(),
      expenses: expenseItems.map(VehicleExpense.fromJson).toList(),
      vehicles: vehicleItems.map(Vehicle.fromJson).toList(),
    );
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _addExpense(List<Vehicle> vehicles) async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => _AddExpenseDialog(vehicles: vehicles),
    );
    if (added == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Finance',
      description: 'Billing, collected revenue and vehicle maintenance costs.',
      actions: [_statusDropdown()],
      child: FutureBuilder<_FinanceData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const LoadingRows();
          }
          final data = snap.data ?? _FinanceData.empty();
          final invoices = data.invoices;
          final collected = invoices
              .where((i) => i.status == 'paid')
              .fold(0.0, (s, i) => s + i.amount);
          final maintenanceCost =
              data.expenses.fold(0.0, (s, e) => s + e.amount);
          final totalRevenue = collected - maintenanceCost;
          var rows = invoices;
          if (_search.isNotEmpty) {
            final q = _search.toLowerCase();
            rows = rows
                .where((i) =>
                    i.number.toLowerCase().contains(q) ||
                    (i.patient?.name.toLowerCase().contains(q) ?? false))
                .toList();
          }
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(builder: (context, c) {
                  final cols = c.maxWidth > 900
                      ? 4
                      : c.maxWidth > 500
                          ? 2
                          : 1;
                  return GridView.count(
                    crossAxisCount: cols,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.4,
                    children: [
                      _summaryCard(Icons.account_balance_wallet,
                          'Collected Driver Revenue',
                          formatCurrency(collected), AppTheme.primary),
                      _summaryCard(Icons.build_circle, 'Maintenance Cost',
                          formatCurrency(maintenanceCost),
                          const Color(0xFFF59E0B)),
                      _summaryCard(
                          Icons.trending_up,
                          'Total Revenue',
                          formatCurrency(totalRevenue),
                          totalRevenue >= 0
                              ? AppTheme.primary
                              : const Color(0xFFDC2626)),
                      _summaryCard(Icons.receipt_long, 'Total Invoices',
                          invoices.length.toString(), const Color(0xFF7C3AED)),
                    ],
                  );
                }),
                const SizedBox(height: 24),
                SectionCard(
                  title: 'Invoices',
                  padding: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SearchField(
                            hintText: 'Search invoices...',
                            onChanged: (v) => setState(() => _search = v)),
                        const SizedBox(height: 16),
                        DataTable2<Invoice>(
                          columns: const [
                            DataColumn2(
                                label: 'Invoice', key: 'number', width: 140),
                            DataColumn2(
                                label: 'Patient', key: 'patient', width: 160),
                            DataColumn2(
                                label: 'Issued',
                                key: 'issued',
                                width: 120,
                                hideOnSmall: true),
                            DataColumn2(
                                label: 'Due',
                                key: 'due',
                                width: 110,
                                hideOnSmall: true),
                            DataColumn2(
                                label: 'Amount',
                                key: 'amount',
                                width: 110,
                                numeric: true),
                            DataColumn2(
                                label: 'Status', key: 'status', width: 110),
                          ],
                          rows: rows,
                          rowKey: (i) => i.id,
                          onRowTap: (i) => widget.nav.openDetail('invoice', i.id),
                          cellValues: (i) => [
                            Text(i.number,
                                style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF7C3AED))),
                            Text(i.patient?.name ?? '—',
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w500)),
                            formatDate(i.issuedAt),
                            formatDate(i.dueDate),
                            formatCurrency(i.amount),
                            () {
                              final m = invoiceStatus(i.status);
                              return StatusBadge(
                                  tone: m.tone, label: m.label, dot: true);
                            }(),
                          ],
                          emptyMessage: 'No invoices found.',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SectionCard(
                  title: 'Vehicle Maintenance Costs',
                  padding: EdgeInsets.zero,
                  action: TextButton.icon(
                    onPressed: () => _addExpense(data.vehicles),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Expense'),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: data.expenses.isEmpty
                        ? const Text('No maintenance costs recorded yet.',
                            style: TextStyle(
                                fontSize: 13, color: AppTheme.textMuted))
                        : DataTable2<VehicleExpense>(
                            columns: const [
                              DataColumn2(
                                  label: 'Vehicle', key: 'vehicle', width: 140),
                              DataColumn2(
                                  label: 'Category', key: 'category', width: 120),
                              DataColumn2(
                                  label: 'Description',
                                  key: 'description',
                                  width: 200,
                                  hideOnSmall: true),
                              DataColumn2(
                                  label: 'Date',
                                  key: 'date',
                                  width: 110,
                                  hideOnSmall: true),
                              DataColumn2(
                                  label: 'Amount',
                                  key: 'amount',
                                  width: 110,
                                  numeric: true),
                            ],
                            rows: data.expenses,
                            rowKey: (e) => e.id,
                            cellValues: (e) => [
                              Text(e.vehicleRegistration,
                                  style: const TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.w500)),
                              Text(e.category),
                              Text(
                                  e.description.isEmpty ? '—' : e.description,
                                  overflow: TextOverflow.ellipsis),
                              formatDate(e.incurredAt),
                              formatCurrency(e.amount),
                            ],
                            emptyMessage: 'No maintenance costs recorded yet.',
                          ),
                  ),
                ),
              ],
            ),
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
              color: accent.withValues(alpha: 0.1),
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
                        fontSize: 12, color: AppTheme.textMuted),
                    overflow: TextOverflow.ellipsis),
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

class _FinanceData {
  final List<Invoice> invoices;
  final List<VehicleExpense> expenses;
  final List<Vehicle> vehicles;

  _FinanceData({
    required this.invoices,
    required this.expenses,
    required this.vehicles,
  });

  factory _FinanceData.empty() =>
      _FinanceData(invoices: [], expenses: [], vehicles: []);
}

class _AddExpenseDialog extends StatefulWidget {
  final List<Vehicle> vehicles;
  const _AddExpenseDialog({required this.vehicles});

  @override
  State<_AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<_AddExpenseDialog> {
  String? _vehicleId;
  String _category = 'MAINTENANCE';
  final _amountCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  DateTime _incurredAt = DateTime.now();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final vehicleId = _vehicleId;
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (vehicleId == null || amount == null || amount <= 0) {
      setState(() => _error = 'Select a vehicle and enter a valid amount.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ApiService.post('/operations/vehicle-expenses/', {
        'vehicle': vehicleId,
        'category': _category,
        'description': _descriptionCtrl.text.trim(),
        'amount': amount,
        'incurred_at': _incurredAt.toIso8601String().substring(0, 10),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Vehicle Expense'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _vehicleId,
              decoration: const InputDecoration(labelText: 'Vehicle'),
              items: widget.vehicles
                  .map((v) => DropdownMenuItem(
                        value: v.id,
                        child: Text('${v.plate} · ${v.model}'),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _vehicleId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: const [
                DropdownMenuItem(value: 'MAINTENANCE', child: Text('Maintenance')),
                DropdownMenuItem(value: 'REPAIR', child: Text('Repair')),
                DropdownMenuItem(value: 'INSURANCE', child: Text('Insurance')),
                DropdownMenuItem(value: 'OTHER', child: Text('Other')),
              ],
              onChanged: (v) => setState(() => _category = v ?? 'MAINTENANCE'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount (TZS)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionCtrl,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: Text('Date: ${formatDate(_incurredAt.toIso8601String())}')),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _incurredAt,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _incurredAt = picked);
                  },
                  child: const Text('Change'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}
