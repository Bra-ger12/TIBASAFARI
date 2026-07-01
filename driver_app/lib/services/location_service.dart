import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Handles GPS permission and continuous location stream.
class LocationService {
  LocationService._();
  static final instance = LocationService._();

  StreamSubscription<Position>? _sub;
  final _controller = StreamController<Position>.broadcast();

  Stream<Position> get stream => _controller.stream;

  Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

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

  void startTracking() {
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
  }
}
