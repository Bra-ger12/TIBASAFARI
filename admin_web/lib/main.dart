import 'package:flutter/material.dart';

import 'app_shell.dart';
import 'screens/auth_screens.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const TibaSafariAdminApp());
}

class TibaSafariAdminApp extends StatelessWidget {
  const TibaSafariAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tiba Safari Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const AdminLoginScreen(),
        '/signup': (context) => const AdminSignupScreen(),
        '/admin': (context) => const AppShell(),
      },
    );
  }
}
