import 'package:flutter/material.dart';
import '../models/models.dart';

class LiveMap extends StatelessWidget {
  final List<ActiveTripMapItem> trips;
  final double height;
  const LiveMap({super.key, required this.trips, this.height = 320});

  // Dar es Salaam bounds
  static const double minLat = -6.95;
  static const double maxLat = -6.65;
  static const double minLng = 39.18;
  static const double maxLng = 39.38;

  Offset _project(double lat, double lng, Size size) {
    final x = ((lng - minLng) / (maxLng - minLng)) * size.width;
    final y = (1 - (lat - minLat) / (maxLat - minLat)) * size.height;
    return Offset(x, y);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF0F1B2D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          CustomPaint(
            size: Size.infinite,
            painter: _MapPainter(trips, _project),
          ),
          // Live indicator
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.85),  // ✅ FIXED
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),  // ✅ FIXED
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PulseDot(),
                  const SizedBox(width: 6),
                  Text(
                    'Live · ${trips.length} active ${trips.length == 1 ? "vehicle" : "vehicles"}',
                    style: const TextStyle(
                      color: Color(0xFFE2E8F0),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Legend
          Positioned(
            bottom: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.85),  // ✅ FIXED
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),  // ✅ FIXED
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _legendDot(const Color(0xFF0EA5E9), 'Active vehicle'),
                  const SizedBox(height: 4),
                  _legendDot(const Color(0xFF34D399), 'Pickup origin'),
                ],
              ),
            ),
          ),
          if (trips.isEmpty)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_hospital, color: Color(0xFF475569), size: 32),
                  SizedBox(height: 8),
                  Text('No active trips on the map right now.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 10)),
      ],
    );
  }
}

class _PulseDot extends StatefulWidget {
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with TickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        return SizedBox(
          width: 12,
          height: 12,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 12 * t,
                height: 12 * t,
                decoration: BoxDecoration(
                  color: const Color(0xFF34D399).withValues(alpha: 0.4 * (1 - t)),  // ✅ FIXED
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MapPainter extends CustomPainter {
  final List<ActiveTripMapItem> trips;
  final Offset Function(double, double, Size) project;
  _MapPainter(this.trips, this.project);

  @override
  void paint(Canvas canvas, Size size) {
    // Land base gradient
    final landPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFF13263D), const Color(0xFF0C1A2C)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), landPaint);

    // Ocean (south-east)
    final oceanPath = Path()
      ..moveTo(size.width, size.height * 0.45)
      ..cubicTo(
        size.width * 0.7,
        size.height * 0.5,
        size.width * 0.55,
        size.height * 0.62,
        size.width * 0.62,
        size.height * 0.78,
      )
      ..cubicTo(
        size.width * 0.66,
        size.height * 0.88,
        size.width * 0.8,
        size.height * 0.95,
        size.width,
        size.height * 0.92,
      )
      ..close();
    canvas.drawPath(
        oceanPath,
        Paint()
          ..shader = LinearGradient(
            colors: [const Color(0xFF1B3A5B), const Color(0xFF13283F)],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));

    // Grid
    final gridPaint = Paint()
      ..color = const Color(0xFF1E3A5F)
      ..strokeWidth = 0.5;
    for (int i = 1; i < 10; i++) {
      final x = size.width * i / 10;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (int i = 1; i < 6; i++) {
      final y = size.height * i / 6;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Roads (stylized)
    final roadPaint = Paint()
      ..color = const Color(0xFF24425F)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final roads = [
      [
        Offset(-10, size.height * 0.75),
        Offset(size.width * 0.2, size.height * 0.67),
        Offset(size.width * 0.4, size.height * 0.62),
        Offset(size.width * 0.65, size.height * 0.54),
        Offset(size.width * 0.9, size.height * 0.42),
        Offset(size.width + 10, size.height * 0.42),
      ],
      [
        Offset(size.width * 0.15, -10),
        Offset(size.width * 0.18, size.height * 0.25),
        Offset(size.width * 0.22, size.height * 0.5),
        Offset(size.width * 0.28, size.height * 0.75),
        Offset(size.width * 0.32, size.height + 10),
      ],
      [
        Offset(-10, size.height * 0.25),
        Offset(size.width * 0.25, size.height * 0.29),
        Offset(size.width * 0.45, size.height * 0.23),
        Offset(size.width * 0.65, size.height * 0.31),
        Offset(size.width + 10, size.height * 0.35),
      ],
    ];
    for (final pts in roads) {
      final path = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (int i = 1; i < pts.length - 1; i++) {
        final mid = Offset((pts[i].dx + pts[i + 1].dx) / 2,
            (pts[i].dy + pts[i + 1].dy) / 2);
        path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
      }
      path.lineTo(pts.last.dx, pts.last.dy);
      roadPaint.strokeWidth = 14;
      canvas.drawPath(path, roadPaint);
      roadPaint.strokeWidth = 2;
      roadPaint.color = const Color(0xFF2F5478);
      canvas.drawPath(path, roadPaint);
      roadPaint.color = const Color(0xFF24425F);
    }

    // Pickup origin dots
    for (final t in trips) {
      final p = project(t.lat, t.lng, size);
      canvas.drawCircle(p, 3, Paint()..color = const Color(0xFF34D399).withValues(alpha: 0.7));  // ✅ FIXED
    }

    // Vehicle markers — live position once known, else the pickup point
    for (final t in trips) {
      final p = project(t.vehicleLat ?? t.lat, t.vehicleLng ?? t.lng, size);
      // pulse ring
      canvas.drawCircle(
          p, 16, Paint()..color = const Color(0xFF38BDF8).withValues(alpha: 0.15));  // ✅ FIXED
      // outer
      canvas.drawCircle(
          p,
          11,
          Paint()
            ..color = const Color(0xFF0EA5E9)
            ..style = PaintingStyle.fill);
      canvas.drawCircle(
          p,
          11,
          Paint()
            ..color = const Color(0xFFE0F2FE)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) => old.trips != trips;
}

// ✅ REMOVED unused _lerp function