import 'dart:async';

import 'package:flutter/material.dart';
import 'package:patient_app/core/services/notifications_ws_service.dart';
import 'package:patient_app/core/services/trip_api_service.dart';
import 'package:patient_app/models/auth_session.dart';
import 'package:patient_app/widgets/bottom_nav_bar.dart';
import 'package:patient_app/core/theme/app_theme.dart';
import 'package:patient_app/screens/billing/billing_screen.dart';
import 'package:patient_app/screens/dashboard/notification.dart';

const Color cTeal = AppColors.primary;
const Color cTealDark = AppColors.primaryDark;
const Color cTealDeep = AppColors.primaryDeep;
const Color cTealMid = AppColors.primaryLight;
const Color cTealLight = AppColors.primaryExtraLight;
const Color cBorder = AppColors.border;
const Color cDivider = AppColors.divider;
const Color cMuted = AppColors.textSecondary;
const Color cMutedLight = AppColors.textMuted;
const Color cError = AppColors.error;
const Color cAmber = AppColors.accent;
const Color cBg = AppColors.background;
const Color cBlue = AppColors.secondary;

// Pre‑defined const colors (no .withValues() in const widgets)
const Color cTealShadow = Color(0x330E7C66);
const Color cHeroShadow = Color(0x4D0E7C66);
const Color cAmberBg = Color(0xFFFBEFD9);
const Color cAmberText = Color(0xFFA56C12);
const Color cWhiteSoft = Color(0x0DFFFFFF);
const Color cWhiteBorder = Color(0x26FFFFFF);
const Color cBlackSoft = Color(0x26000000);
const Color cBlackFaint = Color(0x0D000000);

