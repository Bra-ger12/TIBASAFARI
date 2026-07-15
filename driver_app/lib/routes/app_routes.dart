class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String resetPassword = '/reset-password';
  static const String home = '/home';
  static const String driverHome = home;
  static const String tripHistory = '/trip-history';
  static const String tripDetail = '/trip-detail';
  static const String earnings = '/earnings';
  static const String notifications = '/notifications';
  static const String profile = '/profile';

  static const Map<String, String> routeNames = {
    splash: 'Splash',
    login: 'Login',
    signup: 'Driver Signup',
    resetPassword: 'Reset Password',
    home: 'Driver Home',
    tripHistory: 'Trip History',
    tripDetail: 'Trip Details',
    earnings: 'Earnings',
    notifications: 'Notifications',
    profile: 'Driver Profile',
  };
}
