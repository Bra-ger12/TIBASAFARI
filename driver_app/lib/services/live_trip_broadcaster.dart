import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'location_service.dart';
import 'trip_ws_service.dart';

/// Owns the "share my live location for the active trip" lifecycle,
/// decoupled from any single screen.
///
/// Previously location was only streamed while the driver kept the Live Map
/// screen open and foregrounded — the moment they backed out (or the screen
/// was disposed) broadcasting stopped and the patient's tracking map went
/// blank. Broadcasting is now driven purely by whether the driver has an
/// active trip, so a dot keeps flowing to the patient/dispatch as long as the
/// app is open on any screen. (It still stops when the app is fully
/// backgrounded/killed — that would need a foreground service.)
///
/// Idempotent: [start] for the trip already being broadcast is a no-op, so
/// both the dashboard (on refresh/accept) and the Live Map screen can call it
/// freely without fighting over the shared singletons.
class LiveTripBroadcaster {
  LiveTripBroadcaster._();
  static final instance = LiveTripBroadcaster._();

  String? _tripId;
  StreamSubscription<Position>? _locationSub;

  /// The trip whose location is currently being broadcast, or null if idle.
  String? get activeTripId => _tripId;

  void start({
    required String tripId,
    required String token,
    required String wsBaseUrl,
  }) {
    if (tripId.isEmpty || token.isEmpty) return;
    if (_tripId == tripId && _locationSub != null) return;
    // Switching trips: tear down the previous stream first.
    if (_tripId != tripId) stop();
    _tripId = tripId;

    TripWsService.instance
        .connect(tripId: tripId, token: token, wsBaseUrl: wsBaseUrl);
    LocationService.instance.startTracking();
    _locationSub = LocationService.instance.stream.listen((pos) {
      TripWsService.instance.sendLocation(pos.latitude, pos.longitude);
    });
  }

  void stop() {
    _locationSub?.cancel();
    _locationSub = null;
    _tripId = null;
    LocationService.instance.stopTracking();
    TripWsService.instance.disconnect();
  }
}
