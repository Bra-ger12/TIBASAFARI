import 'package:flutter/material.dart';
import 'package:patient_app/core/services/trip_api_service.dart';
import 'package:patient_app/core/theme/app_theme.dart';

const Color _cTeal = AppColors.primary;
const Color _cTealDark = AppColors.primaryDark;
const Color _cTealDeep = AppColors.primaryDeep;
const Color _cTealLight = AppColors.primaryExtraLight;
const Color _cBorder = AppColors.border;
const Color _cDivider = AppColors.divider;
const Color _cMuted = AppColors.textSecondary;
const Color _cMutedLight = AppColors.textMuted;
const Color _cError = AppColors.error;
const Color _cAmber = AppColors.accent;
const Color _cBg = AppColors.background;
const Color _cBlue = AppColors.secondary;

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  List<Map<String, dynamic>> _invoices = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final raw = await TripApiService.instance.getMyInvoices();
      if (mounted) {
        setState(() {
          _invoices = raw.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _isLoading = false; });
    }
  }

  String _fmtAmount(dynamic v) {
    if (v == null) return '—';
    final d = double.tryParse(v.toString()) ?? 0;
    return 'TZS ${d.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cBg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: _cDivider)),
                boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(color: _cTealLight, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.arrow_back_rounded, size: 20, color: _cTealDark),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text('My Invoices', style: AppFonts.sora(fontSize: 17, fontWeight: FontWeight.w800, color: _cTealDeep)),
                  const Spacer(),
                  IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded, color: _cTeal, size: 22),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: _cTeal))
                  : _error != null
                      ? _buildError()
                      : _invoices.isEmpty
                          ? _buildEmpty()
                          : RefreshIndicator(
                              onRefresh: _load,
                              color: _cTeal,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(20),
                                itemCount: _invoices.length,
                                itemBuilder: (ctx, i) {
                                  final inv = _invoices[i];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: _InvoiceCard(
                                      invoice: inv,
                                      fmtAmount: _fmtAmount,
                                      onTap: () => _showDetail(inv),
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(Map<String, dynamic> inv) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InvoiceDetailSheet(
        invoice: inv,
        fmtAmount: _fmtAmount,
        onPaymentSubmitted: _onPaymentSubmitted,
      ),
    );
  }

  void _onPaymentSubmitted() {
    _load();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Payment submitted for verification'),
      backgroundColor: _cTeal,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 100, height: 100,
          decoration: const BoxDecoration(color: _cTealLight, shape: BoxShape.circle),
          child: const Icon(Icons.receipt_long_rounded, size: 48, color: _cTeal),
        ),
        const SizedBox(height: 20),
        Text('No Invoices Yet', style: AppFonts.sora(fontSize: 18, fontWeight: FontWeight.w800, color: _cTealDeep)),
        const SizedBox(height: 8),
        const Text('Your invoices will appear here after trips.', style: TextStyle(fontSize: 14, color: _cMuted)),
      ]),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline_rounded, size: 54, color: _cError),
          const SizedBox(height: 16),
          Text(_error ?? 'Failed to load invoices', style: const TextStyle(fontSize: 14, color: _cMuted), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _cTeal, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Invoice Card ──────────────────────────────────────────────────────────────

class _InvoiceCard extends StatelessWidget {
  final Map<String, dynamic> invoice;
  final String Function(dynamic) fmtAmount;
  final VoidCallback onTap;
  const _InvoiceCard({required this.invoice, required this.fmtAmount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = invoice['status'] as String? ?? 'DRAFT';
    final (statusColor, statusBg) = _statusStyle(status);
    final invoiceNo = invoice['invoice_number'] as String? ?? '—';
    final total = invoice['total_amount'];
    final amountDue = invoice['amount_due'];
    final createdAt = DateTime.tryParse(invoice['created_at'] as String? ?? '');
    final dateStr = createdAt != null ? '${createdAt.day}/${createdAt.month}/${createdAt.year}' : '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cBorder, width: 1.5),
          boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(13)),
            child: Icon(_statusIcon(status), size: 22, color: statusColor),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(invoiceNo, style: AppFonts.sora(fontSize: 14, fontWeight: FontWeight.w800, color: _cTealDeep)),
            const SizedBox(height: 3),
            Text(dateStr, style: const TextStyle(fontSize: 12, color: _cMutedLight)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(fmtAmount(total), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _cTealDeep)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: statusBg, borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withValues(alpha: 0.25)),
              ),
              child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
            ),
            if (status != 'PAID' && status != 'CANCELLED' && amountDue != null) ...[
              const SizedBox(height: 3),
              Text('Due: ${fmtAmount(amountDue)}', style: const TextStyle(fontSize: 11, color: _cAmber, fontWeight: FontWeight.w600)),
            ],
          ]),
        ]),
      ),
    );
  }

  (Color, Color) _statusStyle(String status) {
    return switch (status) {
      'PAID'          => (_cTeal, const Color(0xFFEBF9F4)),
      'ISSUED'        => (_cBlue, const Color(0xFFEFF6FF)),
      'OVERDUE'       => (_cError, const Color(0xFFFFF0F0)),
      'PARTIALLY_PAID'=> (_cAmber, const Color(0xFFFFFBEB)),
      'CANCELLED'     => (_cMuted, const Color(0xFFF5F5F5)),
      _               => (_cMutedLight, const Color(0xFFF8F8F8)),
    };
  }

  IconData _statusIcon(String status) {
    return switch (status) {
      'PAID'           => Icons.check_circle_rounded,
      'ISSUED'         => Icons.receipt_rounded,
      'OVERDUE'        => Icons.warning_rounded,
      'PARTIALLY_PAID' => Icons.payments_rounded,
      'CANCELLED'      => Icons.cancel_rounded,
      _                => Icons.receipt_long_rounded,
    };
  }
}

