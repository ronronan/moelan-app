import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/cagnotte_repository.dart';
import '../../core/format.dart';
import '../../models/consumable_type.dart';
import '../../models/fine_type.dart';
import '../../models/transaction.dart';
import 'players_providers.dart';

class PlayerDetailScreen extends ConsumerWidget {
  const PlayerDetailScreen({required this.playerId, super.key});

  final String playerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerAsync = ref.watch(playerDetailProvider(playerId));

    return Scaffold(
      appBar: AppBar(
        title: playerAsync.when(
          data: (player) => Text(player.fullName),
          loading: () => const Text('...'),
          error: (_, _) => const Text('Joueur'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Historique complet',
            onPressed: () => context.push('/history?playerId=$playerId'),
          ),
        ],
      ),
      body: playerAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erreur : $err')),
        data: (player) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Text(
                  formatCents(player.balanceCents),
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: player.balanceCents < 0
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _ActionButtons(playerId: playerId),
              const SizedBox(height: 24),
              Text('Historique récent', style: Theme.of(context).textTheme.titleMedium),
              _RecentTransactions(playerId: playerId),
            ],
          );
        },
      ),
    );
  }
}

class _ActionButtons extends ConsumerWidget {
  const _ActionButtons({required this.playerId});

  final String playerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consumablesAsync = ref.watch(consumableTypesProvider);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        consumablesAsync.when(
          data: (types) {
            final beer = types.where((t) => t.code == 'beer').firstOrNull;
            return _ActionButton(
              icon: Icons.sports_bar,
              label: beer == null ? 'Bière' : 'Bière (${formatCents(beer.priceCents)})',
              onPressed: beer == null
                  ? null
                  : () => _recordConsumption(context, ref, beer),
            );
          },
          loading: () => const _ActionButton(icon: Icons.sports_bar, label: 'Bière'),
          error: (_, _) => const _ActionButton(icon: Icons.sports_bar, label: 'Bière'),
        ),
        consumablesAsync.when(
          data: (types) {
            final soft = types.where((t) => t.code == 'soft').firstOrNull;
            return _ActionButton(
              icon: Icons.local_drink,
              label: soft == null ? 'Soft' : 'Soft (${formatCents(soft.priceCents)})',
              onPressed: soft == null
                  ? null
                  : () => _recordConsumption(context, ref, soft),
            );
          },
          loading: () => const _ActionButton(icon: Icons.local_drink, label: 'Soft'),
          error: (_, _) => const _ActionButton(icon: Icons.local_drink, label: 'Soft'),
        ),
        _ActionButton(
          icon: Icons.gavel,
          label: 'Amende',
          onPressed: () => _showFineSheet(context, ref),
        ),
        _ActionButton(
          icon: Icons.add_card,
          label: 'Créditer',
          onPressed: () => _showCreditDialog(context, ref),
        ),
      ],
    );
  }

  Future<void> _recordConsumption(
    BuildContext context,
    WidgetRef ref,
    ConsumableType consumable,
  ) async {
    await ref.read(cagnotteRepositoryProvider).recordConsumption(playerId, consumable.id);
    invalidatePlayerData(ref, playerId);
  }

  Future<void> _showFineSheet(BuildContext context, WidgetRef ref) async {
    final fineTypes = await ref.read(fineTypesProvider.future);
    final active = fineTypes.where((f) => f.active).toList();
    if (!context.mounted) return;

    final selected = await showModalBottomSheet<FineType>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Choisir une amende', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            for (final fine in active)
              ListTile(
                title: Text(fine.label),
                trailing: Text(formatCents(fine.amountCents)),
                onTap: () => Navigator.of(context).pop(fine),
              ),
          ],
        ),
      ),
    );

    if (selected == null) return;
    await ref.read(cagnotteRepositoryProvider).recordFine(playerId, selected.id);
    invalidatePlayerData(ref, playerId);
  }

  Future<void> _showCreditDialog(BuildContext context, WidgetRef ref) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Créditer le joueur'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Montant (€)'),
            ),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(labelText: 'Note (optionnel)'),
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
            child: const Text('Créditer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final euros = double.tryParse(amountController.text.replaceAll(',', '.'));
    if (euros == null || euros <= 0) return;

    await ref
        .read(cagnotteRepositoryProvider)
        .recordCredit(
          playerId,
          (euros * 100).round(),
          note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
        );
    invalidatePlayerData(ref, playerId);
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _RecentTransactions extends ConsumerWidget {
  const _RecentTransactions({required this.playerId});

  final String playerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(playerTransactionsProvider(playerId));
    return transactionsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Erreur : $err'),
      ),
      data: (transactions) {
        if (transactions.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Aucune transaction pour le moment.'),
          );
        }
        return Column(
          children: [
            for (final tx in transactions.take(10)) _TransactionTile(transaction: tx),
          ],
        );
      },
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final positive = transaction.amountCents > 0;
    return ListTile(
      dense: true,
      leading: Icon(_iconFor(transaction.kind)),
      title: Text(_labelFor(transaction.kind)),
      subtitle: transaction.note != null ? Text(transaction.note!) : null,
      trailing: Text(
        formatCents(transaction.amountCents),
        style: TextStyle(
          color: positive
              ? Colors.green.shade700
              : Theme.of(context).colorScheme.error,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  IconData _iconFor(TransactionKind kind) => switch (kind) {
    TransactionKind.beer => Icons.sports_bar,
    TransactionKind.soft => Icons.local_drink,
    TransactionKind.fine => Icons.gavel,
    TransactionKind.credit => Icons.add_card,
    TransactionKind.manualAdjustment => Icons.build,
  };

  String _labelFor(TransactionKind kind) => switch (kind) {
    TransactionKind.beer => 'Bière',
    TransactionKind.soft => 'Soft',
    TransactionKind.fine => 'Amende',
    TransactionKind.credit => 'Crédit',
    TransactionKind.manualAdjustment => 'Ajustement',
  };
}
