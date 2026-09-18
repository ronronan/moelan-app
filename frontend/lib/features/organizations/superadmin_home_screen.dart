import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/cagnotte_repository.dart';
import '../../core/format.dart';
import '../../models/organization.dart';
import '../../models/player.dart';

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
            icon: const Icon(Icons.verified_user),
            tooltip: 'Espaces en attente',
            onPressed: () => context.push('/superadmin/organizations'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Se déconnecter',
            onPressed: () async {
              await ref.read(oidcManagerProvider).logout();
            },
          ),
        ],
      ),
      body: orgsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erreur : $err')),
        data: (orgs) {
          if (orgs.isEmpty) {
            return const Center(child: Text('Aucun espace pour le moment.'));
          }
          final selected =
              orgs.firstWhere(
                (o) => o.id == _selectedOrgId,
                orElse: () => orgs.first,
              );
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: DropdownButtonFormField<String>(
                  initialValue: selected.id,
                  decoration: const InputDecoration(
                    labelText: 'Espace',
                    border: OutlineInputBorder(),
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
              ),
              const Divider(height: 1),
              Expanded(child: _OrgPlayers(orgId: selected.id)),
            ],
          );
        },
      ),
    );
  }
}

class _OrgPlayers extends ConsumerWidget {
  const _OrgPlayers({required this.orgId});

  final String orgId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playersAsync = ref.watch(orgPlayersProvider(orgId));

    return playersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Erreur : $err')),
      data: (players) {
        if (players.isEmpty) {
          return const Center(child: Text('Aucun joueur pour le moment.'));
        }
        final total = players.fold<int>(0, (sum, p) => sum + p.balanceCents);
        return RefreshIndicator(
          onRefresh: () => ref.refresh(orgPlayersProvider(orgId).future),
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'Cagnotte totale : ${formatCents(total)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              const Divider(height: 1),
              for (final player in players)
                ListTile(
                  title: Text(player.fullName),
                  trailing: Text(
                    formatCents(player.balanceCents),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: player.balanceCents < 0
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
