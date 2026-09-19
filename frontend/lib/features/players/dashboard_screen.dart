import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/cagnotte_repository.dart';
import '../../core/design/tokens.dart';
import '../../core/error_message.dart';
import '../../core/format.dart';
import '../../core/push/push_notifications.dart';
import '../../models/consumable_type.dart';
import '../../models/player.dart';
import '../../widgets/cagnotte_card.dart';
import '../../widgets/common.dart';
import '../../widgets/feedback.dart';
import '../../widgets/money.dart';
import '../../widgets/page_body.dart';
import '../../widgets/states.dart';
import 'players_providers.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final Set<String> _selected = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // M16 scaffolding: no-ops until a Firebase project is configured (see
    // core/push/push_notifications.dart) — safe to always attempt.
    ref.read(pushNotificationsProvider).initialize(ref);
  }

  void _toggleSelected(String playerId) {
    setState(() {
      if (!_selected.add(playerId)) _selected.remove(playerId);
    });
  }

  void _clearSelection() => setState(_selected.clear);

  Future<void> _bulkDebit(ConsumableType consumable) async {
    final count = _selected.length;
    setState(() => _busy = true);
    final repo = ref.read(cagnotteRepositoryProvider);
    try {
      for (final playerId in _selected) {
        await repo.recordConsumption(playerId, consumable.id);
      }
      if (mounted) {
        showSuccess(
          context,
          '${consumable.label} × $count — '
          '${formatCents(consumable.priceCents * count)} débités',
        );
      }
    } catch (error) {
      if (mounted) showFailure(context, error);
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
      appBar: selectionMode
          ? AppBar(
              title: Text('${_selected.length} sélectionné(s)'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Annuler la sélection',
                onPressed: _clearSelection,
              ),
            )
          : AppBar(
              title: const Text('Moelan'),
              actions: [
                if (isSuperAdmin) ...[
                  IconButton(
                    icon: const Icon(Icons.verified_user_outlined),
                    tooltip: 'Espaces en attente',
                    onPressed: () => context.push('/superadmin/organizations'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.people_outline),
                    tooltip: 'Utilisateurs',
                    onPressed: () => context.push('/superadmin/users'),
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.insights_outlined),
                  tooltip: 'Statistiques',
                  onPressed: () => context.push('/stats'),
                ),
                IconButton(
                  icon: const Icon(Icons.receipt_long_outlined),
                  tooltip: 'Historique',
                  onPressed: () => context.push('/history'),
                ),
                _OverflowMenu(isAdmin: isAdmin),
                const SizedBox(width: Gap.xs),
              ],
            ),
      body: playersAsync.when(
        loading: () => const _DashboardSkeleton(),
        error: (err, _) => _DashboardError(error: err),
        data: (players) {
          final total = players.fold<int>(0, (sum, p) => sum + p.balanceCents);
          final targetCents = ref
              .watch(meStatusProvider)
              .value
              ?.organization
              ?.targetCents;

          return RefreshIndicator(
            onRefresh: () => ref.refresh(playersListProvider.future),
            child: PageBody(
              child: ListView(
                padding: const EdgeInsets.only(top: Gap.sm, bottom: Gap.xxxl),
                children: [
                  CagnotteCard(
                    totalCents: total,
                    targetCents: targetCents,
                    playerCount: players.isEmpty ? null : players.length,
                  ),
                  if (players.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: Gap.xxl),
                      child: EmptyState(
                        icon: Icons.groups_outlined,
                        title: 'Aucun joueur pour le moment',
                        message: isAdmin
                            ? "Ajoutez les membres de l'équipe pour commencer "
                                  'à tenir la caisse.'
                            : "L'administrateur de l'espace n'a pas encore "
                                  'ajouté de joueur.',
                        action: isAdmin
                            ? FilledButton.icon(
                                onPressed: () =>
                                    _showAddPlayerDialog(context, ref),
                                icon: const Icon(Icons.person_add_outlined),
                                label: const Text('Ajouter un joueur'),
                              )
                            : null,
                      ),
                    )
                  else ...[
                    SectionHeader(
                      'Effectif',
                      trailing: canWrite
                          ? Text(
                              'Appui long : sélection',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            )
                          : null,
                    ),
                    for (final player in players)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Gap.sm),
                        child: _PlayerCard(
                          player: player,
                          selectable: canWrite,
                          selected: _selected.contains(player.id),
                          selectionMode: selectionMode,
                          onToggle: () => _toggleSelected(player.id),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: selectionMode
          ? _BulkActionBar(busy: _busy, onDebit: _bulkDebit)
          : null,
      floatingActionButton:
          isAdmin &&
              !selectionMode &&
              (playersAsync.value?.isNotEmpty ?? false)
          ? FloatingActionButton.extended(
              onPressed: () => _showAddPlayerDialog(context, ref),
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Joueur'),
            )
          : null,
    );
  }

  Future<void> _showAddPlayerDialog(BuildContext context, WidgetRef ref) async {
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un joueur'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: firstNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Prénom'),
                autofocus: true,
                validator: _required,
              ),
              const SizedBox(height: Gap.md),
              TextFormField(
                controller: lastNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nom'),
                validator: _required,
                onFieldSubmitted: (_) {
                  if (formKey.currentState!.validate()) {
                    Navigator.of(context).pop(true);
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );

    if (created != true || !context.mounted) return;

    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();
    try {
      await ref
          .read(cagnotteRepositoryProvider)
          .createPlayer(firstName, lastName);
      if (context.mounted) {
        showSuccess(context, "$firstName $lastName a rejoint l'effectif.");
      }
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
    ref.invalidate(playersListProvider);
  }
}

String? _required(String? value) =>
    (value == null || value.trim().isEmpty) ? 'Champ obligatoire' : null;

/// The settings and sign-out entries, folded into a menu: the app bar already
/// carries four icons on a phone, and these two are the least used.
class _OverflowMenu extends ConsumerWidget {
  const _OverflowMenu({required this.isAdmin});

  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      tooltip: 'Plus',
      onSelected: (value) async {
        switch (value) {
          case 'settings':
            context.push('/settings');
          case 'logout':
            await ref.read(oidcManagerProvider).logout();
        }
      },
      itemBuilder: (context) => [
        if (isAdmin)
          const PopupMenuItem(
            value: 'settings',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.tune),
              title: Text('Réglages'),
            ),
          ),
        const PopupMenuItem(
          value: 'logout',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout),
            title: Text('Se déconnecter'),
          ),
        ),
      ],
    );
  }
}

