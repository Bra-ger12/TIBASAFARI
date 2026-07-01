import 'package:flutter_test/flutter_test.dart';

import 'package:patient_app/main.dart';

void main() {
  testWidgets('App starts and shows splash screen', (tester) async {
    await tester.pumpWidget(const TibaSafariApp());

    expect(find.text('Tiba Safari'), findsOneWidget);
    expect(find.text('Medical Transport Service'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
  });
}
