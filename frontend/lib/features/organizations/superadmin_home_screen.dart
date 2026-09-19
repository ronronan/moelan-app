import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/cagnotte_repository.dart';
import '../../core/design/tokens.dart';
import '../../models/organization.dart';
import '../../models/player.dart';
import '../../widgets/cagnotte_card.dart';
import '../../widgets/common.dart';
import '../../widgets/money.dart';
import '../../widgets/page_body.dart';
import '../../widgets/states.dart';

/// Every space, approved or not — the super-admin operator has no space of
/// their own to land on, so this is what they browse instead.
final allOrganizationsProvider = FutureProvider.autoDispose<List<Organization>>((
  ref,
) {
  return ref.watch(cagnotteRepositoryProvider).listOrganizations();
});

/// Read-only: the operator isn't a member of the org they're browsing, so
/// none of the write endpoints (`/api/players`, consumptions, ...) apply to
/// them — only `GET /api/organizations/{id}/players`.
final orgPlayersProvider = FutureProvider.family
    .autoDispose<List<Player>, String>((ref, orgId) {
      return ref.watch(cagnotteRepositoryProvider).listPlayersForOrg(orgId);
    });

/// Landing screen for a super-admin account with no space of its own: lets
/// them browse every organization and see its players' balances, read-only.
class SuperAdminHomeScreen extends ConsumerStatefulWidget {
  const SuperAdminHomeScreen({super.key});

  @override
  ConsumerState<SuperAdminHomeScreen> createState() =>
      _SuperAdminHomeScreenState();
}

class _SuperAdminHomeScreenState extends ConsumerState<SuperAdminHomeScreen> {
  String? _selectedOrgId;

  @override
  Widget build(BuildContext context) {
    final orgsAsync = ref.watch(allOrganizationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Espaces'),
        actions: [
          IconButton(
            icon: const Icon(Icons.verified_user_outlined),
            tooltip: 'Demandes en attente',
            onPressed: () => context.push('/superadmin/organizations'),
          ),
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Utilisateurs',
            onPressed: () => context.push('/superadmin/users'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Se déconnecter',
            onPressed: () async {
              await ref.read(oidcManagerProvider).logout();
            },
          ),
          const SizedBox(width: Gap.xs),
        ],
      ),
      body: orgsAsync.when(
        loading: () => const LoadingView(),
        error: (err, _) => ErrorView(
          error: err,
          onRetry: () => ref.invalidate(allOrganizationsProvider),
        ),
        data: (orgs) {
          if (orgs.isEmpty) {
            return const EmptyState(
              icon: Icons.groups_outlined,
              title: 'Aucun espace pour le moment',
              message:
                  "Les équipes qui créent leur caisse noire apparaîtront ici.",
            );
          }
          final selected = orgs.firstWhere(
            (o) => o.id == _selectedOrgId,
            orElse: () => orgs.first,
          );
          return PageBody(
            child: ListView(
              padding: const EdgeInsets.only(top: Gap.lg, bottom: Gap.xxl),
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selected.id,
                  decoration: const InputDecoration(
                    labelText: 'Espace',
                    prefixIcon: Icon(Icons.groups_outlined),
                  ),
                  items: [
                    for (final org in orgs)
                      DropdownMenuItem(
                        value: org.id,
                        child: Text(
                          org.approved ? org.name : '${org.name} (en attente)',
                        ),
                      ),
                  ],
                  onChanged: (id) => setState(() => _selectedOrgId = id),
                ),
                if (!selected.approved)
                  Padding(
                    padding: const EdgeInsets.only(top: Gap.md),
                    child: _PendingBanner(orgName: selected.name),
                  ),
                const SizedBox(height: Gap.lg),
                _OrgPlayers(org: selected),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.orgName});

  final String orgName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Row(
        children: [
          Icon(
            Icons.hourglass_top_outlined,
            size: 18,
            color: theme.colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(
              "Cet espace attend encore votre validation : personne ne peut "
              "y écrire.",
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ),
          TextButton(
            onPressed: () => context.push('/superadmin/organizations'),
            child: const Text('Traiter'),
          ),
        ],
      ),
    );
  }
}

class _OrgPlayers extends ConsumerWidget {
  const _OrgPlayers({required this.org});

  final Organization org;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playersAsync = ref.watch(orgPlayersProvider(org.id));

    return playersAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: Gap.xl),
        child: LoadingView(),
      ),
      error: (err, _) => ErrorView(
        error: err,
        onRetry: () => ref.invalidate(orgPlayersProvider(org.id)),
      ),
      data: (players) {
        if (players.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: Gap.xl),
            child: EmptyState(
              icon: Icons.groups_outlined,
              title: 'Aucun joueur',
              message: "Cet espace n'a pas encore d'effectif.",
            ),
          );
        }
        final total = players.fold<int>(0, (sum, p) => sum + p.balanceCents);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CagnotteCard(
              totalCents: total,
              targetCents: org.targetCents,
              playerCount: players.length,
            ),
            SectionHeader('Effectif', trailing: Text('${players.length}')),
            for (final player in players)
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.sm),
                child: AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Gap.lg,
                    vertical: Gap.md,
                  ),
                  child: Row(
                    children: [
                      InitialsAvatar(player.fullName, muted: !player.active),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Text(
                          player.fullName,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      BalancePill(player.balanceCents),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
