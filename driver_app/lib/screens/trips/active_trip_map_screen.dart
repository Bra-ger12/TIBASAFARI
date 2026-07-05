import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/driver_session.dart';
import '../../core/theme/colors.dart';
import '../../services/driver_service.dart';
import '../../services/location_service.dart';
import '../../services/offline_queue_service.dart';
import '../../services/trip_ws_service.dart';
import 'trip_chat_screen.dart';
import 'trip_completion_screen.dart';

class ActiveTripMapScreen extends StatefulWidget {
  final DriverAssignedTrip trip;
  final String token;
  final String driverUid;

  const ActiveTripMapScreen({
    super.key,
    required this.trip,
    required this.token,
    required this.driverUid,
  });

  @override
  State<ActiveTripMapScreen> createState() => _ActiveTripMapScreenState();
}

class _ActiveTripMapScreenState extends State<ActiveTripMapScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  StreamSubscription<Position>? _locationSub;
  StreamSubscription<String>? _wsSub;

  LatLng? _driverLatLng;
  LatLng? _pickupLatLng;
  LatLng? _destLatLng;
  TripAssignmentStatus _status = TripAssignmentStatus.accepted;
  bool _isLoading = false;

  double _traveledMeters = 0;
  DateTime? _tripStartedAt;

  static const _wsBase = 'ws://10.0.2.2:8000';
  static const _avgSpeedKmh = 30.0;

  @override
  void initState() {
    super.initState();
    _status = widget.trip.status;
    _startTracking();
    _connectWebSocket();
    _resolveStops();
  }

  Future<void> _resolveStops() async {
    final trip = widget.trip;
    final pickup = trip.pickupLatitude != null && trip.pickupLongitude != null
        ? LatLng(trip.pickupLatitude!, trip.pickupLongitude!)
        : await _geocode(trip.pickupAddress);
    final destination = trip.destLatitude != null && trip.destLongitude != null
        ? LatLng(trip.destLatitude!, trip.destLongitude!)
        : await _geocode(trip.destination);

    if (!mounted) return;
    setState(() {
      _pickupLatLng = pickup;
      _destLatLng = destination;
    });
    _fitBounds();
  }

  Future<LatLng?> _geocode(String address) async {
    if (address.trim().isEmpty) return null;
    try {
      final results = await geocoding.locationFromAddress(address);
      if (results.isEmpty) return null;
      return LatLng(results.first.latitude, results.first.longitude);
    } catch (_) {
      return null;
    }
  }

  void _startTracking() async {
    LocationService.instance.startTracking();
    _locationSub = LocationService.instance.stream.listen((pos) {
      final ll = LatLng(pos.latitude, pos.longitude);
      if (_driverLatLng != null) {
        _traveledMeters += Geolocator.distanceBetween(
          _driverLatLng!.latitude,
          _driverLatLng!.longitude,
          ll.latitude,
          ll.longitude,
        );
      }
      setState(() => _driverLatLng = ll);
      TripWsService.instance.sendLocation(pos.latitude, pos.longitude);
      _mapController.future.then((c) => c.animateCamera(
            CameraUpdate.newLatLng(ll),
          ));
      _fitBounds();
    });

    final pos = await LocationService.instance.getCurrentPosition();
    if (pos != null && mounted) {
      setState(() => _driverLatLng = LatLng(pos.latitude, pos.longitude));
    }
  }

  void _connectWebSocket() {
    TripWsService.instance.connect(
      tripId: widget.trip.id,
      token: widget.token,
      wsBaseUrl: _wsBase,
    );
    _wsSub = TripWsService.instance.statusStream.listen((status) {
      final parsed = TripAssignmentStatus.values.firstWhere(
        (s) => s.name.toUpperCase() == status.toUpperCase(),
        orElse: () => _status,
      );
      if (mounted) setState(() => _status = parsed);
    });
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _wsSub?.cancel();
    LocationService.instance.stopTracking();
    TripWsService.instance.disconnect();
    super.dispose();
  }

  Future<void> _performAction(String action) async {
    if (action == 'complete') {
      final completed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => TripCompletionScreen(
            trip: widget.trip,
            initialDistanceKm: _traveledMeters > 0 ? _traveledMeters / 1000 : null,
            initialDurationMinutes: _elapsedMinutes,
          ),
        ),
      );
      if (completed == true && mounted) {
        Navigator.of(context).pop(true);
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      final nextEnum = _actionToEnum(action);
      await DriverService.instance.updateTripStatus(
        driverUid: widget.driverUid,
        tripId: widget.trip.id,
        status: nextEnum,
      );
      if (action == 'start') _tripStartedAt = DateTime.now();
      setState(() => _status = _nextStatus(action));
    } on ActionQueuedException catch (e) {
      if (action == 'start') _tripStartedAt = DateTime.now();
      if (mounted) {
        setState(() => _status = _nextStatus(action));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: cAmber,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Action failed: $e'),
            backgroundColor: cError,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  TripAssignmentStatus _actionToEnum(String action) {
    switch (action) {
      case 'start':
        return TripAssignmentStatus.inProgress;
      case 'arrive':
        return TripAssignmentStatus.arrived;
      default:
        return _status;
    }
  }

  TripAssignmentStatus _nextStatus(String action) => _actionToEnum(action);

  Future<void> _triggerSos() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Send Emergency Alert?',
            style: TextStyle(fontWeight: FontWeight.w800, color: cError)),
        content: const Text(
            'This immediately notifies dispatch with your location and this trip. Only use this in a real emergency.',
            style: TextStyle(color: cMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: cMuted, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: cError,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Send SOS', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final notified = await DriverService.instance.triggerSos(
        tripId: widget.trip.id,
        latitude: _driverLatLng?.latitude,
        longitude: _driverLatLng?.longitude,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(notified > 0
            ? 'Emergency alert sent to dispatch'
            : 'Alert sent, but no dispatcher is currently reachable'),
        backgroundColor: cError,
        behavior: SnackBarBehavior.floating,
      ));
    } on ActionQueuedException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$e'),
          backgroundColor: cAmber,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to send alert: $e'),
          backgroundColor: cError,
        ));
      }
    }
  }

  void _openChat() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TripChatScreen(
        trip: widget.trip,
        token: widget.token,
        driverUid: widget.driverUid,
      ),
    ));
  }

  void _openNavigation(String address) async {
    final query = Uri.encodeComponent(address);
    final googleMapsUrl =
        Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$query&travelmode=driving');
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    }
  }

  /// The stop the driver is currently heading to: pickup while accepted, destination once en route/arrived.
  LatLng? get _nextStopLatLng =>
      _status == TripAssignmentStatus.accepted ? _pickupLatLng : _destLatLng;

  String get _nextStopLabel =>
      _status == TripAssignmentStatus.accepted ? 'pickup' : 'destination';

  int? get _elapsedMinutes {
    final started = _tripStartedAt;
    if (started == null) return null;
    return DateTime.now().difference(started).inMinutes;
  }

  String? get _distanceEtaText {
    final target = _nextStopLatLng;
    final driver = _driverLatLng;
    if (target == null || driver == null) return null;
    final meters = Geolocator.distanceBetween(
      driver.latitude,
      driver.longitude,
      target.latitude,
      target.longitude,
    );
    final km = meters / 1000;
    final etaMinutes = (km / _avgSpeedKmh * 60).ceil().clamp(1, 999);
    return '${km.toStringAsFixed(1)} km • ~$etaMinutes min to $_nextStopLabel';
  }

  Future<void> _fitBounds() async {
    final target = _nextStopLatLng;
    final driver = _driverLatLng;
    if (target == null || driver == null) return;
    final controller = await _mapController.future;
    final bounds = LatLngBounds(
      southwest: LatLng(
        driver.latitude < target.latitude ? driver.latitude : target.latitude,
        driver.longitude < target.longitude ? driver.longitude : target.longitude,
      ),
      northeast: LatLng(
        driver.latitude > target.latitude ? driver.latitude : target.latitude,
        driver.longitude > target.longitude ? driver.longitude : target.longitude,
      ),
    );
    await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 72));
  }

  Set<Marker> get _markers {
    final markers = <Marker>{};
    if (_driverLatLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: _driverLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'You'),
      ));
    }
    if (_pickupLatLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: _pickupLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(title: 'Pickup', snippet: widget.trip.pickupAddress),
      ));
    }
    if (_destLatLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: _destLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: 'Destination', snippet: widget.trip.destination),
      ));
    }
    return markers;
  }

  Set<Polyline> get _polylines {
    final target = _nextStopLatLng;
    final driver = _driverLatLng;
    if (target == null || driver == null) return {};
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: [driver, target],
        color: cTeal,
        width: 4,
        patterns: [PatternItem.dash(16), PatternItem.gap(10)],
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cBg,
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _driverLatLng ?? const LatLng(-6.7924, 39.2083),
              zoom: 15,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (c) => _mapController.complete(c),
          ),

          // Top card
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _TripInfoCard(
                trip: widget.trip,
                status: _status,
                etaText: _distanceEtaText,
                onNavigate: () => _openNavigation(
                  _status == TripAssignmentStatus.accepted
                      ? widget.trip.pickupAddress
                      : widget.trip.destination,
                ),
                onBack: () => Navigator.of(context).pop(),
              ),
            ),
          ),

          // SOS button
          Positioned(
            right: 16,
            bottom: 140,
            child: _SosFab(onTap: _triggerSos),
          ),

          // Chat button
          Positioned(
            right: 16,
            bottom: 200,
            child: _ChatFab(onTap: _openChat),
          ),

          // Bottom action panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _ActionPanel(
              status: _status,
              isLoading: _isLoading,
              onStart: () => _performAction('start'),
              onArrive: () => _performAction('arrive'),
              onComplete: () => _performAction('complete'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info Card ────────────────────────────────────────────────────────────────

class _TripInfoCard extends StatelessWidget {
  final DriverAssignedTrip trip;
  final TripAssignmentStatus status;
  final String? etaText;
  final VoidCallback onNavigate;
  final VoidCallback onBack;

  const _TripInfoCard({
    required this.trip,
    required this.status,
    required this.etaText,
    required this.onNavigate,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x1A0F6E56), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cTealLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: cTeal, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.patientName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: cTealDeep,
                      ),
                    ),
                    Text(
                      trip.appointmentType,
                      style: const TextStyle(fontSize: 12, color: cMuted),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onNavigate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: cTeal,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.navigation_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                      const Text(
                        'Navigate',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFFEEF4F2), height: 1),
          const SizedBox(height: 14),
          _AddressRow(
            icon: Icons.trip_origin_rounded,
            iconColor: Colors.blue,
            label: 'Pickup',
            address: trip.pickupAddress,
          ),
          const SizedBox(height: 10),
          _AddressRow(
            icon: Icons.location_on_rounded,
            iconColor: cTeal,
            label: 'Destination',
            address: trip.destination,
          ),
          if (etaText != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cTealLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.timer_outlined, size: 14, color: cTealDark),
                const SizedBox(width: 6),
                Text(etaText!,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: cTealDark)),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String address;

  const _AddressRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: cMuted, fontWeight: FontWeight.w600)),
              Text(
                address,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cTealDeep),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Action Panel ─────────────────────────────────────────────────────────────

