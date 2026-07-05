import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:patient_app/core/services/trip_api_service.dart';
import 'package:patient_app/core/services/trip_tracking_service.dart';
import 'package:patient_app/core/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

// ── Color aliases ─────────────────────────────────────────────────────────────
const Color cTeal = AppColors.primary;
const Color cTealDark = AppColors.primaryDark;
const Color cTealDeep = AppColors.primaryDeep;
const Color cTealLight = AppColors.primaryExtraLight;
const Color cBorder = AppColors.border;
const Color cDivider = AppColors.divider;
const Color cMuted = AppColors.textSecondary;
const Color cMutedLight = AppColors.textMuted;
const Color cError = AppColors.error;
const Color cAmber = AppColors.accent;
const Color cBg = AppColors.background;
const Color cBlue = AppColors.secondary;

const Color cTealShadow = Color(0x330E7C66);
const Color cAmberBg = Color(0xFFFBEFD9);
const Color cAmberText = Color(0xFFA56C12);


class TrackRideScreen extends StatefulWidget {
  final String? rideId;
  final String? token;
  final String? pickupLocation;
  final String? destination;
  final String? driverName;
  final String? driverPhone;
  final String? vehicleNumber;

  const TrackRideScreen({
    super.key,
    this.rideId,
    this.token,
    this.pickupLocation,
    this.destination,
    this.driverName,
    this.driverPhone,
    this.vehicleNumber,
  });

  @override
  State<TrackRideScreen> createState() => _TrackRideScreenState();
}

