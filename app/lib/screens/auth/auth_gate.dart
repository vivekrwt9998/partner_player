import 'package:flutter/material.dart';

import '../../services/auth_controller.dart';
import '../main_shell.dart';
import 'welcome_screen.dart';

/// Decides what the app shows on launch: a loading spinner while a saved
/// session is being restored, the [WelcomeScreen] if signed out, or
/// [MainShell] once authenticated. Also the thing that reacts automatically
/// when [AuthController] changes -- e.g. right after a successful login, or
/// right after a logout from the Profile screen -- since it listens to the
/// same single [AuthController.instance] the whole app shares.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    AuthController.instance.bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthController.instance,
      builder: (context, _) {
        return switch (AuthController.instance.status) {
          AuthStatus.loading => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          AuthStatus.unauthenticated => const WelcomeScreen(),
          AuthStatus.authenticated => const MainShell(),
        };
      },
    );
  }
}
