import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/cagnotte_repository.dart';
import '../../core/design/tokens.dart';
import '../../models/organization.dart';
import '../../widgets/common.dart';
import '../../widgets/feedback.dart';
import '../../widgets/page_body.dart';
import '../../widgets/states.dart';
import 'superadmin_home_screen.dart';

final pendingOrganizationsProvider =
    FutureProvider.autoDispose<List<Organization>>((ref) {
      return ref.watch(cagnotteRepositoryProvider).listPendingOrganizations();
    });

class SuperAdminOrganizationsScreen extends ConsumerWidget {
  const SuperAdminOrganizationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingOrganizationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Demandes d\'espace')),
      body: pendingAsync.when(
        loading: () => const LoadingView(),
        error: (err, _) => ErrorView(
          error: err,
          onRetry: () => ref.invalidate(pendingOrganizationsProvider),
        ),
        data: (orgs) {
          if (orgs.isEmpty) {
            return const EmptyState(
              icon: Icons.inbox_outlined,
              title: 'Aucune demande en attente',
              message: 'Les nouvelles demandes de création apparaîtront ici.',
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(pendingOrganizationsProvider.future),
            child: PageBody(
              child: ListView(
                padding: const EdgeInsets.only(top: Gap.lg, bottom: Gap.xxl),
                children: [
                  for (final org in orgs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Gap.md),
                      child: _PendingCard(org: org),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PendingCard extends ConsumerWidget {
  const _PendingCard({required this.org});

  final Organization org;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(org.name),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(org.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      org.contactEmail,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _reject(context, ref),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    side: BorderSide(
                      color: theme.colorScheme.error.withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Text('Refuser'),
                ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: FilledButton(
                  onPressed: () => _approve(context, ref),
                  child: const Text('Valider'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(cagnotteRepositoryProvider).approveOrganization(org.id);
      if (context.mounted) {
        showSuccess(context, '« ${org.name} » peut maintenant être utilisé.');
      }
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
    ref.invalidate(pendingOrganizationsProvider);
    ref.invalidate(allOrganizationsProvider);
  }

  /// Refusing is destructive and has no undo — the space row, its seeded
  /// prices/fines and its Keycloak groups all go — so it asks first, and
  /// says out loud what the requester will see next (they land back on
  /// "Créer mon espace", not on an error).
  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.delete_forever_outlined,
          color: Theme.of(context).colorScheme.error,
        ),
        title: Text('Refuser « ${org.name} » ?'),
        content: const Text(
          "La demande et l'espace associé seront définitivement supprimés. "
          "Le compte qui l'a créée retrouvera l'écran « Créer mon espace » et "
          'pourra refaire une demande.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Refuser et supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(cagnotteRepositoryProvider).rejectOrganization(org.id);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Demande « ${org.name} » supprimée.')),
        );
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
    ref.invalidate(pendingOrganizationsProvider);
    ref.invalidate(allOrganizationsProvider);
  }
}
