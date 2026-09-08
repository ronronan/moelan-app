import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/cagnotte_repository.dart';
import '../../core/format.dart';
import '../../models/player.dart';
import 'players_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playersAsync = ref.watch(playersListProvider);
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moelan App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Se déconnecter',
            onPressed: () async {
              await ref.read(oidcManagerProvider).logout();
            },
          ),
        ],
      ),
      body: playersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erreur : $err')),
        data: (players) {
          final total = players.fold<int>(0, (sum, p) => sum + p.balanceCents);
          return RefreshIndicator(
            onRefresh: () => ref.refresh(playersListProvider.future),
            child: ListView(
              children: [
                _CagnotteHeader(totalCents: total),
                const Divider(height: 1),
                if (players.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('Aucun joueur pour le moment.')),
                  )
                else
                  for (final player in players) _PlayerTile(player: player),
              ],
            ),
          );
        },
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => _showAddPlayerDialog(context, ref),
              tooltip: 'Ajouter un joueur',
              child: const Icon(Icons.person_add),
            )
          : null,
    );
  }

  Future<void> _showAddPlayerDialog(BuildContext context, WidgetRef ref) async {
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un joueur'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: firstNameController,
              decoration: const InputDecoration(labelText: 'Prénom'),
              autofocus: true,
            ),
            TextField(
              controller: lastNameController,
              decoration: const InputDecoration(labelText: 'Nom'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );

    if (created != true) return;
    if (firstNameController.text.trim().isEmpty || lastNameController.text.trim().isEmpty) {
      return;
    }

    await ref
        .read(cagnotteRepositoryProvider)
        .createPlayer(firstNameController.text.trim(), lastNameController.text.trim());
    ref.invalidate(playersListProvider);
  }
}

class _CagnotteHeader extends StatelessWidget {
  const _CagnotteHeader({required this.totalCents});

  final int totalCents;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text('Cagnotte totale', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            formatCents(totalCents),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          const Text('Direction Moelan-sur-Mer 🌊'),
        ],
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    final negative = player.balanceCents < 0;
    return ListTile(
      title: Text(player.fullName),
      trailing: Text(
        formatCents(player.balanceCents),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: negative ? Theme.of(context).colorScheme.error : null,
        ),
      ),
      onTap: () => context.push('/players/${player.id}'),
    );
  }
}
