import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/cagnotte_repository.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/format.dart';
import '../../models/consumable_type.dart';
import '../../models/fine_type.dart';
import '../../models/player.dart';
import '../../widgets/common.dart';
import '../../widgets/feedback.dart';
import '../../widgets/money.dart';
import '../../widgets/page_body.dart';
import '../../widgets/states.dart';
import '../../widgets/transaction_tile.dart';
import 'players_providers.dart';

class PlayerDetailScreen extends ConsumerWidget {
  const PlayerDetailScreen({required this.playerId, super.key});

  final String playerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerAsync = ref.watch(playerDetailProvider(playerId));
    final canWrite = ref.watch(canWriteProvider);
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: playerAsync.when(
          data: (player) => Text(player.fullName),
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const Text('Joueur'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Historique complet',
            onPressed: () => context.push('/history?playerId=$playerId'),
          ),
          if (isAdmin)
            _PlayerMenu(playerId: playerId, player: playerAsync.value),
          const SizedBox(width: Gap.xs),
        ],
      ),
      body: playerAsync.when(
        loading: () => const LoadingView(),
        error: (err, _) => ErrorView(
          error: err,
          onRetry: () => ref.invalidate(playerDetailProvider(playerId)),
        ),
        data: (player) => RefreshIndicator(
          onRefresh: () async => invalidatePlayerData(ref, playerId),
          child: PageBody(
            child: ListView(
              padding: const EdgeInsets.only(bottom: Gap.xxxl),
              children: [
                _BalanceHeader(player: player),
                if (canWrite) ...[
                  const SizedBox(height: Gap.xl),
                  _ActionGrid(playerId: playerId, isAdmin: isAdmin),
                ],
                const SectionHeader('Derniers mouvements'),
                _RecentTransactions(playerId: playerId),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The number the whole screen exists for, stated once and large, with the
/// one word that tells you what it means — "dans le rouge" or "à jour".
class _BalanceHeader extends StatelessWidget {
  const _BalanceHeader({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = MoelanColors.of(context);
    final cents = player.balanceCents;
    final (background, foreground, caption) = switch (cents) {
      < 0 => (
        colors.negativeContainer,
        colors.onNegativeContainer,
        'Doit ${formatCents(-cents)} à la caisse',
      ),
      > 0 => (
        colors.positiveContainer,
        colors.onPositiveContainer,
        'En avance sur la caisse',
      ),
      _ => (
        theme.colorScheme.surfaceContainerHighest,
        theme.colorScheme.onSurfaceVariant,
        'Compte à jour',
      ),
    };

    return Container(
      margin: const EdgeInsets.only(top: Gap.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.xl,
        vertical: Gap.xl,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Column(
        children: [
          InitialsAvatar(player.fullName, radius: 28, muted: !player.active),
          const SizedBox(height: Gap.lg),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: MoneyText(
              cents,
              colored: false,
              style: theme.textTheme.displaySmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: Gap.xs),
          Text(
            caption,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: foreground.withValues(alpha: 0.85),
            ),
          ),
          if (!player.active) ...[
            const SizedBox(height: Gap.md),
            Chip(
              label: const Text('Joueur inactif'),
              backgroundColor: theme.colorScheme.surface,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }
}

/// The four everyday gestures, as a two-by-two grid of equally weighted
/// targets. They used to be a `Wrap` of pill buttons whose widths depended on
/// the price text, which meant the button you were reaching for moved
/// whenever the admin changed a tariff.
class _ActionGrid extends ConsumerWidget {
  const _ActionGrid({required this.playerId, required this.isAdmin});

  final String playerId;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consumablesAsync = ref.watch(consumableTypesProvider);
    final consumables = consumablesAsync.value ?? const <ConsumableType>[];
    final beer = consumables.where((t) => t.code == 'beer' && t.active).firstOrNull;
    final soft = consumables.where((t) => t.code == 'soft' && t.active).firstOrNull;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.sports_bar_outlined,
                label: 'Bière',
                hint: beer == null ? null : formatCents(beer.priceCents),
                onPressed: beer == null
                    ? null
                    : () => _record(context, ref, beer),
              ),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: _ActionButton(
                icon: Icons.local_drink_outlined,
                label: 'Soft',
                hint: soft == null ? null : formatCents(soft.priceCents),
                onPressed: soft == null
                    ? null
                    : () => _record(context, ref, soft),
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.md),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.gavel_outlined,
                label: 'Amende',
                onPressed: () => _showFineSheet(context, ref),
              ),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: _ActionButton(
                icon: Icons.savings_outlined,
                label: 'Créditer',
                emphasis: true,
                onPressed: () => _showCreditDialog(context, ref),
              ),
            ),
          ],
        ),
        if (isAdmin) ...[
          const SizedBox(height: Gap.md),
          // The API has always exposed manual adjustments (admin only, note
          // required) but no screen reached them — the documented way to
          // correct a mis-keyed round was to call the endpoint by hand.
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => _showAdjustmentDialog(context, ref),
              icon: const Icon(Icons.tune, size: 18),
              label: const Text('Corriger le solde'),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _record(
    BuildContext context,
    WidgetRef ref,
    ConsumableType consumable,
  ) async {
    try {
      await ref
          .read(cagnotteRepositoryProvider)
          .recordConsumption(playerId, consumable.id);
      if (context.mounted) {
        showSuccess(
          context,
          '${consumable.label} · ${formatCents(consumable.priceCents)} débité',
        );
      }
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
    invalidatePlayerData(ref, playerId);
  }

  Future<void> _showFineSheet(BuildContext context, WidgetRef ref) async {
    final fineTypes = await ref.read(fineTypesProvider.future);
    final active = fineTypes.where((f) => f.active).toList();
    if (!context.mounted) return;

    final selected = await showModalBottomSheet<FineType>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.sm, left: Gap.xs),
              child: Text(
                'Choisir une amende',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (active.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: Gap.xl),
                child: EmptyState(
                  icon: Icons.gavel_outlined,
                  title: 'Aucune amende active',
                  message: 'Le barème se configure dans Réglages → Amendes.',
                ),
              ),
            for (final fine in active)
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.sm),
                child: AppCard(
                  onTap: () => Navigator.of(context).pop(fine),
                  padding: const EdgeInsets.symmetric(
                    horizontal: Gap.lg,
                    vertical: Gap.md,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          fine.label,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      MoneyText(
                        -fine.amountCents,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (selected == null) return;
    try {
      await ref.read(cagnotteRepositoryProvider).recordFine(playerId, selected.id);
      if (context.mounted) {
        showSuccess(
          context,
          '${selected.label} · ${formatCents(selected.amountCents)} débité',
        );
      }
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
    invalidatePlayerData(ref, playerId);
  }

  Future<void> _showCreditDialog(BuildContext context, WidgetRef ref) async {
    final result = await _showAmountDialog(
      context,
      title: 'Créditer le joueur',
      confirmLabel: 'Créditer',
      helper: 'Ce que le joueur remet dans la caisse.',
      noteRequired: false,
    );
    if (result == null) return;

    try {
      await ref
          .read(cagnotteRepositoryProvider)
          .recordCredit(playerId, result.cents, note: result.note);
      if (context.mounted) {
        showSuccess(context, '${formatCents(result.cents)} crédités');
      }
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
    invalidatePlayerData(ref, playerId);
  }

  Future<void> _showAdjustmentDialog(BuildContext context, WidgetRef ref) async {
    final result = await _showAmountDialog(
      context,
      title: 'Corriger le solde',
      confirmLabel: 'Corriger',
      helper: 'Montant positif pour créditer, négatif pour débiter. '
          "La correction s'ajoute à l'historique, elle n'efface rien.",
      noteRequired: true,
      allowNegative: true,
    );
    if (result == null) return;

    try {
      await ref
          .read(cagnotteRepositoryProvider)
          .recordAdjustment(playerId, result.cents, result.note!);
      if (context.mounted) {
        showSuccess(context, 'Solde corrigé de ${formatCents(result.cents)}');
      }
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
    invalidatePlayerData(ref, playerId);
  }
}

/// What an amount dialog hands back: cents (never a double) plus the note.
class _AmountResult {
  const _AmountResult(this.cents, this.note);
  final int cents;
  final String? note;
}

/// Shared by "créditer" and "corriger" — same shape, different rules. Parses
/// euros with either separator (a French keyboard gives a comma) and converts
/// to cents at the boundary, so no amount ever travels as a double.
Future<_AmountResult?> _showAmountDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  required String helper,
  required bool noteRequired,
  bool allowNegative = false,
}) async {
  final amountController = TextEditingController();
  final noteController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              helper,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Gap.lg),
            TextFormField(
              controller: amountController,
              autofocus: true,
              keyboardType: TextInputType.numberWithOptions(
                decimal: true,
                signed: allowNegative,
              ),
              decoration: const InputDecoration(
                labelText: 'Montant',
                suffixText: '€',
              ),
              validator: (value) {
                final euros = _parseEuros(value);
                if (euros == null) return 'Montant invalide';
                if (!allowNegative && euros <= 0) {
                  return 'Le montant doit être positif';
                }
                if (allowNegative && euros == 0) {
                  return 'Le montant ne peut pas être nul';
                }
                return null;
              },
            ),
            const SizedBox(height: Gap.md),
            TextFormField(
              controller: noteController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: noteRequired ? 'Motif' : 'Note (optionnel)',
              ),
              validator: noteRequired
                  ? (value) => (value == null || value.trim().isEmpty)
                        ? 'Un motif est obligatoire'
                        : null
                  : null,
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
          child: Text(confirmLabel),
        ),
      ],
    ),
  );

  if (confirmed != true) return null;
  final euros = _parseEuros(amountController.text);
  if (euros == null) return null;
  final note = noteController.text.trim();
  return _AmountResult(
    (euros * 100).round(),
    note.isEmpty ? null : note,
  );
}

double? _parseEuros(String? raw) =>
    double.tryParse((raw ?? '').trim().replaceAll(',', '.'));

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    this.hint,
    this.onPressed,
    this.emphasis = false,
  });

  final IconData icon;
  final String label;

  /// The price, when there is one — shown under the label rather than inside
  /// it, so the button's size doesn't depend on the tariff.
  final String? hint;
  final VoidCallback? onPressed;

  /// True for the one action that puts money *in*, which earns the filled
  /// treatment among four otherwise equal buttons.
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: emphasis ? scheme.primary : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(Radii.md),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(Radii.md),
        child: Opacity(
          opacity: onPressed == null ? 0.45 : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Gap.lg),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 26,
                  color: emphasis ? scheme.onPrimary : scheme.onSurface,
                ),
                const SizedBox(height: Gap.sm),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: emphasis ? scheme.onPrimary : scheme.onSurface,
                  ),
                ),
                if (hint != null)
                  Text(
                    hint!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: emphasis
                          ? scheme.onPrimary.withValues(alpha: 0.8)
                          : scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Admin-only actions that don't belong among the four everyday gestures:
/// giving the player their own read-only login, and taking them off the
/// active roster.
class _PlayerMenu extends ConsumerWidget {
  const _PlayerMenu({required this.playerId, required this.player});

  final String playerId;
  final Player? player;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = player;
    if (current == null) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      tooltip: 'Actions',
      onSelected: (value) async {
        switch (value) {
          case 'invite':
            await _showInviteDialog(context, ref, current);
          case 'toggle':
            await _toggleActive(context, ref, current);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'invite',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.mail_outline),
            title: Text(
              current.email == null ? 'Donner un accès' : 'Renvoyer l\'accès',
            ),
            subtitle: current.email == null ? null : Text(current.email!),
          ),
        ),
        PopupMenuItem(
          value: 'toggle',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              current.active
                  ? Icons.person_off_outlined
                  : Icons.person_outline,
            ),
            title: Text(current.active ? 'Désactiver' : 'Réactiver'),
          ),
        ),
      ],
    );
  }

  Future<void> _showInviteDialog(
    BuildContext context,
    WidgetRef ref,
    Player player,
  ) async {
    final emailController = TextEditingController(text: player.email ?? '');
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Donner un accès'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${player.fullName} recevra un email pour créer son mot de '
                'passe. Son compte sera en lecture seule : il pourra suivre '
                'son ardoise, pas la modifier.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Gap.lg),
              TextFormField(
                controller: emailController,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) {
                  final email = (value ?? '').trim();
                  if (email.isEmpty) return 'Email obligatoire';
                  if (!email.contains('@') || !email.contains('.')) {
                    return 'Adresse invalide';
                  }
                  return null;
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
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final email = emailController.text.trim();
    try {
      await ref.read(cagnotteRepositoryProvider).invitePlayer(playerId, email);
      if (context.mounted) showSuccess(context, 'Invitation envoyée à $email.');
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
    invalidatePlayerData(ref, playerId);
  }

  Future<void> _toggleActive(
    BuildContext context,
    WidgetRef ref,
    Player player,
  ) async {
    try {
      await ref
          .read(cagnotteRepositoryProvider)
          .setPlayerActive(playerId, !player.active);
      if (context.mounted) {
        showSuccess(
          context,
          player.active
              ? '${player.fullName} ne fait plus partie de l\'effectif actif.'
              : '${player.fullName} est de retour dans l\'effectif.',
        );
      }
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
    invalidatePlayerData(ref, playerId);
  }
}

class _RecentTransactions extends ConsumerWidget {
  const _RecentTransactions({required this.playerId});

  final String playerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(playerTransactionsProvider(playerId));
    return transactionsAsync.when(
      loading: () => const Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: Gap.sm),
            child: SkeletonBox(height: 38, radius: Radii.sm),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: Gap.sm),
            child: SkeletonBox(height: 38, radius: Radii.sm),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: Gap.sm),
            child: SkeletonBox(height: 38, radius: Radii.sm),
          ),
        ],
      ),
      error: (err, _) => ErrorView(
        error: err,
        onRetry: () => ref.invalidate(playerTransactionsProvider(playerId)),
      ),
      data: (transactions) {
        if (transactions.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: Gap.lg),
            child: EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Rien à signaler',
              message: 'Aucun mouvement sur ce compte pour le moment.',
            ),
          );
        }
        return Column(
          children: [
            for (final tx in transactions.take(10))
              TransactionTile(transaction: tx),
            if (transactions.length > 10)
              Padding(
                padding: const EdgeInsets.only(top: Gap.sm),
                child: TextButton(
                  onPressed: () => context.push('/history?playerId=$playerId'),
                  child: const Text('Voir tout l\'historique'),
                ),
              ),
          ],
        );
      },
    );
  }
}
