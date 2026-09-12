import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/cagnotte_repository.dart';

class PendingApprovalScreen extends ConsumerWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgName = ref.watch(meStatusProvider).value?.organization?.name;

    return Scaffold(
      appBar: AppBar(title: const Text('En attente de validation')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.hourglass_top, size: 48),
              const SizedBox(height: 16),
              Text(
                orgName == null
                    ? 'Votre espace est en attente de validation.'
                    : "L'espace « $orgName » est en attente de validation.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => ref.invalidate(meStatusProvider),
                child: const Text('Vérifier à nouveau'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () async => ref.read(oidcManagerProvider).logout(),
                child: const Text('Se déconnecter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
