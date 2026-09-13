import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cagnotte_repository.dart';
import '../../core/format.dart';
import '../../models/consumable_type.dart';
import '../../models/fine_type.dart';
import '../players/players_providers.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Réglages'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Tarifs'),
              Tab(text: "Types d'amendes"),
              Tab(text: 'Trésorerie'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_ConsumableTypesTab(), _FineTypesTab(), _TreasuryTab()],
        ),
      ),
    );
  }
}

class _TreasuryTab extends ConsumerStatefulWidget {
  const _TreasuryTab();

  @override
  ConsumerState<_TreasuryTab> createState() => _TreasuryTabState();
}

class _TreasuryTabState extends ConsumerState<_TreasuryTab> {
  final _targetController = TextEditingController();
  final _thresholdController = TextEditingController();
  bool _busy = false;
  bool _initialized = false;

  @override
  void dispose() {
    _targetController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  /// Parses a euros field into cents, or null if blank. Returns
  /// `(false, null)` on an invalid (non-blank, unparsable or negative)
  /// value so the caller can bail out without saving.
  (bool, int?) _parseEuros(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return (true, null);
    final euros = double.tryParse(trimmed.replaceAll(',', '.'));
    if (euros == null || euros <= 0) return (false, null);
    return (true, (euros * 100).round());
  }

  Future<void> _save() async {
    final (targetOk, targetCents) = _parseEuros(_targetController.text);
    final (thresholdOk, thresholdEuros) = _parseEuros(
      _thresholdController.text,
    );
    if (!targetOk || !thresholdOk) return;
    // Stored as a negative cap in the backend (a debt *limit*); the field
    // asks for a plain positive euro amount, which reads more naturally.
    final debtAlertThresholdCents = thresholdEuros == null
        ? null
        : -thresholdEuros;

    setState(() => _busy = true);
    try {
      await ref
          .read(cagnotteRepositoryProvider)
          .patchMyOrganization(
            targetCents: targetCents,
            debtAlertThresholdCents: debtAlertThresholdCents,
          );
      ref.invalidate(meStatusProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meStatusAsync = ref.watch(meStatusProvider);

    return meStatusAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Erreur : $err')),
      data: (status) {
        final targetCents = status?.organization?.targetCents;
        final thresholdCents = status?.organization?.debtAlertThresholdCents;
        if (!_initialized) {
          _initialized = true;
          if (targetCents != null) {
            _targetController.text = (targetCents / 100).toStringAsFixed(2);
          }
          if (thresholdCents != null) {
            _thresholdController.text = (-thresholdCents / 100)
                .toStringAsFixed(2);
          }
        }
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Objectif de remplissage de la cagnotte, affiché en barre de "
                'progression sur le tableau de bord. Laisser vide pour ne '
                "fixer aucun objectif.",
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _targetController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Objectif (€)'),
              ),
              const SizedBox(height: 24),
              const Text(
                "Seuil d'alerte de dette : un email est envoyé à l'adresse "
                'de contact dès qu\'un joueur descend sous ce montant. '
                'Laisser vide pour ne jamais alerter.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _thresholdController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: "Seuil d'alerte (€)",
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: const Text('Enregistrer'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ConsumableTypesTab extends ConsumerWidget {
  const _ConsumableTypesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typesAsync = ref.watch(consumableTypesProvider);
    return typesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Erreur : $err')),
      data: (types) => ListView(
        children: [
          for (final type in types)
            ListTile(
              title: Text(type.label),
              subtitle: Text(type.active ? 'Actif' : 'Inactif'),
              trailing: Text(
                formatCents(type.priceCents),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () => _showEditPriceDialog(context, ref, type),
            ),
        ],
      ),
    );
  }

  Future<void> _showEditPriceDialog(
    BuildContext context,
    WidgetRef ref,
    ConsumableType type,
  ) async {
    final controller = TextEditingController(
      text: (type.priceCents / 100).toStringAsFixed(2),
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tarif : ${type.label}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Prix (€)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final euros = double.tryParse(controller.text.replaceAll(',', '.'));
    if (euros == null || euros < 0) return;

    await ref
        .read(cagnotteRepositoryProvider)
        .patchConsumableType(type.id, priceCents: (euros * 100).round());
    ref.invalidate(consumableTypesProvider);
  }
}

class _FineTypesTab extends ConsumerWidget {
  const _FineTypesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typesAsync = ref.watch(fineTypesProvider);
    return Scaffold(
      body: typesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erreur : $err')),
        data: (types) => ListView(
          children: [
            for (final type in types)
              ListTile(
                title: Text(type.label),
                subtitle: Text(type.active ? 'Actif' : 'Inactif'),
                trailing: Text(
                  formatCents(type.amountCents),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () => _showEditFineDialog(context, ref, type),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddFineDialog(context, ref),
        tooltip: 'Ajouter une amende',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showEditFineDialog(
    BuildContext context,
    WidgetRef ref,
    FineType type,
  ) async {
    final labelController = TextEditingController(text: type.label);
    final amountController = TextEditingController(
      text: (type.amountCents / 100).toStringAsFixed(2),
    );
    var active = type.active;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Modifier une amende'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelController,
                decoration: const InputDecoration(labelText: 'Libellé'),
              ),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Montant (€)'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: active,
                onChanged: (value) => setState(() => active = value),
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
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    final euros = double.tryParse(amountController.text.replaceAll(',', '.'));
    if (euros == null || euros < 0 || labelController.text.trim().isEmpty)
      return;

    await ref
        .read(cagnotteRepositoryProvider)
        .patchFineType(
          type.id,
          label: labelController.text.trim(),
          amountCents: (euros * 100).round(),
          active: active,
        );
    ref.invalidate(fineTypesProvider);
  }

  Future<void> _showAddFineDialog(BuildContext context, WidgetRef ref) async {
    final codeController = TextEditingController();
    final labelController = TextEditingController();
    final amountController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nouvelle amende'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Code (ex: late_training)',
              ),
            ),
            TextField(
              controller: labelController,
              decoration: const InputDecoration(labelText: 'Libellé'),
            ),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Montant (€)'),
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

    if (confirmed != true) return;
    final euros = double.tryParse(amountController.text.replaceAll(',', '.'));
    if (euros == null ||
        euros < 0 ||
        codeController.text.trim().isEmpty ||
        labelController.text.trim().isEmpty) {
      return;
    }

    await ref
        .read(cagnotteRepositoryProvider)
        .createFineType(
          codeController.text.trim(),
          labelController.text.trim(),
          (euros * 100).round(),
        );
    ref.invalidate(fineTypesProvider);
  }
}
