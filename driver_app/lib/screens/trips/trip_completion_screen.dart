import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';

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

  final GlobalKey _signatureBoundaryKey = GlobalKey();
  final List<Offset?> _signaturePoints = [];
  File? _proofPhoto;

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

  Future<File?> _exportSignature() async {
    if (_signaturePoints.isEmpty) return null;
    final boundary = _signatureBoundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;
    final file = File(
      '${Directory.systemTemp.path}/signature_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    return file.writeAsBytes(byteData.buffer.asUint8List());
  }

  Future<void> _capturePhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() => _proofPhoto = File(picked.path));
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final signatureFile = await _exportSignature();
      await DriverService.instance.completeTrip(
        tripId: widget.trip.id,
        distanceKm: double.tryParse(_distanceCtrl.text.trim()),
        durationMinutes: int.tryParse(_durationCtrl.text.trim()),
        signature: signatureFile,
        proofPhoto: _proofPhoto,
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
                    const SizedBox(height: 20),
                    _buildProofPhotoSection(),
                    const SizedBox(height: 20),
                    _buildSignatureSection(),
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

  Widget _buildProofPhotoSection() {
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
          Text('Proof of Drop-off (optional)',
              style: AppFonts.sora(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (_proofPhoto != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(_proofPhoto!, height: 160, width: double.infinity, fit: BoxFit.cover),
            ),
          if (_proofPhoto != null) const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _capturePhoto,
            icon: Icon(_proofPhoto == null ? Icons.photo_camera_rounded : Icons.replay_rounded, size: 18),
            label: Text(_proofPhoto == null ? 'Take Photo' : 'Retake Photo'),
            style: OutlinedButton.styleFrom(
              foregroundColor: cTealDark,
              side: const BorderSide(color: cBorder),
              minimumSize: const Size.fromHeight(44),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureSection() {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Patient Signature (optional)',
                  style: AppFonts.sora(fontSize: 14, fontWeight: FontWeight.w800)),
              TextButton(
                onPressed: _signaturePoints.isEmpty
                    ? null
                    : () => setState(() => _signaturePoints.clear()),
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RepaintBoundary(
            key: _signatureBoundaryKey,
            child: Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cBorder),
              ),
              child: GestureDetector(
                onPanStart: (details) {
                  setState(() => _signaturePoints.add(details.localPosition));
                },
                onPanUpdate: (details) {
                  setState(() => _signaturePoints.add(details.localPosition));
                },
                onPanEnd: (_) => setState(() => _signaturePoints.add(null)),
                child: CustomPaint(
                  painter: _SignaturePainter(_signaturePoints),
                  size: Size.infinite,
                ),
              ),
            ),
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

class _SignaturePainter extends CustomPainter {
  final List<Offset?> points;
  _SignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = cText
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      if (p1 != null && p2 != null) {
        canvas.drawLine(p1, p2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
