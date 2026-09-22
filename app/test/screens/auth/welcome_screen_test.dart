import 'package:app/screens/auth/login_screen.dart';
import 'package:app/screens/auth/signup_screen.dart';
import 'package:app/screens/auth/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpWelcome(WidgetTester tester) {
    return tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));
  }

  testWidgets('shows Sign Up, Log In and Continue as Guest', (tester) async {
    await pumpWelcome(tester);

    expect(find.text('Sign Up'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
    expect(find.text('Continue as Guest'), findsOneWidget);
  });

  testWidgets('tapping Sign Up opens SignupScreen', (tester) async {
    await pumpWelcome(tester);

    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();

    expect(find.byType(SignupScreen), findsOneWidget);
  });

  testWidgets('tapping Log In opens LoginScreen', (tester) async {
    await pumpWelcome(tester);

    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
