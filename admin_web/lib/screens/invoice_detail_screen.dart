import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/format.dart';
import '../widgets/status_badge.dart';
import '../widgets/shared.dart';
import '../widgets/nav.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final NavState nav;
  const InvoiceDetailScreen({super.key, required this.nav});
  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  late Future<Map<String, dynamic>> _future;
  String? _newStatus;
  bool _saving = false;
  
  @override
  void initState() {
    super.initState();
    _future = _load();
  }
  
  Future<Map<String, dynamic>> _load() async {
    return ApiService.get('/billing/invoices/${widget.nav.selectedInvoiceId}/');
  }

  Future<void> _update() async {
    if (_newStatus == null) return;
    setState(() => _saving = true);
    try {
      await ApiService.patch(
          '/billing/invoices/${widget.nav.selectedInvoiceId}/',
          {'status': _newStatus!.toUpperCase()});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invoice status updated.')));
        setState(() {
          _newStatus = null;
          _future = _load();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const LoadingRows();
        }
        if (snap.hasError || snap.data == null) {
          return ErrorState(
            message: '${snap.error ?? 'Unknown error'}',
            onRetry: () => setState(() => _future = _load()),
          );
        }
        // ApiService unwraps the envelope, so snap.data is the invoice dict directly.
        final inv = Invoice.fromJson(snap.data!);
        final meta = invoiceStatus(inv.status);
        return PageScaffold(
          title: inv.number,
          description: 'Issued ${formatDate(inv.issuedAt)}',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => widget.nav.navigate(ViewKey.billingInvoices),
          ),
          actions: [StatusBadge(tone: meta.tone, label: meta.label, dot: true)],
          child: LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth > 900;
            final left = _left(inv);
            final right = _right(inv);
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: left),
                  const SizedBox(width: 16),
                  Expanded(flex: 1, child: right),
                ],
              );
            }
            return Column(children: [left, const SizedBox(height: 16), right]);
          }),
        );
      },
    );
  }

  Widget _left(Invoice inv) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionCard(
          title: 'Invoice Breakdown',
          child: Column(
            children: [
              for (final line in inv.breakdown) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(line.label,
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.textMuted)),
                    Text(formatCurrency(line.amount),
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
                const Divider(height: 16, color: AppTheme.border),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  Text(formatCurrency(inv.amount),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _right(Invoice inv) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionCard(
          title: 'Patient',
          child: inv.patient == null
              ? const Text('—')
              : InkWell(
                  onTap: () =>
                      widget.nav.openDetail('patient', inv.patient!.id),
                  child: Row(children: [
                    AvatarCircle(
                        name: inv.patient!.name, color: AppTheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(inv.patient!.name,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                          Text(inv.patient!.phone,
                              style: const TextStyle(
                                  fontSize: 12, color: AppTheme.textMuted)),
                        ])),
                  ]),
                ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Payment',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InfoRow(
                  label: 'Due Date',
                  value: Text(formatDate(inv.dueDate))),
              const SizedBox(height: 12),
              InfoRow(
                  label: 'Paid On',
                  value: Text(inv.paidAt != null
                      ? formatDate(inv.paidAt!)
                      : 'Not paid yet')),
              const SizedBox(height: 12),
              InfoRow(
                  label: 'Current Status',
                  value: StatusBadge(
                      tone: invoiceStatus(inv.status).tone,
                      label: invoiceStatus(inv.status).label,
                      dot: true)),
            ],
          ),
        ),
        if (inv.status != 'paid') ...[
          const SizedBox(height: 16),
          SectionCard(
            title: 'Update Payment Status',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _newStatus,  // ✅ FIXED - use initialValue
                  decoration: const InputDecoration(
                      labelText: 'New status',
                      border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(
                        value: 'paid', child: Text('Paid')),
                    DropdownMenuItem(
                        value: 'partially_paid',
                        child: Text('Partially Paid')),
                    DropdownMenuItem(
                        value: 'overdue', child: Text('Overdue')),
                    DropdownMenuItem(
                        value: 'unpaid', child: Text('Unpaid')),
                  ],
                  onChanged: (v) => setState(() => _newStatus = v),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving || _newStatus == null ? null : _update,
                  style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      minimumSize: const Size.fromHeight(40)),
                  child: _saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Update Status'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}