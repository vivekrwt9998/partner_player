import 'package:flutter/material.dart';
import 'screens/main_shell.dart';

void main() {
  runApp(const PartnerGameApp());
}

class PartnerGameApp extends StatelessWidget {
  const PartnerGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Partner Game',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // TEMPORARY: bypassing the login/signup/guest gate (AuthGate) while
      // the backend connection is being sorted out, so the Games tab is
      // reachable without a server. Nothing was deleted -- AuthGate and
      // everything under screens/auth/ still exist untouched. To turn auth
      // back on, re-add the `screens/auth/auth_gate.dart` import and change
      // this back to `const AuthGate()`.
      home: const MainShell(),
    );
  }
}
