import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/cagnotte_repository.dart';
import '../../core/design/tokens.dart';
import '../../widgets/page_body.dart';

class PendingApprovalScreen extends ConsumerWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final orgName = ref.watch(meStatusProvider).value?.organization?.name;

    return Scaffold(
      appBar: AppBar(
        title: const Text('En attente'),
        actions: [
          TextButton(
            onPressed: () async => ref.read(oidcManagerProvider).logout(),
            child: const Text('Se déconnecter'),
          ),
          const SizedBox(width: Gap.sm),
        ],
      ),
      body: CenteredPageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Wrapped in an Align because the column stretches its children,
            // which would turn the disc into a full-width pill.
            Align(
              child: Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.hourglass_top_outlined,
                  size: 32,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
              ),
            ),
            const SizedBox(height: Gap.xl),
            Text(
              orgName == null
                  ? 'Votre espace attend sa validation'
                  : '« $orgName » attend sa validation',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: Gap.md),
            Text(
              "L'opérateur de l'instance doit valider votre demande. Vous "
              "n'avez rien d'autre à faire : revenez d'ici là, ou vérifiez "
              'maintenant.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: Gap.xxl),
            FilledButton.icon(
              onPressed: () => ref.invalidate(meStatusProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Vérifier à nouveau'),
            ),
          ],
        ),
      ),
    );
  }
}
