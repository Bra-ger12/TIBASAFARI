import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Distinguishes *why* location access isn't available — "denied, ask
/// again" (show a retry button) and "denied forever"/"service disabled"
/// (must open Settings — a retry button won't help) need different UI,
/// but used to all collapse into a single `false`.
enum LocationPermissionResult {
  granted,
  serviceDisabled,
  denied,
  deniedForever,
}

/// Handles GPS permission and continuous location stream.
class LocationService {
  LocationService._();
  static final instance = LocationService._();

  StreamSubscription<Position>? _sub;
  final _controller = StreamController<Position>.broadcast();
  final _trackingErrorController =
      StreamController<LocationPermissionResult>.broadcast();

  Stream<Position> get stream => _controller.stream;

  /// startTracking() is normally called fire-and-forget (it's async but
  /// callers don't await it), so this is how a screen finds out tracking
  /// silently never started because permission isn't granted.
  Stream<LocationPermissionResult> get trackingErrorStream =>
      _trackingErrorController.stream;

  Future<LocationPermissionResult> checkPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationPermissionResult.serviceDisabled;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return LocationPermissionResult.denied;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return LocationPermissionResult.deniedForever;
    }
    return LocationPermissionResult.granted;
  }

  Future<bool> requestPermission() async =>
      (await checkPermission()) == LocationPermissionResult.granted;

  Future<Position?> getCurrentPosition() async {
    final granted = await requestPermission();
    if (!granted) return null;
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> startTracking() async {
    final result = await checkPermission();
    if (result != LocationPermissionResult.granted) {
      _trackingErrorController.add(result);
      return;
    }
    _sub?.cancel();
    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // update every 10 metres
      ),
    ).listen(
      (pos) => _controller.add(pos),
      onError: (_) {},
    );
  }

  void stopTracking() {
    _sub?.cancel();
    _sub = null;
  }

  void dispose() {
    stopTracking();
    _controller.close();
    _trackingErrorController.close();
  }
}
