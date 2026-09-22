import 'package:app/screens/auth/signup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows validation errors when submitted empty', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));

    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(find.text('Required'), findsNWidgets(4));
  });

  testWidgets('rejects a password shorter than 6 characters', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));

    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Vivek');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email or Phone Number'),
      'vivek@example.com',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Country'), 'India');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), '123');
    await tester.enterText(find.widgetWithText(TextFormField, 'Confirm Password'), '123');

    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(find.text('At least 6 characters'), findsWidgets);
  });

  testWidgets('rejects mismatched passwords', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));

    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Vivek');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email or Phone Number'),
      'vivek@example.com',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Country'), 'India');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret123');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm Password'),
      'different123',
    );

    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(find.text("Passwords don't match"), findsOneWidget);
  });
}
