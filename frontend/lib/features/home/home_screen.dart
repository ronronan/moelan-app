import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moelan App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final manager = ref.read(oidcManagerProvider);
              await manager.logout();
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Connecté en tant que '
              '${user?.claims.toJson()['preferred_username'] ?? user?.uid}',
            ),
            const SizedBox(height: 8),
            Text(isAdmin ? 'Rôle : admin' : 'Rôle : membre'),
          ],
        ),
      ),
    );
  }
}
