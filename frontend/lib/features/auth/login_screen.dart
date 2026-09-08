import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Moelan App',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('La caisse noire du club, cap sur Moelan-sur-Mer.'),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () async {
                final manager = ref.read(oidcManagerProvider);
                await manager.loginAuthorizationCodeFlow();
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Text('Se connecter'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