// ── Invoice Detail Sheet ──────────────────────────────────────────────────────

class _InvoiceDetailSheet extends StatelessWidget {
  final Map<String, dynamic> invoice;
  final String Function(dynamic) fmtAmount;
  final VoidCallback onPaymentSubmitted;
  const _InvoiceDetailSheet({
    required this.invoice,
    required this.fmtAmount,
    required this.onPaymentSubmitted,
  });

  double _asDouble(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;

  bool get _hasPendingPayment {
    final payments = invoice['payments'];
    if (payments is! List) return false;
    return payments.any((p) => p is Map && p['status'] == 'PENDING');
  }

  Future<void> _openPaymentSheet(BuildContext context, double amountDue) async {
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SubmitPaymentSheet(
        invoiceId: invoice['id'].toString(),
        amountDue: amountDue,
      ),
    );
    if (submitted == true && context.mounted) {
      Navigator.pop(context);
      onPaymentSubmitted();
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoiceNo = invoice['invoice_number'] as String? ?? '—';
    final status = invoice['status'] as String? ?? 'DRAFT';
    final baseFare = invoice['base_fare'];
    final distanceCharge = invoice['distance_charge'];
    final timeCharge = invoice['time_charge'];
    final wheelchairSurcharge = invoice['wheelchair_surcharge'];
    final discount = invoice['discount'];
    final taxAmount = invoice['tax_amount'];
    final total = invoice['total_amount'];
    final amountPaid = invoice['amount_paid'];
    final amountDue = invoice['amount_due'];
    final notes = invoice['notes'] as String? ?? '';
    final canPay = !const {'PAID', 'CANCELLED', 'REFUNDED'}.contains(status) &&
        _asDouble(amountDue) > 0;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: _cBorder, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            // Invoice header
            Row(children: [
              Container(
                width: 52, height: 52,
                decoration: const BoxDecoration(color: _cTealLight, borderRadius: BorderRadius.all(Radius.circular(16))),
                child: const Icon(Icons.receipt_long_rounded, size: 28, color: _cTeal),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(invoiceNo, style: AppFonts.sora(fontSize: 18, fontWeight: FontWeight.w800, color: _cTealDeep)),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(color: _cTealLight, borderRadius: BorderRadius.circular(8)),
                  child: Text(status, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _cTeal)),
                ),
              ])),
            ]),
            const SizedBox(height: 20),
            const Divider(color: _cDivider),
            const SizedBox(height: 16),

            // Line items
            _LineItem('Base Fare', fmtAmount(baseFare)),
            if (_nonZero(distanceCharge)) _LineItem('Distance Charge', fmtAmount(distanceCharge)),
            if (_nonZero(timeCharge)) _LineItem('Time Charge', fmtAmount(timeCharge)),
            if (_nonZero(wheelchairSurcharge)) _LineItem('Wheelchair Surcharge', fmtAmount(wheelchairSurcharge)),
            if (_nonZero(discount)) _LineItem('Discount', '-${fmtAmount(discount)}', color: _cTeal),
            if (_nonZero(taxAmount)) _LineItem('Tax', fmtAmount(taxAmount)),
            const Divider(color: _cDivider, height: 24),
            _LineItem('Total', fmtAmount(total), bold: true),
            if (_nonZero(amountPaid)) _LineItem('Amount Paid', fmtAmount(amountPaid), color: _cTeal),
            if (_nonZero(amountDue)) _LineItem('Amount Due', fmtAmount(amountDue), bold: true, color: _cAmber),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _cBg, borderRadius: BorderRadius.circular(10)),
                child: Text(notes, style: const TextStyle(fontSize: 13, color: _cMuted)),
              ),
            ],
            if (_hasPendingPayment) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _cAmber.withValues(alpha: 0.3)),
                ),
                child: const Row(children: [
                  Icon(Icons.hourglass_top_rounded, size: 16, color: _cAmber),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Payment submitted — pending verification',
                        style: TextStyle(fontSize: 12.5, color: _cAmber, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 20),
            if (canPay && !_hasPendingPayment) ...[
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => _openPaymentSheet(context, _asDouble(amountDue)),
                  icon: const Icon(Icons.payments_rounded, size: 18),
                  label: const Text('Pay Now', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _cTeal, foregroundColor: Colors.white, elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity, height: 50,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _cTealDeep,
                  side: const BorderSide(color: _cBorder),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Close', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  bool _nonZero(dynamic v) {
    if (v == null) return false;
    return (double.tryParse(v.toString()) ?? 0) > 0;
  }
}

// ── Submit Payment Sheet ──────────────────────────────────────────────────────

class _SubmitPaymentSheet extends StatefulWidget {
  final String invoiceId;
  final double amountDue;
  const _SubmitPaymentSheet({required this.invoiceId, required this.amountDue});

  @override
  State<_SubmitPaymentSheet> createState() => _SubmitPaymentSheetState();
}

class _SubmitPaymentSheetState extends State<_SubmitPaymentSheet> {
  static const _methods = [
    ('CASH', 'Cash', Icons.payments_rounded),
    ('MOBILE_MONEY', 'M-Pesa / Mobile Money', Icons.smartphone_rounded),
    ('BANK_TRANSFER', 'Bank Transfer', Icons.account_balance_rounded),
    ('CARD', 'Card', Icons.credit_card_rounded),
  ];

  late final TextEditingController _amountCtrl;
  final _referenceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _method = 'MOBILE_MONEY';
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(text: widget.amountDue.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _referenceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    if (_method != 'CASH' && _referenceCtrl.text.trim().isEmpty) {
      setState(() => _error = 'A payment reference (e.g. M-Pesa code) is required');
      return;
    }

    setState(() { _isSubmitting = true; _error = null; });
    try {
      await TripApiService.instance.submitPayment(
        invoiceId: widget.invoiceId,
        amount: amount,
        method: _method,
        reference: _referenceCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 32),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: _cBorder, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Text('Submit Payment', style: AppFonts.sora(fontSize: 18, fontWeight: FontWeight.w800, color: _cTealDeep)),
              const SizedBox(height: 6),
              const Text(
                "Paid outside the app? Let us know how and we'll verify it against your invoice.",
                style: TextStyle(fontSize: 13, color: _cMuted, height: 1.4),
              ),
              const SizedBox(height: 20),

              const Text('Payment Method', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _cMuted)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _methods.map((m) {
                  final selected = _method == m.$1;
                  return ChoiceChip(
                    avatar: Icon(m.$3, size: 16, color: selected ? Colors.white : _cMuted),
                    label: Text(m.$2),
                    selected: selected,
                    onSelected: (_) => setState(() => _method = m.$1),
                    selectedColor: _cTeal,
                    backgroundColor: _cBg,
                    labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : _cTealDeep),
                    side: BorderSide(color: selected ? _cTeal : _cBorder),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              _field(label: 'Amount (TZS)', ctrl: _amountCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              const SizedBox(height: 14),
              if (_method != 'CASH') ...[
                _field(label: 'Payment Reference', ctrl: _referenceCtrl, hint: 'e.g. M-Pesa confirmation code'),
                const SizedBox(height: 14),
              ],
              _field(label: 'Notes (optional)', ctrl: _notesCtrl, maxLines: 2),

              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _cError.withValues(alpha: 0.3)),
                  ),
                  child: Text(_error!, style: const TextStyle(color: _cError, fontSize: 12.5)),
                ),
              ],

              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _cTeal, foregroundColor: Colors.white, elevation: 0,
                    disabledBackgroundColor: _cBorder,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('Submit Payment', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController ctrl,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _cMuted)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _cMutedLight, fontSize: 13),
            filled: true, fillColor: _cBg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          style: const TextStyle(fontWeight: FontWeight.w600, color: _cTealDeep),
        ),
      ],
    );
  }
}

class _LineItem extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;
  const _LineItem(this.label, this.value, {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? _cTealDeep;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: bold ? _cTealDeep : _cMuted, fontWeight: bold ? FontWeight.w700 : FontWeight.w500))),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: c)),
      ]),
    );
  }
}
