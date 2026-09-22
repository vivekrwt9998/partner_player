import 'package:flutter/material.dart';

import '../services/auth_controller.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoggingOut = false;

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);
    await AuthController.instance.logout();
    // AuthGate swaps back to WelcomeScreen on its own; this widget may
    // already be unmounted by the time logout() returns.
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthController.instance.user;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person, size: 64, color: Colors.deepPurple),
              const SizedBox(height: 16),
              Text(
                user?.name ?? 'Profile',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              if (user?.isGuest ?? false) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'GUEST',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ] else if (user?.email != null || user?.country != null) ...[
                const SizedBox(height: 6),
                Text(
                  [
                    if (user?.email != null) user!.email!,
                    if (user?.phone != null) user!.phone!,
                    if (user?.country != null) user!.country!,
                  ].join(' · '),
                  style: TextStyle(color: Theme.of(context).colorScheme.outline),
                ),
              ],
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: _isLoggingOut ? null : _logout,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Log Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
