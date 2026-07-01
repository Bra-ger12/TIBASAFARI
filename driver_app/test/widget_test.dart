// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap gestures
// and scroll gestures using the methods like tap() and scroll().

// ignore: unused_import
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:driver_app/main.dart';

void main() {
  testWidgets('App starts and shows login screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const TibaSafariDriverApp());

    // Verify that the login screen appears
    expect(find.text('TibaSafari Driver Portal'), findsOneWidget);
    expect(
      find.text('Login to view and manage your assigned trips'),
      findsOneWidget,
    );
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets('Driver signup page is reachable from login', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TibaSafariDriverApp());

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Create Driver Account'), findsOneWidget);
    expect(find.text('Submit Signup Request'), findsOneWidget);
  });
}
