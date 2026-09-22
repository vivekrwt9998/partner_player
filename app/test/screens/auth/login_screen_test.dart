import 'package:app/screens/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows validation errors when submitted empty', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(find.text('Required'), findsNWidgets(2));
  });
}
