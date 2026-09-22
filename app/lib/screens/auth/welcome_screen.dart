import 'package:flutter/material.dart';

import '../../services/auth_controller.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

/// The very first screen a signed-out player sees: log in, sign up, or jump
/// straight in as a guest. [AuthGate] swaps this out for [MainShell]
/// automatically the moment any of the three succeeds.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isContinuingAsGuest = false;

  Future<void> _continueAsGuest() async {
    setState(() => _isContinuingAsGuest = true);
    try {
      await AuthController.instance.continueAsGuest();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err.toString())),
      );
    } finally {
      if (mounted) setState(() => _isContinuingAsGuest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.sports_esports_rounded,
                size: 96,
                color: Colors.deepPurple,
              ),
              const SizedBox(height: 16),
              Text(
                'Partner Game',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Play classic games with friends, anywhere.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SignupScreen()),
                  ),
                  child: const Text('Sign Up'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                  child: const Text('Log In'),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: _isContinuingAsGuest ? null : _continueAsGuest,
                child: _isContinuingAsGuest
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Continue as Guest'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
