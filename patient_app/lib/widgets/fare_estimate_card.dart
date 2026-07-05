import 'package:flutter/material.dart';
import 'package:patient_app/core/services/fare_service.dart';
import 'package:patient_app/core/theme/app_theme.dart';
import 'package:patient_app/models/fare_breakdown.dart';

const Color _cTeal = AppColors.primary;
const Color _cTealDeep = AppColors.primaryDeep;
const Color _cMuted = AppColors.textSecondary;
const Color _cBorder = AppColors.border;
const Color _cError = AppColors.error;
const Color _cAmber = AppColors.accent;

String _formatTzs(double v) => 'TSh ${v.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+\.)'),
      (m) => '${m[1]},',
    )}';

/// Fetches and displays a fare estimate for the given trip parameters.
/// Wired into book_ride.dart's Route/mobility selections; [onEstimate]
/// lets the booking screen capture the latest quote to submit alongside
/// the trip so it's persisted as Trip.estimated_fare/estimated_fare_breakdown.
class FareEstimateSection extends StatefulWidget {
  final double pickupLat;
  final double pickupLng;
  final double destLat;
  final double destLng;
  final String serviceType;
  final int waitingMinutes;
  final DateTime? scheduledAt;
  final ValueChanged<FareBreakdown>? onEstimate;

  const FareEstimateSection({
    super.key,
    required this.pickupLat,
    required this.pickupLng,
    required this.destLat,
    required this.destLng,
    this.serviceType = 'basic',
    this.waitingMinutes = 0,
    this.scheduledAt,
    this.onEstimate,
  });

  @override
  State<FareEstimateSection> createState() => _FareEstimateSectionState();
}

class _FareEstimateSectionState extends State<FareEstimateSection> {
  FareBreakdown? _breakdown;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant FareEstimateSection old) {
    super.didUpdateWidget(old);
    if (old.pickupLat != widget.pickupLat ||
        old.pickupLng != widget.pickupLng ||
        old.destLat != widget.destLat ||
        old.destLng != widget.destLng ||
        old.serviceType != widget.serviceType ||
        old.waitingMinutes != widget.waitingMinutes ||
        old.scheduledAt != widget.scheduledAt) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final breakdown = await FareService.instance.estimateFare(
        pickupLat: widget.pickupLat,
        pickupLng: widget.pickupLng,
        destLat: widget.destLat,
        destLng: widget.destLng,
        serviceType: widget.serviceType,
        waitingMinutes: widget.waitingMinutes,
        scheduledAt: widget.scheduledAt,
      );
      if (mounted) setState(() => _breakdown = breakdown);
      widget.onEstimate?.call(breakdown);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: _cTeal),
          ),
        ),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(_error!,
                  style: const TextStyle(color: _cError, fontSize: 12.5)),
            ),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_breakdown == null) return const SizedBox.shrink();
    return FareEstimateCard(breakdown: _breakdown!);
  }
}

/// Pure display widget — pass an already-fetched [FareBreakdown].
class FareEstimateCard extends StatelessWidget {
  final FareBreakdown breakdown;
  const FareEstimateCard({super.key, required this.breakdown});

  @override
  Widget build(BuildContext context) {
    final b = breakdown;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Estimated Fare',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: _cMuted)),
              Text(_formatTzs(b.totalFare),
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _cTealDeep)),
            ],
          ),
          const SizedBox(height: 4),
          Text('${b.distanceKm.toStringAsFixed(2)} km',
              style: const TextStyle(fontSize: 12, color: _cMuted)),
          const SizedBox(height: 12),
          const Divider(height: 1, color: _cBorder),
          const SizedBox(height: 12),
          _line('Base fare', b.baseFare),
          _line('Distance', b.distanceCharge),
          if (b.waitingMinutes > 0)
            _line('Waiting (${b.waitingMinutes} min)', b.waitingCharge),
          if (b.serviceMultiplier != 1.0)
            _line(
              '${_serviceTypeLabel(b.serviceType)} (×${b.serviceMultiplier.toStringAsFixed(2)})',
              b.subtotalAfterMultiplier -
                  (b.baseFare + b.distanceCharge + b.waitingCharge),
            ),
          if (b.isPeakHour) _line('Peak hour surcharge', b.peakSurchargeAmount),
          if (b.isUrbanZone) _line('City center surcharge', b.zoneSurchargeAmount),
          const SizedBox(height: 8),
          if (b.isPeakHour || b.isUrbanZone)
            Wrap(
              spacing: 6,
              children: [
                if (b.isPeakHour) _badge('Peak hour', _cAmber),
                if (b.isUrbanZone) _badge('City center', _cTeal),
              ],
            ),
        ],
      ),
    );
  }

  String _serviceTypeLabel(String type) => switch (type) {
        'wheelchair' => 'Wheelchair service',
        'medical_equipment' => 'Medical equipment',
        _ => 'Basic service',
      };

  Widget _line(String label, double amount) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12.5, color: _cMuted)),
            Text(_formatTzs(amount),
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _cTealDeep)),
          ],
        ),
      );

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
      );
}
