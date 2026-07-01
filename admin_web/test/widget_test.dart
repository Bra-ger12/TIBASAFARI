import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_web/screens/auth_screens.dart';
import 'package:admin_web/theme/app_theme.dart';

void main() {
  testWidgets('shows admin login and navigates to signup', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        initialRoute: '/login',
        routes: {
          '/login': (context) => const AdminLoginScreen(),
          '/signup': (context) => const AdminSignupScreen(),
        },
      ),
    );

    expect(find.text('Admin Login'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Create Admin Account'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