class _TrackRideScreenState extends State<TrackRideScreen>
    with SingleTickerProviderStateMixin {
  final Completer<GoogleMapController> _mapController = Completer();

  bool _isExpanded = false;
  String _tripStatus = 'ACCEPTED';
  LatLng? _driverLatLng;

  StreamSubscription<Map<String, double>>? _locationSub;
  StreamSubscription<String>? _statusSub;

  late final AnimationController _animController;
  late final List<Animation<double>> _fadeAnims;

  static const _daresalaam = LatLng(-6.7924, 39.2083);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fadeAnims = List.generate(4, (i) {
      final s = (i * 0.1).clamp(0.0, 0.6);
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _animController,
          curve: Interval(s, (s + 0.4).clamp(0.0, 1.0), curve: Curves.easeOut),
        ),
      );
    });
    _connectTracking();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _statusSub?.cancel();
    TripTrackingService.instance.disconnect();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _connectTracking() async {
    final id = widget.rideId;
    if (id == null) return;
    final token = widget.token ?? await TripApiService.instance.getToken();
    if (token == null || !mounted) return;

    TripTrackingService.instance.connect(tripId: id, token: token);

    _locationSub = TripTrackingService.instance.locationStream.listen((pos) {
      final ll = LatLng(pos['lat']!, pos['lng']!);
      setState(() => _driverLatLng = ll);
      _mapController.future.then(
        (c) => c.animateCamera(CameraUpdate.newLatLng(ll)),
      );
    });

    _statusSub = TripTrackingService.instance.statusStream.listen((status) {
      if (mounted) setState(() => _tripStatus = status);
    });
  }

  Set<Marker> get _markers {
    if (_driverLatLng == null) return {};
    return {
      Marker(
        markerId: const MarkerId('driver'),
        position: _driverLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: widget.driverName ?? 'Driver',
          snippet: widget.vehicleNumber,
        ),
      ),
    };
  }

  Widget _anim(int i, Widget child) => FadeTransition(
        opacity: _fadeAnims[i],
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _anim(0, _buildMapView()),
                    const SizedBox(height: 18),
                    _anim(1, _buildDriverCard()),
                    const SizedBox(height: 18),
                    _anim(2, _buildTripRouteInfo()),
                    const SizedBox(height: 18),
                    _anim(3, _buildStatusTimeline()),
                    const SizedBox(height: 24),
                    _buildCancelRideButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: cDivider)),
        boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: cTealLight, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.arrow_back_rounded, size: 22, color: cTealDark),
            ),
          ),
          const SizedBox(width: 14),
          Text('Track Ride',
              style: AppFonts.sora(fontSize: 18, fontWeight: FontWeight.w800, color: cTealDeep)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: cAmberBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _PulsingDot(color: cAmber),
                const SizedBox(width: 6),
                Text('LIVE',
                    style: AppFonts.sora(fontSize: 11, fontWeight: FontWeight.w800, color: cAmberText, letterSpacing: 0.8)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Map ─────────────────────────────────────────────────────────────────────

  Widget _buildMapView() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 240,
        child: GoogleMap(
          initialCameraPosition: const CameraPosition(target: _daresalaam, zoom: 14),
          markers: _markers,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          onMapCreated: (c) => _mapController.complete(c),
        ),
      ),
    );
  }

  // ── Driver Card ─────────────────────────────────────────────────────────────

  Widget _buildDriverCard() {
    final name = widget.driverName ?? 'Driver';
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(22)),
        border: Border.fromBorderSide(BorderSide(color: cBorder)),
        boxShadow: [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [cTeal, cTealDark]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: cTealShadow, blurRadius: 10, offset: Offset(0, 4))],
                  ),
                  child: Center(
                    child: Text(name[0].toUpperCase(),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: AppFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: cTealDeep)),
                      const SizedBox(height: 3),
                      Text(
                        '${widget.vehicleNumber ?? "Vehicle"} • ${_statusLabel()}',
                        style: const TextStyle(fontSize: 12.5, color: cMuted, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _isExpanded = !_isExpanded),
                  child: AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more_rounded, size: 22, color: cMuted),
                  ),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                const Divider(color: cDivider, height: 1, indent: 16, endIndent: 16),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(child: _contactButton(
                        icon: Icons.phone_rounded, label: 'Call', color: cTeal,
                        onTap: widget.driverPhone != null ? () => _callDriver() : null,
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _contactButton(
                        icon: Icons.chat_bubble_outline_rounded, label: 'Message', color: cBlue,
                        onTap: widget.driverPhone != null ? () => _smsDriver() : null,
                      )),
                    ],
                  ),
                ),
              ],
            ),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _contactButton({required IconData icon, required String label, required Color color, required VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }

  // ── Route Info ───────────────────────────────────────────────────────────────

  Widget _buildTripRouteInfo() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(22)),
        border: Border.fromBorderSide(BorderSide(color: cBorder)),
        boxShadow: [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(children: [
                Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: cTeal, width: 3)),
                ),
                Container(width: 1.5, height: 32, color: cBorder),
                Container(width: 11, height: 11, decoration: BoxDecoration(color: cError, borderRadius: BorderRadius.circular(3))),
              ]),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pickup', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cMuted)),
                    const SizedBox(height: 2),
                    Text(widget.pickupLocation ?? '—',
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: cTealDeep)),
                    const SizedBox(height: 14),
                    const Text('Destination', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cMuted)),
                    const SizedBox(height: 2),
                    Text(widget.destination ?? '—',
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: cTealDeep)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Status Timeline ──────────────────────────────────────────────────────────

  Widget _buildStatusTimeline() {
    final steps = [
      ('Driver Assigned', Icons.person_add_rounded, 'ASSIGNED'),
      ('On the Way', Icons.drive_eta_rounded, 'ACCEPTED'),
      ('Arrived at Pickup', Icons.near_me_rounded, 'EN_ROUTE'),
      ('Ride in Progress', Icons.directions_car_rounded, 'ARRIVED'),
      ('Trip Completed', Icons.flag_rounded, 'COMPLETED'),
    ];
    final currentIdx = steps.indexWhere((s) => s.$3 == _tripStatus);
    final activeIdx = currentIdx < 0 ? 0 : currentIdx;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(22)),
        border: Border.fromBorderSide(BorderSide(color: cBorder)),
        boxShadow: [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ride Status', style: AppFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: cTealDeep)),
          const SizedBox(height: 16),
          ...List.generate(steps.length, (i) {
            final (label, icon, _) = steps[i];
            final done = i < activeIdx;
            final current = i == activeIdx;
            final isLast = i == steps.length - 1;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: current ? 28 : 22,
                    height: current ? 28 : 22,
                    decoration: BoxDecoration(
                      color: done ? cTeal : current ? cAmber.withValues(alpha: 0.15) : cBg,
                      shape: BoxShape.circle,
                      border: current ? Border.all(color: cAmber, width: 2) : null,
                    ),
                    child: done
                        ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                        : current
                            ? Icon(icon, size: 14, color: cAmber)
                            : null,
                  ),
                  if (!isLast) Container(width: 2, height: 32, margin: const EdgeInsets.symmetric(vertical: 4),
                      color: done ? cTeal : cBorder),
                ]),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: current ? FontWeight.w700 : FontWeight.w600,
                              color: done || current ? cTealDeep : cMuted,
                            )),
                        const SizedBox(height: 2),
                        Text(
                          done ? 'Done' : current ? 'In Progress' : 'Pending',
                          style: TextStyle(fontSize: 12, color: current ? cAmber : done ? cTeal : cMuted),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ── Cancel Button ────────────────────────────────────────────────────────────

  Widget _buildCancelRideButton() {
    return GestureDetector(
      onTap: _showCancelDialog,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: cError.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cError.withValues(alpha: 0.2), width: 1.5),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cancel_rounded, size: 20, color: cError),
            SizedBox(width: 10),
            Text('Cancel Ride', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: cError)),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  String _statusLabel() {
    switch (_tripStatus) {
      case 'ASSIGNED':  return 'Assigned';
      case 'ACCEPTED':  return 'On the Way';
      case 'EN_ROUTE':  return 'En Route';
      case 'ARRIVED':   return 'Arrived';
      case 'COMPLETED': return 'Completed';
      default:          return _tripStatus;
    }
  }

  void _callDriver() async {
    final phone = widget.driverPhone;
    if (phone == null) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  void _smsDriver() async {
    final phone = widget.driverPhone;
    if (phone == null) return;
    final uri = Uri.parse('sms:$phone');
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Ride?',
            style: TextStyle(fontWeight: FontWeight.w800, color: cTealDeep)),
        content: const Text(
            'Are you sure you want to cancel this ride? A cancellation fee may apply.',
            style: TextStyle(color: cMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Ride', style: TextStyle(color: cTeal, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
            style: ElevatedButton.styleFrom(
              backgroundColor: cError, foregroundColor: Colors.white, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Cancel Ride', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ── Pulsing Dot ───────────────────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _anim,
        builder: (_, child) => Opacity(opacity: _anim.value, child: child),
        child: Container(
          width: 7, height: 7,
          decoration: BoxDecoration(
            color: widget.color, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: widget.color.withValues(alpha: 0.5), blurRadius: 4)],
          ),
        ),
      );
}
