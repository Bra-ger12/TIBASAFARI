import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/format.dart';
import '../widgets/data_table.dart';
import '../widgets/status_badge.dart';
import '../widgets/shared.dart';
import '../widgets/nav.dart';

/// Staff queue for self-reported ("submit-payment") patient payments that
/// need to be verified or rejected before they're applied to an invoice.
class PaymentsPendingScreen extends StatefulWidget {
  final NavState nav;
  const PaymentsPendingScreen({super.key, required this.nav});
  @override
  State<PaymentsPendingScreen> createState() => _PaymentsPendingScreenState();
}

class _PaymentsPendingScreenState extends State<PaymentsPendingScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  String _status = 'PENDING';
  final Set<String> _busyIds = {};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() {
    return ApiService.list('/billing/payments/?status=$_status');
  }

  void _refresh() {
    setState(() => _future = _load());
  }

  Future<void> _verify(Map<String, dynamic> payment) async {
    final id = payment['id'].toString();
    setState(() => _busyIds.add(id));
    try {
      await ApiService.post('/billing/payments/$id/verify/');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment verified and applied to invoice.')),
        );
        _refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to verify: $e')));
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  Future<void> _reject(Map<String, dynamic> payment) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject payment'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            hintText: 'e.g. Reference does not match any received transfer',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final id = payment['id'].toString();
    setState(() => _busyIds.add(id));
    try {
      await ApiService.post('/billing/payments/$id/reject/', {
        'reason': reasonController.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment rejected.')),
        );
        _refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to reject: $e')));
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Pending Payments',
      description:
          'Patient self-reported payments (e.g. mobile money transfers) awaiting verification.',
      actions: [_statusDropdown()],
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const LoadingRows();
          }
          if (snap.hasError) {
            return Center(child: Text('Failed to load: ${snap.error}'));
          }
          final rows = snap.data ?? [];
          final totalPending = rows
              .where((p) => (p['status'] ?? '').toString().toUpperCase() == 'PENDING')
              .fold(0.0, (s, p) => s + (double.tryParse('${p['amount']}') ?? 0));

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_status == 'PENDING')
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.hourglass_top_rounded,
                              color: Color(0xFFF59E0B), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Awaiting verification',
                                style: TextStyle(
                                    fontSize: 12, color: AppTheme.textMuted)),
                            Text(
                                '${rows.length} payment${rows.length == 1 ? '' : 's'} · ${formatCurrency(totalPending)}',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ]),
                    ),
                  ),
                ),
              DataTable2<Map<String, dynamic>>(
                columns: const [
                  DataColumn2(label: 'Patient', key: 'patient', width: 180),
                  DataColumn2(label: 'Invoice', key: 'invoice', width: 130),
                  DataColumn2(label: 'Method', key: 'method', width: 120, hideOnSmall: true),
                  DataColumn2(label: 'Reference', key: 'reference', width: 160, hideOnSmall: true),
                  DataColumn2(label: 'Amount', key: 'amount', width: 110, numeric: true),
                  DataColumn2(label: 'Submitted', key: 'created', width: 130, hideOnSmall: true),
                  DataColumn2(label: 'Status', key: 'status', width: 100),
                  DataColumn2(label: '', key: 'actions', width: 190),
                ],
                rows: rows,
                rowKey: (p) => p['id'].toString(),
                cellValues: (p) {
                  final busy = _busyIds.contains(p['id'].toString());
                  final isPending =
                      (p['status'] ?? '').toString().toUpperCase() == 'PENDING';
                  final meta = paymentStatus((p['status'] ?? '').toString());
                  return [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text((p['patient_name'] ?? '—').toString(),
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        Text((p['patient_email'] ?? '').toString(),
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.textMuted)),
                      ],
                    ),
                    Text((p['invoice_number'] ?? '—').toString(),
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF7C3AED))),
                    (p['method'] ?? '—').toString(),
                    (p['reference'] ?? '—').toString(),
                    formatCurrency(double.tryParse('${p['amount']}') ?? 0),
                    formatDate(p['created_at']?.toString(), withTime: true),
                    StatusBadge(tone: meta.tone, label: meta.label, dot: true),
                    isPending
                        ? Row(
                            children: [
                              if (busy)
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              else ...[
                                TextButton(
                                  onPressed: () => _verify(p),
                                  child: const Text('Verify'),
                                ),
                                TextButton(
                                  onPressed: () => _reject(p),
                                  style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFFEF4444)),
                                  child: const Text('Reject'),
                                ),
                              ],
                            ],
                          )
                        : const Text('—'),
                  ];
                },
                emptyMessage: 'No payments in this status.',
              ),
            ],
          );
        },
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
          DropdownMenuItem(value: 'PENDING', child: Text('Pending')),
          DropdownMenuItem(value: 'COMPLETED', child: Text('Completed')),
          DropdownMenuItem(value: 'FAILED', child: Text('Failed')),
          DropdownMenuItem(value: 'ALL', child: Text('All')),
        ],
        onChanged: (v) {
          if (v == null) return;
          setState(() {
            _status = v;
            _future = _load();
          });
        },
      ),
    );
  }
}