class _ActionPanel extends StatelessWidget {
  final TripAssignmentStatus status;
  final bool isLoading;
  final VoidCallback onStart;
  final VoidCallback onArrive;
  final VoidCallback onComplete;

  const _ActionPanel({
    required this.status,
    required this.isLoading,
    required this.onStart,
    required this.onArrive,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).padding.bottom,
      ),
      child: _buildButton(),
    );
  }

  Widget _buildButton() {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: CircularProgressIndicator(color: cTeal),
        ),
      );
    }

    switch (status) {
      case TripAssignmentStatus.accepted:
        return _PrimaryButton(
          label: 'Start Trip',
          icon: Icons.play_arrow_rounded,
          color: cTeal,
          onTap: onStart,
        );
      case TripAssignmentStatus.inProgress:
        return Row(
          children: [
            Expanded(
              child: _PrimaryButton(
                label: 'Arrived',
                icon: Icons.location_on_rounded,
                color: Colors.blue,
                onTap: onArrive,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PrimaryButton(
                label: 'Complete',
                icon: Icons.check_circle_rounded,
                color: Colors.green,
                onTap: onComplete,
              ),
            ),
          ],
        );
      case TripAssignmentStatus.arrived:
        return _PrimaryButton(
          label: 'Complete',
          icon: Icons.check_circle_rounded,
          color: Colors.green,
          onTap: onComplete,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _ChatFab extends StatelessWidget {
  final VoidCallback onTap;
  const _ChatFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cTeal,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 52,
          height: 52,
          child: Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _SosFab extends StatelessWidget {
  final VoidCallback onTap;
  const _SosFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cError,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 52,
          height: 52,
          child: Icon(Icons.emergency_share_rounded, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 56,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
