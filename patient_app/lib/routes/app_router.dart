import 'package:flutter/material.dart';
import 'package:patient_app/screens/auth/login_screen.dart';
import 'package:patient_app/screens/auth/registration_screen.dart';
import 'package:patient_app/screens/auth/reset_password_screen.dart';
import 'package:patient_app/screens/dashboard/homepage.dart';
import 'package:patient_app/screens/profile/profile_screen.dart';
import 'package:patient_app/screens/rides/book_ride.dart';
import 'package:patient_app/screens/rides/track_ride.dart';
import 'package:patient_app/screens/rides/history_screen.dart';
import 'package:patient_app/models/auth_session.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
      case '/login':
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      
      case '/register':
        return MaterialPageRoute(builder: (_) => const PatientRegisterScreen());

      case '/reset-password':
        return MaterialPageRoute(builder: (_) => const ResetPasswordScreen());

      case '/home':
        final session = settings.arguments as AuthSession?;
        return MaterialPageRoute(
          builder: (_) => HomeScreen(session: session ?? const AuthSession(
            userId: 'guest',
            displayName: 'Guest',
            phone: '',
            email: '',
            totalTrips: 0,
            tripsThisMonth: 0,
            timeSaved: '0 hr',
            upcomingTrips: [],
            recentTrips: [],
            unreadNotifications: 0,
            isLoggedIn: false,
          )),
        );
      
      case '/book':
      case '/book-ride':
        return MaterialPageRoute(builder: (_) => const BookRideScreen());
      
      case '/track':
      case '/track-ride':
        final args = settings.arguments as Map<String, String>?;
        return MaterialPageRoute(
          builder: (_) => TrackRideScreen(
            rideId: args?['rideId'],
            pickupLocation: args?['pickupLocation'],
            destination: args?['destination'],
          ),
        );
      
      case '/profile':
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      
      case '/history':
        return MaterialPageRoute(builder: (_) => const HistoryScreen());
      
      default:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
    }
  }
}