class HomeScreen extends StatefulWidget {
  final AuthSession session;
  const HomeScreen({super.key, required this.session});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  String _activeTab = 'home';
  late AuthSession _session;
  late final AnimationController _animController;
  late final List<Animation<double>> _fadeAnims;
  late final List<Animation<Offset>> _slideAnims;
  static const int _animCount = 8;
  StreamSubscription<PatientNotification>? _notifSub;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnims = List.generate(_animCount, (i) {
      final start = (i * 0.07).clamp(0.0, 0.7);
      final end = (start + 0.4).clamp(0.0, 1.0);
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _animController,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ),
      );
    });
    _slideAnims = List.generate(_animCount, (i) {
      final start = (i * 0.07).clamp(0.0, 0.7);
      final end = (start + 0.4).clamp(0.0, 1.0);
      return Tween<Offset>(
        begin: const Offset(0, 0.2),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _animController,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ),
      );
    });
    _animController.forward();
    _refreshDashboard();
    _connectNotifications();
  }

  /// Listens for the backend's real-time "Driver Assigned" push (sent by
  /// TripService.assign_driver over ws/notifications/, with driver name/
  /// phone/vehicle in metadata) so the patient sees who is coming without
  /// waiting for a manual refresh.
  Future<void> _connectNotifications() async {
    final token = await TripApiService.instance.getToken();
    if (token == null || !mounted) return;
    NotificationsWsService.instance.connect(token: token);
    _notifSub =
        NotificationsWsService.instance.notificationStream.listen((n) async {
      final tripId = n.metadata['trip_id'] as String?;
      if (tripId != null) await _refreshDashboard();
      if (!mounted) return;

      final driverName = n.metadata['driver_name'] as String?;
      final driverPhone = n.metadata['driver_phone'] as String?;
      final vehicle = n.metadata['vehicle'] as String?;
      final isDriverAssigned = driverName != null;

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          isDriverAssigned
              ? '$driverName${driverPhone != null ? ' ($driverPhone)' : ''}'
                  '${vehicle != null ? ' is coming in a $vehicle' : ' has been assigned to your trip'}.'
              : (n.title.isNotEmpty ? '${n.title}: ${n.message}' : n.message),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: cTeal,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        action: tripId != null
            ? SnackBarAction(
                label: 'Track',
                textColor: Colors.white,
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/track-ride',
                  arguments: {'rideId': tripId},
                ),
              )
            : null,
      ));
    });
  }

  Future<void> _refreshDashboard() async {
    try {
      final data = await TripApiService.instance.getPatientDashboard();
      if (!mounted) return;
      final updated = _session.copyWith(
        totalTrips: data['totalTrips'] as int?,
        tripsThisMonth: data['tripsThisMonth'] as int?,
        upcomingTrips: data['upcomingTrips'] as List<dynamic>?,
        recentTrips: data['recentTrips'] as List<dynamic>?,
      );
      await AuthSession.save(updated);
      setState(() => _session = updated);
    } catch (_) {
      // Non-fatal: keep showing whatever the session already has
    }
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    _animController.dispose();
    super.dispose();
  }

  Widget _animated(int i, Widget child) => FadeTransition(
        opacity: _fadeAnims[i],
        child: SlideTransition(position: _slideAnims[i], child: child),
      );

  void _navigateToTracking(Map<String, dynamic> trip) {
    Navigator.pushNamed(context, '/track-ride', arguments: {
      'rideId': (trip['id'] ?? '').toString(),
      'pickupLocation': (trip['pickup'] ?? '').toString(),
      'destination': (trip['destination'] ?? '').toString(),
    });
  }

  void _onTrackTapped() {
    if (_session.upcomingTrips.isNotEmpty) {
      _navigateToTracking(_session.upcomingTrips.first as Map<String, dynamic>);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No active ride to track right now.'),
        backgroundColor: cTeal,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _onTab(String tab) {
    setState(() => _activeTab = tab);
    switch (tab) {
      case 'home':
        break;
      case 'book':
        Navigator.pushNamed(context, '/book-ride');
        break;
      case 'history':
        Navigator.pushNamed(context, '/history');
        break;
      case 'profile':
        Navigator.pushNamed(context, '/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return Scaffold(
      backgroundColor: cBg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              session: session,
              notifCount: session.unreadNotifications,
              onMenu: () => Navigator.pushNamed(context, '/profile'),
              //  NAVIGATES TO NOTIFICATION PAGE
              onNotif: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _animated(
                      0,
                      Padding(
                        padding: const EdgeInsets.only(bottom: 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Hello, ${session.displayName}! ",
                              style: AppFonts.sora(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: cTealDeep,
                                height: 1.2,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              "How can we help you today?",
                              style: TextStyle(
                                fontSize: 14.5,
                                color: cMuted,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _animated(
                      1,
                      Padding(
                        padding: const EdgeInsets.only(bottom: 28),
                        child: _HeroCard(
                          onTap: () => Navigator.pushNamed(context, '/book-ride'),
                        ),
                      ),
                    ),
                    _animated(
                      2,
                      Padding(
                        padding: const EdgeInsets.only(bottom: 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionHeader(title: "Quick Actions"),
                            const SizedBox(height: 14),
                            //  PASSING NAVIGATION CALLBACKS HERE
                            _QuickActionsGrid(
                              onSchedule: () => Navigator.pushNamed(context, '/book-ride'),
                              onTrack: _onTrackTapped,
                              onHistory: () => Navigator.pushNamed(context, '/history'),
                              onBilling: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BillingScreen())),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _animated(
                      3,
                      _UnifiedStatsCard(
                        totalTrips: session.totalTrips,
                        tripsThisMonth: session.tripsThisMonth,
                        timeSaved: session.timeSaved,
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (session.upcomingTrips.isNotEmpty)
                      _animated(
                        4,
                        Padding(
                          padding: const EdgeInsets.only(bottom: 28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionHeader(title: "Upcoming Trip"),
                              const SizedBox(height: 14),
                              _UpcomingTripCard(
                                trip: session.upcomingTrips.first,
                                onViewDetails: () => _navigateToTracking(
                                    session.upcomingTrips.first as Map<String, dynamic>),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (session.recentTrips.isNotEmpty)
                      _animated(
                        5,
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionHeader(title: "Recent Trips"),
                            const SizedBox(height: 14),
                            _GroupedRecentTrips(
                              trips: session.recentTrips,
                              onTap: (trip) => Navigator.pushNamed(context, '/history'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            BottomNavBar(
              activeTab: _activeTab,
              onTab: _onTab,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── HEADER ────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final AuthSession session;
  final int notifCount;
  final VoidCallback onMenu;
  final VoidCallback onNotif;
  const _Header({
    required this.session,
    required this.notifCount,
    required this.onMenu,
    required this.onNotif,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: cDivider)),
        boxShadow: [
          BoxShadow(color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, 4)),
          BoxShadow(color: Color(0x05000000), blurRadius: 6, offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: onMenu,
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [cTeal, cTealDark]),
                borderRadius: BorderRadius.all(Radius.circular(14)),
                boxShadow: [BoxShadow(color: cTealShadow, blurRadius: 12, offset: Offset(0, 4))],
              ),
              child: Center(
                child: Text(
                  session.displayName.isNotEmpty ? session.displayName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                child: Image.asset(
                  'assets/images/tiba-safari-logo.png',
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [cTeal, cTealDark]),
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                      child: const Icon(Icons.local_hospital_rounded, size: 16, color: Colors.white),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                "Tiba Safari",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: cTealDeep,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: onNotif,
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: cBg,
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.notifications_none_rounded, size: 24, color: cTealDark),
                  if (notifCount > 0)
                    Positioned(
                      top: 5,
                      right: 5,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(
                          color: cError,
                          shape: BoxShape.circle,
                          border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2.5)),
                          boxShadow: [BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 2))],
                        ),
                        child: Center(
                          child: Text(
                            '$notifCount',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── HERO CARD ────────────────────────────────────────────────

class _HeroCard extends StatefulWidget {
  final VoidCallback onTap;
  const _HeroCard({required this.onTap});

  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOutCubic,
        child: Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(28)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [cTeal, cTealDark, Color(0xFF042F23)],
            ),
            boxShadow: [
              BoxShadow(color: cHeroShadow, blurRadius: 32, offset: Offset(0, 16)),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(28)),
            child: Stack(
              children: [
                Positioned(
                  top: -50,
                  right: -30,
                  child: Transform.rotate(
                    angle: -0.3,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: const BoxDecoration(
                        color: cWhiteSoft,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -40,
                  left: -20,
                  child: Transform.rotate(
                    angle: 0.5,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: const BoxDecoration(
                        color: cWhiteSoft,
                        borderRadius: BorderRadius.all(Radius.circular(40)),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.05),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(26),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: const BorderRadius.all(Radius.circular(20)),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 0.5),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _PulsingDot(color: Color(0xFF5DFFA5)),
                                  SizedBox(width: 8),
                                  Text(
                                    "AVAILABLE NOW",
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              "Request Medical\nTransport",
                              style: AppFonts.sora(
                                fontSize: 25,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.25,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              "Fast, reliable NEMT service\nanywhere in Tanzania",
                              style: TextStyle(
                                fontSize: 13.5,
                                color: Color(0xB3FFFFFF),
                                fontWeight: FontWeight.w500,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 26),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.all(Radius.circular(30)),
                                boxShadow: [BoxShadow(color: cBlackSoft, blurRadius: 16, offset: Offset(0, 6))],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "Book a Ride",
                                    style: AppFonts.sora(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: cTealDeep,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward_rounded, size: 18, color: cTealDark),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                     
                      Container(
                        width: 96,
                        height: 96,
                       decoration: const BoxDecoration(
  color: cError,
  shape: BoxShape.circle,
  border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2.5)),
  boxShadow: [BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 2))],
),
                        child: const Icon(
                          Icons.medical_services_rounded,
                          size: 48,
                          color: Color(0xE6FFFFFF),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── PULSING DOT ────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color}); 

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => Opacity(
        opacity: _animation.value,
        child: child,
      ),
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: widget.color.withValues(alpha: 0.5), blurRadius: 4)],
        ),
      ),
    );
  }
}

// ─── QUICK ACTIONS GRID ────────────────────────────────────────────────
// ✅ REMOVED 'const' TO ACCEPT NAVIGATION CALLBACKS

class _QuickActionsGrid extends StatelessWidget {
  final VoidCallback onSchedule;
  final VoidCallback onTrack;
  final VoidCallback onHistory;
  final VoidCallback onBilling;

  const _QuickActionsGrid({
    required this.onSchedule,
    required this.onTrack,
    required this.onHistory,
    required this.onBilling,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(22)),
        border: Border.fromBorderSide(BorderSide(color: cBorder, width: 1)),
        boxShadow: [
          BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          _QuickActionItem(
            label: 'Schedule',
            icon: Icons.calendar_month_rounded,
            bg: cTealLight,
            color: cTeal,
            onTap: onSchedule,
          ),
          const _ActionDivider(),
          _QuickActionItem(
            label: 'Track',
            icon: Icons.near_me_rounded,
            bg: cTealLight,
            color: cTeal,
            onTap: onTrack,
          ),
          const _ActionDivider(),
          _QuickActionItem(
            label: 'History',
            icon: Icons.history_rounded,
            bg: cTealLight,
            color: cTeal,
            onTap: onHistory,
          ),
          const _ActionDivider(),
          _QuickActionItem(
            label: 'Billing',
            icon: Icons.receipt_long_rounded,
            bg: cAmberBg,
            color: cAmberText,
            onTap: onBilling,
          ),
        ],
      ),
    );
  }
}

class _ActionDivider extends StatelessWidget {
  const _ActionDivider(); 

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: VerticalDivider(width: 1, thickness: 1, color: cDivider, indent: 8, endIndent: 8),
    );
  }
}

class _QuickActionItem extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color bg;
  final Color color;
  final VoidCallback onTap; // ✅ ADDED CALLBACK

  const _QuickActionItem({
    required this.label,
    required this.icon,
    required this.bg,
    required this.color,
    required this.onTap,
  });

  @override
  State<_QuickActionItem> createState() => _QuickActionItemState();
}

class _QuickActionItemState extends State<_QuickActionItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: widget.onTap, // ✅ USES CALLBACK
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: _pressed ? cBg : Colors.transparent,
            borderRadius: const BorderRadius.all(Radius.circular(18)),
          ),
          child: Column(
            children: [
              AnimatedScale(
                scale: _pressed ? 0.9 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: widget.bg,
                    borderRadius: const BorderRadius.all(Radius.circular(16)),
                    boxShadow: [
                      BoxShadow(color: widget.color.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Icon(widget.icon, size: 24, color: widget.color),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: cTealDeep,
                  letterSpacing: 0.1,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── UNIFIED STATS CARD ────────────────────────────────────────────────

class _UnifiedStatsCard extends StatelessWidget {
  final int totalTrips;
  final int tripsThisMonth;
  final String timeSaved;
  const _UnifiedStatsCard({ 
    required this.totalTrips,
    required this.tripsThisMonth,
    required this.timeSaved,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(22)),
        border: Border.fromBorderSide(BorderSide(color: cBorder, width: 1)),
        boxShadow: [
          BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _StatItemBlock(
                label: 'Total Trips',
                value: '$totalTrips',
                icon: Icons.directions_car_rounded,
                color: cTeal,
              ),
            ),
            const VerticalDivider(width: 1, thickness: 1, color: cDivider, indent: 18, endIndent: 18),
            Expanded(
              child: _StatItemBlock(
                label: 'This Month',
                value: '$tripsThisMonth',
                icon: Icons.calendar_today_rounded,
                color: cBlue,
              ),
            ),
            const VerticalDivider(width: 1, thickness: 1, color: cDivider, indent: 18, endIndent: 18),
            Expanded(
              child: _StatItemBlock(
                label: 'Time Saved',
                value: timeSaved,
                icon: Icons.access_time_rounded,
                color: cAmber,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItemBlock extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatItemBlock({ 
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: cTealDeep,
              height: 1,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              color: cMutedLight,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── SECTION HEADER ────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title}); 

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppFonts.sora(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: cTealDeep,
        letterSpacing: -0.2,
      ),
    );
  }
}

// ─── UPCOMING TRIP CARD ────────────────────────────────────────────────

class _UpcomingTripCard extends StatelessWidget {
  final dynamic trip;
  final VoidCallback onViewDetails;
  const _UpcomingTripCard({
    required this.trip,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(22)),
        border: Border.fromBorderSide(BorderSide(color: cBorder, width: 1)),
        boxShadow: [
          BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: const BoxDecoration(
              color: cAmberBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Row(
              children: [
                const _PulsingDot(color: cAmber),
                const SizedBox(width: 10),
                Text(
                  "Driver is on the way",
                  style: AppFonts.sora(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: cAmberText,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    boxShadow: [BoxShadow(color: cBlackFaint, blurRadius: 4)],
                  ),
                  child: const Text(
                    "UPCOMING",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: cTealDark,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _RouteTimeline(
                  pickup: trip['pickup'] ?? 'Loading...',
                  destination: trip['destination'] ?? 'Loading...',
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Divider(color: cDivider, height: 1),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 15, color: cMutedLight),
                        const SizedBox(width: 8),
                        Text(
                          trip['date'] ?? 'Loading...',
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: cMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: onViewDetails,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: const BoxDecoration(
                          color: cTealLight,
                          borderRadius: BorderRadius.all(Radius.circular(20)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Track Ride",
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: cTealDark,
                              ),
                            ),
                            SizedBox(width: 6),
                            Icon(Icons.arrow_forward_rounded, size: 14, color: cTealDark),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact route timeline: pickup circle → dashed line → square drop-off
/// marker, matching the AfyaRide reference's route summary motif.
class _RouteTimeline extends StatelessWidget {
  final String pickup;
  final String destination;
  const _RouteTimeline({required this.pickup, required this.destination});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            children: [
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: cTeal, width: 3),
                ),
              ),
              Container(
                width: 2,
                height: 26,
                margin: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  color: cBorder,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: cError,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pickup point',
                  style: AppFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w600, color: cMutedLight)),
              const SizedBox(height: 2),
              Text(pickup,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: cTealDeep)),
              const SizedBox(height: 14),
              Text('Drop-off',
                  style: AppFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w600, color: cMutedLight)),
              const SizedBox(height: 2),
              Text(destination,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: cTealDeep)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── GROUPED RECENT TRIPS ────────────────────────────────────────────────

class _GroupedRecentTrips extends StatelessWidget {
  final List<dynamic> trips;
  final Function(dynamic trip) onTap;
  const _GroupedRecentTrips({
    required this.trips,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(22)),
        border: Border.fromBorderSide(BorderSide(color: cBorder, width: 1)),
        boxShadow: [
          BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: List.generate(trips.length, (index) {
          final trip = trips[index];
          final isLast = index == trips.length - 1;
          return _RecentTripItem(
            trip: trip,
            onTap: () => onTap(trip),
            showDivider: !isLast,
          );
        }),
      ),
    );
  }
}

class _RecentTripItem extends StatefulWidget {
  final dynamic trip;
  final VoidCallback onTap;
  final bool showDivider;
  const _RecentTripItem({
    required this.trip,
    required this.onTap,
    this.showDivider = true,
  });

  @override
  State<_RecentTripItem> createState() => _RecentTripItemState();
}

class _RecentTripItemState extends State<_RecentTripItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOutCubic,
        color: _pressed ? cBg : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: cTealLight,
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 24,
                    color: cTeal,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.trip['destination'] ?? 'Loading...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: cTealDeep,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.trip['date'] ?? 'Loading...',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: cMutedLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: cBg,
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: cMutedLight,
                  ),
                ),
              ],
            ),
            if (widget.showDivider)
              const Padding(
                padding: EdgeInsets.only(left: 62, top: 16),
                child: Divider(color: cDivider, height: 1),
              ),
          ],
        ),
      ),
    );
  }
}
