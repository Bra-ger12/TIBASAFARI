import 'package:flutter/material.dart';

import '../../core/models/driver_session.dart';
import '../../core/theme/colors.dart';
import '../../services/driver_service.dart';

/// Submits the trip completion, including distance/duration, to the backend.
class TripCompletionScreen extends StatefulWidget {
  final DriverAssignedTrip trip;
  final double? initialDistanceKm;
  final int? initialDurationMinutes;

  const TripCompletionScreen({
    super.key,
    required this.trip,
    this.initialDistanceKm,
    this.initialDurationMinutes,
  });

  @override
  State<TripCompletionScreen> createState() => _TripCompletionScreenState();
}

class _TripCompletionScreenState extends State<TripCompletionScreen> {
  late final TextEditingController _distanceCtrl;
  late final TextEditingController _durationCtrl;

  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _distanceCtrl = TextEditingController(
      text: widget.initialDistanceKm == null
          ? ''
          : widget.initialDistanceKm!.toStringAsFixed(2),
    );
    _durationCtrl = TextEditingController(
      text: widget.initialDurationMinutes?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _distanceCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await DriverService.instance.completeTrip(
        tripId: widget.trip.id,
        distanceKm: double.tryParse(_distanceCtrl.text.trim()),
        durationMinutes: int.tryParse(_durationCtrl.text.trim()),
      );
      if (mounted) Navigator.of(context).pop(true);
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
    return Scaffold(
      backgroundColor: cBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTripSummary(),
                    const SizedBox(height: 20),
                    _buildMetricsRow(),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      _buildErrorBanner(_error!),
                    ],
                    const SizedBox(height: 24),
                    _buildSubmitButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: cSurface,
        border: Border(bottom: BorderSide(color: cBorder)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).pop(false),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 40,
              height: 40,
              decoration:
                  BoxDecoration(color: cTealLight, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.arrow_back_rounded, size: 22, color: cTealDark),
            ),
          ),
          const SizedBox(width: 14),
          Text('Complete Trip',
              style: AppFonts.sora(fontSize: 18, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildTripSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.trip.patientName,
              style: AppFonts.sora(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(widget.trip.appointmentType,
              style: const TextStyle(fontSize: 12, color: cMuted)),
          const SizedBox(height: 12),
          const Divider(color: cDivider, height: 1),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.trip_origin_rounded, size: 14, color: cBlue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(widget.trip.pickupAddress,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cText)),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.location_on_rounded, size: 14, color: cTeal),
            const SizedBox(width: 8),
            Expanded(
              child: Text(widget.trip.destination,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cText)),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildMetricsRow() {
    return Row(
      children: [
        Expanded(
          child: _metricField(
            label: 'Distance (km)',
            controller: _distanceCtrl,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _metricField(
            label: 'Duration (min)',
            controller: _durationCtrl,
          ),
        ),
      ],
    );
  }

  Widget _metricField({required String label, required TextEditingController controller}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: cSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: cMutedLight)),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 6),
            ),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: cText),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cError.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, color: cError, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: const TextStyle(color: cError, fontSize: 13))),
      ]),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: cTeal,
          foregroundColor: Colors.white,
          elevation: 0,
          disabledBackgroundColor: cBorder,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isSubmitting
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : const Text('Complete Trip',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ),
    );
  }
}
