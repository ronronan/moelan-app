import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/cagnotte_repository.dart';
import '../../core/format.dart';
import '../../models/consumable_type.dart';
import '../../models/player.dart';
import 'players_providers.dart';

/// Machine-readable slug the backend attaches to a handful of 403s (see
/// `AppError::code` in the Rust backend) — lets a super-admin without a
/// space of their own see a helpful message instead of a raw error, without
/// the router forcibly redirecting everyone through the create-space flow.
String? _errorCode(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['code'] is String) return data['code'] as String;
  }
  return null;
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final Set<String> _selected = {};
  bool _busy = false;

  void _toggleSelected(String playerId) {
    setState(() {
      if (!_selected.add(playerId)) _selected.remove(playerId);
    });
  }

  void _clearSelection() => setState(_selected.clear);

  Future<void> _bulkDebit(ConsumableType consumable) async {
    setState(() => _busy = true);
    final repo = ref.read(cagnotteRepositoryProvider);
    try {
      for (final playerId in _selected) {
        await repo.recordConsumption(playerId, consumable.id);
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _selected.clear();
        });
        ref.invalidate(playersListProvider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final playersAsync = ref.watch(playersListProvider);
    final canWrite = ref.watch(canWriteProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final isSuperAdmin = ref.watch(isSuperAdminProvider);
    final selectionMode = _selected.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          selectionMode ? '${_selected.length} sélectionné(s)' : 'Moelan App',
        ),
        leading: selectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _clearSelection,
              )
            : null,
        actions: selectionMode
            ? null
            : [
                if (isSuperAdmin)
                  IconButton(
                    icon: const Icon(Icons.verified_user),
                    tooltip: 'Espaces en attente',
                    onPressed: () => context.push('/superadmin/organizations'),
                  ),
                if (isAdmin)
                  IconButton(
                    icon: const Icon(Icons.settings),
                    tooltip: 'Réglages',
                    onPressed: () => context.push('/settings'),
                  ),
                IconButton(
                  icon: const Icon(Icons.bar_chart),
                  tooltip: 'Statistiques',
                  onPressed: () => context.push('/stats'),
                ),
                IconButton(
                  icon: const Icon(Icons.history),
                  tooltip: 'Historique',
                  onPressed: () => context.push('/history'),
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
      body: playersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) {
          final code = _errorCode(err);
          if (code == 'no_organization') {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Ce compte n'appartient à aucun espace."),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => context.push('/create-organization'),
                      child: const Text('Créer un espace'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (code == 'org_pending') {
            return const Center(
              child: Text('Espace en attente de validation.'),
            );
          }
          return Center(child: Text('Erreur : $err'));
        },
        data: (players) {
          final total = players.fold<int>(0, (sum, p) => sum + p.balanceCents);
          final targetCents = ref
              .watch(meStatusProvider)
              .value
              ?.organization
              ?.targetCents;
          return RefreshIndicator(
            onRefresh: () => ref.refresh(playersListProvider.future),
            child: ListView(
              children: [
                _CagnotteHeader(totalCents: total, targetCents: targetCents),
                const Divider(height: 1),
                if (players.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('Aucun joueur pour le moment.')),
                  )
                else
                  for (final player in players)
                    _PlayerTile(
                      player: player,
                      selectable: canWrite,
                      selected: _selected.contains(player.id),
                      selectionMode: selectionMode,
                      onToggle: () => _toggleSelected(player.id),
                    ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: selectionMode
          ? _BulkActionBar(busy: _busy, onDebit: _bulkDebit)
          : null,
      floatingActionButton: isAdmin && !selectionMode
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
    if (firstNameController.text.trim().isEmpty ||
        lastNameController.text.trim().isEmpty) {
      return;
    }

    await ref
        .read(cagnotteRepositoryProvider)
        .createPlayer(
          firstNameController.text.trim(),
          lastNameController.text.trim(),
        );
    ref.invalidate(playersListProvider);
  }
}

/// Shown instead of the AppBar actions once ≥1 player is selected: one tap
/// applies a bière/soft debit to every selected player at once. No bulk
/// endpoint on the API — the volume for a single team is trivial, so a
/// sequential loop of the existing per-player call is simpler than adding
/// one.
class _BulkActionBar extends ConsumerWidget {
  const _BulkActionBar({required this.busy, required this.onDebit});

  final bool busy;
  final void Function(ConsumableType consumable) onDebit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consumablesAsync = ref.watch(consumableTypesProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: consumablesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Text('Erreur : $err'),
          data: (types) {
            final beer = types.where((t) => t.code == 'beer').firstOrNull;
            final soft = types.where((t) => t.code == 'soft').firstOrNull;
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (beer != null)
                  FilledButton.icon(
                    onPressed: busy ? null : () => onDebit(beer),
                    icon: const Icon(Icons.sports_bar),
                    label: Text('Bière (${formatCents(beer.priceCents)})'),
                  ),
                const SizedBox(width: 12),
                if (soft != null)
                  FilledButton.icon(
                    onPressed: busy ? null : () => onDebit(soft),
                    icon: const Icon(Icons.local_drink),
                    label: Text('Soft (${formatCents(soft.priceCents)})'),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CagnotteHeader extends StatelessWidget {
  const _CagnotteHeader({required this.totalCents, this.targetCents});

  final int totalCents;
  final int? targetCents;

  @override
  Widget build(BuildContext context) {
    final target = targetCents;
    // A negative or zero objective can't be filled — treat it the same as
    // "no objective set" rather than showing a nonsensical bar.
    final showProgress = target != null && target > 0;
    final progress = showProgress
        ? (totalCents / target).clamp(0, 1).toDouble()
        : 0.0;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            'Cagnotte totale',
            style: Theme.of(context).textTheme.titleMedium,
          ),
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
          if (showProgress) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: progress, minHeight: 8),
            ),
            const SizedBox(height: 4),
            Text(
              "${(progress * 100).round()} % de l'objectif (${formatCents(target)})",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({
    required this.player,
    required this.selectable,
    required this.selected,
    required this.selectionMode,
    required this.onToggle,
  });

  final Player player;
  final bool selectable;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final negative = player.balanceCents < 0;
    return ListTile(
      leading: selectable
          ? Checkbox(value: selected, onChanged: (_) => onToggle())
          : null,
      title: Text(player.fullName),
      trailing: Text(
        formatCents(player.balanceCents),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: negative ? Theme.of(context).colorScheme.error : null,
        ),
      ),
      selected: selected,
      onTap: () {
        if (selectionMode) {
          if (selectable) onToggle();
        } else {
          context.push('/players/${player.id}');
        }
      },
      onLongPress: selectable ? onToggle : null,
    );
  }
}
