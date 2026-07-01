import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../routes/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _contentCtrl;
  late final Animation<double> _pulse1;
  late final Animation<double> _pulse2;
  late final Animation<double> _contentFade;
  late final Animation<double> _contentScale;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _contentCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _pulse1 = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _pulse2 = Tween<double>(begin: 0.4, end: 0.8).animate(
      CurvedAnimation(
        parent: _pulseCtrl,
        curve: const Interval(0.2, 1.0, curve: Curves.easeInOut),
      ),
    );
    _contentFade = CurvedAnimation(
      parent: _contentCtrl,
      curve: Curves.easeOut,
    );
    _contentScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOutBack),
    );

    _contentCtrl.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 2400));
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Subtle grid pattern overlay
          CustomPaint(painter: _GridPainter()),

          // Pulsing rings behind the icon
          Center(
            child: AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (context, _) => Stack(
                alignment: Alignment.center,
                children: [
                  _PulseRing(scale: _pulse2.value, opacity: 0.06),
                  _PulseRing(scale: _pulse1.value, opacity: 0.10),
                ],
              ),
            ),
          ),

          // Main content
          Center(
            child: FadeTransition(
              opacity: _contentFade,
              child: ScaleTransition(
                scale: _contentScale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon container
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: cTeal,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: cTeal.withValues(alpha: 0.4),
                            blurRadius: 32,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.local_hospital_rounded,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'TibaSafari',
                      style: AppFonts.sora(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: cTeal.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: cTeal.withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        'DRIVER PORTAL',
                        style: AppFonts.sora(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: cTeal,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 64),
                    // Loading dots
                    _LoadingDots(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseRing extends StatelessWidget {
  final double scale;
  final double opacity;
  const _PulseRing({required this.scale, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280 * scale,
      height: 280 * scale,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: cTeal.withValues(alpha: opacity),
          width: 1.5,
        ),
      ),
    );
  }
}

class _LoadingDots extends StatefulWidget {
  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
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
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final anim = Tween<double>(begin: 0.3, end: 1.0).animate(
              CurvedAnimation(
                parent: _ctrl,
                curve: Interval(delay, delay + 0.4, curve: Curves.easeInOut),
              ),
            );
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cTeal.withValues(alpha: anim.value),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..strokeWidth = 1;
    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}
