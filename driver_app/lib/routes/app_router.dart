import 'package:flutter/material.dart';
import '../screens/auth/driver_login.dart';
import '../screens/auth/driver_signup.dart';
import '../screens/dashboard/driver_home_screen.dart';
import '../screens/dashboard/notifications_screen.dart';
import '../screens/earnings/earnings_screen.dart';
import '../screens/profile/driver_profile_screen.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/trips/trip_detail_screen.dart';
import '../screens/trips/trip_history_screen.dart';
import '../core/models/driver_session.dart';
import '../core/theme/colors.dart';
import 'app_routes.dart';

export 'app_routes.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());

      case AppRoutes.login:
        return MaterialPageRoute(builder: (_) => const DriverLoginScreen());

      case AppRoutes.signup:
        return MaterialPageRoute(builder: (_) => const DriverSignupScreen());

      case AppRoutes.driverHome:
        final session = settings.arguments as DriverSession?;
        return MaterialPageRoute(
          builder: (_) =>
              DriverHomeScreen(session: session ?? DriverSession.empty),
        );

      case AppRoutes.tripHistory:
        final session = settings.arguments as DriverSession?;
        return MaterialPageRoute(
          builder: (_) =>
              TripHistoryScreen(session: session ?? DriverSession.empty),
        );

      case AppRoutes.tripDetail:
        final args = settings.arguments;
        final details = args is TripDetailArguments ? args : null;
        final trip = args is DriverAssignedTrip ? args : null;
        final tripId =
            details?.tripId ?? trip?.id ?? (args is String ? args : '');
        return MaterialPageRoute(
          builder: (_) => TripDetailScreen(
            session:
                details?.session ??
                (trip == null
                    ? DriverSession.empty
                    : DriverSession.empty.copyWith(assignedTrips: [trip])),
            tripId: tripId,
          ),
        );

      case AppRoutes.earnings:
        final session = settings.arguments as DriverSession?;
        return MaterialPageRoute(
          builder: (_) =>
              EarningsScreen(session: session ?? DriverSession.empty),
        );

      case AppRoutes.notifications:
        return MaterialPageRoute(builder: (_) => const NotificationsScreen());

      case AppRoutes.profile:
        final session = settings.arguments as DriverSession?;
        return MaterialPageRoute(
          builder: (_) =>
              DriverProfileScreen(session: session ?? DriverSession.empty),
        );

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(
              title: const Text('Route Not Found'),
              backgroundColor: cTeal,
            ),
            body: const Center(child: Text('Route not found')),
          ),
        );
    }
  }
}