/// A 403 on the roster isn't really an error for two accounts: one that has
/// no space yet, and one whose space is still pending. Both get a way
/// forward instead of a red message.
class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    switch (errorCode(error)) {
      case 'no_organization':
        return EmptyState(
          icon: Icons.add_home_outlined,
          title: "Ce compte n'appartient à aucun espace",
          message: 'Créez la caisse noire de votre équipe pour commencer.',
          action: FilledButton(
            onPressed: () => context.push('/create-organization'),
            child: const Text('Créer un espace'),
          ),
        );
      case 'org_pending':
        return const EmptyState(
          icon: Icons.hourglass_top_outlined,
          title: 'Espace en attente de validation',
          message:
              "Un administrateur doit valider votre espace avant que vous "
              "puissiez l'utiliser.",
        );
      default:
        return ErrorView(error: error);
    }
  }
}

/// Keeps the page's shape while the roster loads, instead of collapsing to a
/// spinner and snapping back into place a moment later.
class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return PageBody(
      child: ListView(
        padding: const EdgeInsets.only(top: Gap.sm),
        children: [
          const SkeletonBox(height: 168, radius: Radii.lg),
          const SectionHeader('Effectif'),
          for (var i = 0; i < 5; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: Gap.sm),
              child: SkeletonBox(height: 72, radius: Radii.md),
            ),
        ],
      ),
    );
  }
}

/// Shown instead of the app bar actions once ≥1 player is selected: one tap
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
    return Material(
      elevation: 3,
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.lg,
            vertical: Gap.md,
          ),
          child: consumablesAsync.when(
            loading: () => const SizedBox(height: 48, child: LoadingView()),
            error: (err, _) => SizedBox(
              height: 48,
              child: Center(child: Text(humanizeError(err))),
            ),
            data: (types) {
              final beer = types.where((t) => t.code == 'beer').firstOrNull;
              final soft = types.where((t) => t.code == 'soft').firstOrNull;
              return Row(
                children: [
                  if (beer != null)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: busy ? null : () => onDebit(beer),
                        icon: const Icon(Icons.sports_bar_outlined),
                        label: Text('Bière · ${formatCents(beer.priceCents)}'),
                      ),
                    ),
                  if (beer != null && soft != null)
                    const SizedBox(width: Gap.md),
                  if (soft != null)
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: busy ? null : () => onDebit(soft),
                        icon: const Icon(Icons.local_drink_outlined),
                        label: Text('Soft · ${formatCents(soft.priceCents)}'),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({
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
    final theme = Theme.of(context);
    return AppCard(
      selected: selected,
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.lg,
        vertical: Gap.md,
      ),
      onTap: () {
        if (selectionMode) {
          if (selectable) onToggle();
        } else {
          context.push('/players/${player.id}');
        }
      },
      onLongPress: selectable ? onToggle : null,
      child: Row(
        children: [
          if (selected)
            CircleAvatar(
              radius: 20,
              backgroundColor: theme.colorScheme.primary,
              child: Icon(
                Icons.check,
                size: 22,
                color: theme.colorScheme.onPrimary,
              ),
            )
          else
            InitialsAvatar(player.fullName, muted: !player.active),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.fullName,
                  style: theme.textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!player.active) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Inactif',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: Gap.sm),
          BalancePill(player.balanceCents),
        ],
      ),
    );
  }
}
