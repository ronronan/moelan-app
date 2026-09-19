import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cagnotte_repository.dart';
import '../../core/design/tokens.dart';
import '../../core/format.dart';
import '../../models/consumable_type.dart';
import '../../models/fine_type.dart';
import '../../widgets/common.dart';
import '../../widgets/feedback.dart';
import '../../widgets/money.dart';
import '../../widgets/page_body.dart';
import '../../widgets/states.dart';
import '../players/players_providers.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      // Treasury first: it's the screen an admin comes here for. Tariffs and
      // the fine list are set up once and rarely touched again.
      initialIndex: 0,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Réglages'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Trésorerie'),
              Tab(text: 'Tarifs'),
              Tab(text: 'Amendes'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_TreasuryTab(), _ConsumableTypesTab(), _FineTypesTab()],
        ),
      ),
    );
  }
}

/// Parses a euros field into cents. `null` cents with `ok: true` means the
/// field was left blank, which is a valid way to say "no objective".
({bool ok, int? cents}) _parseEurosField(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return (ok: true, cents: null);
  final euros = double.tryParse(trimmed.replaceAll(',', '.'));
  if (euros == null || euros <= 0) return (ok: false, cents: null);
  return (ok: true, cents: (euros * 100).round());
}

String? _optionalAmountValidator(String? value) {
  final result = _parseEurosField(value ?? '');
  return result.ok ? null : 'Montant invalide';
}

String? _requiredAmountValidator(String? value) {
  final euros = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
  if (euros == null || euros < 0) return 'Montant invalide';
  return null;
}

String? _requiredTextValidator(String? value) =>
    (value == null || value.trim().isEmpty) ? 'Champ obligatoire' : null;

class _TreasuryTab extends ConsumerStatefulWidget {
  const _TreasuryTab();

  @override
  ConsumerState<_TreasuryTab> createState() => _TreasuryTabState();
}

class _TreasuryTabState extends ConsumerState<_TreasuryTab> {
  final _targetController = TextEditingController();
  final _thresholdController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  bool _initialized = false;

  @override
  void dispose() {
    _targetController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final target = _parseEurosField(_targetController.text);
    final threshold = _parseEurosField(_thresholdController.text);

    // Stored as a negative cap in the backend (a debt *limit*); the field
    // asks for a plain positive euro amount, which reads more naturally.
    final debtAlertThresholdCents = threshold.cents == null
        ? null
        : -threshold.cents!;

    setState(() => _busy = true);
    try {
      await ref
          .read(cagnotteRepositoryProvider)
          .patchMyOrganization(
            targetCents: target.cents,
            debtAlertThresholdCents: debtAlertThresholdCents,
          );
      ref.invalidate(meStatusProvider);
      if (mounted) showSuccess(context, 'Réglages enregistrés.');
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meStatusAsync = ref.watch(meStatusProvider);

    return meStatusAsync.when(
      loading: () => const LoadingView(),
      error: (err, _) => ErrorView(
        error: err,
        onRetry: () => ref.invalidate(meStatusProvider),
      ),
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

        return PageBody(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.only(top: Gap.lg, bottom: Gap.xxl),
              children: [
                _SettingsSection(
                  icon: Icons.flag_outlined,
                  title: 'Objectif de la cagnotte',
                  description:
                      'Affiché en barre de progression sur le tableau de '
                      'bord. Laisser vide pour ne fixer aucun objectif.',
                  child: TextFormField(
                    controller: _targetController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Objectif',
                      suffixText: '€',
                    ),
                    validator: _optionalAmountValidator,
                  ),
                ),
                const SizedBox(height: Gap.lg),
                _SettingsSection(
                  icon: Icons.notifications_active_outlined,
                  title: "Alerte de dette",
                  description:
                      "Un email part vers l'adresse de contact de l'espace "
                      'dès qu\'un joueur descend sous ce montant de dette. '
                      'Laisser vide pour ne jamais alerter.',
                  child: TextFormField(
                    controller: _thresholdController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Alerter au-delà de',
                      suffixText: '€ de dette',
                    ),
                    validator: _optionalAmountValidator,
                  ),
                ),
                const SizedBox(height: Gap.xl),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Enregistrer'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: Gap.sm),
                Text(title, style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: Gap.sm),
            Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: Gap.lg),
            child,
          ],
        ),
      ),
    );
  }
}

class _ConsumableTypesTab extends ConsumerWidget {
  const _ConsumableTypesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typesAsync = ref.watch(consumableTypesProvider);
    return typesAsync.when(
      loading: () => const LoadingView(),
      error: (err, _) => ErrorView(
        error: err,
        onRetry: () => ref.invalidate(consumableTypesProvider),
      ),
      data: (types) => PageBody(
        child: ListView(
          padding: const EdgeInsets.only(top: Gap.lg, bottom: Gap.xxl),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.lg, left: Gap.xs),
              child: Text(
                "Le prix appliqué est figé au moment de l'action : changer un "
                'tarif ne modifie aucune consommation déjà enregistrée.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
            for (final type in types)
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.sm),
                child: _RateCard(
                  icon: type.code == 'beer'
                      ? Icons.sports_bar_outlined
                      : Icons.local_drink_outlined,
                  label: type.label,
                  amountCents: type.priceCents,
                  active: type.active,
                  onTap: () => _showEditPriceDialog(context, ref, type),
                ),
              ),
          ],
        ),
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
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tarif : ${type.label}'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Prix',
              suffixText: '€',
            ),
            validator: _requiredAmountValidator,
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
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final euros = double.tryParse(controller.text.replaceAll(',', '.'));
    if (euros == null || euros < 0) return;

    try {
      await ref
          .read(cagnotteRepositoryProvider)
          .patchConsumableType(type.id, priceCents: (euros * 100).round());
      if (context.mounted) {
        showSuccess(
          context,
          '${type.label} : ${formatCents((euros * 100).round())}',
        );
      }
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
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
        loading: () => const LoadingView(),
        error: (err, _) => ErrorView(
          error: err,
          onRetry: () => ref.invalidate(fineTypesProvider),
        ),
        data: (types) {
          if (types.isEmpty) {
            return EmptyState(
              icon: Icons.gavel_outlined,
              title: 'Aucune amende au barème',
              message: 'Ajoutez les règles de la maison.',
              action: FilledButton.icon(
                onPressed: () => _showAddFineDialog(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Ajouter une amende'),
              ),
            );
          }
          return PageBody(
            child: ListView(
              padding: const EdgeInsets.only(top: Gap.lg, bottom: 88),
              children: [
                for (final type in types)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Gap.sm),
                    child: _RateCard(
                      icon: Icons.gavel_outlined,
                      label: type.label,
                      amountCents: type.amountCents,
                      active: type.active,
                      onTap: () => _showEditFineDialog(context, ref, type),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: typesAsync.hasValue && typesAsync.value!.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => _showAddFineDialog(context, ref),
              tooltip: 'Ajouter une amende',
              child: const Icon(Icons.add),
            )
          : null,
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
    final formKey = GlobalKey<FormState>();
    var active = type.active;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Modifier une amende'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: labelController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Libellé'),
                  validator: _requiredTextValidator,
                ),
                const SizedBox(height: Gap.md),
                TextFormField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Montant',
                    suffixText: '€',
                  ),
                  validator: _requiredAmountValidator,
                ),
                const SizedBox(height: Gap.sm),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Proposée aux membres'),
                  subtitle: const Text(
                    "Une amende désactivée reste dans l'historique.",
                  ),
                  value: active,
                  onChanged: (value) => setState(() => active = value),
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
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    final euros = double.tryParse(amountController.text.replaceAll(',', '.'));
    if (euros == null || euros < 0) return;

    try {
      await ref
          .read(cagnotteRepositoryProvider)
          .patchFineType(
            type.id,
            label: labelController.text.trim(),
            amountCents: (euros * 100).round(),
            active: active,
          );
      if (context.mounted) showSuccess(context, 'Amende mise à jour.');
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
    ref.invalidate(fineTypesProvider);
  }

  Future<void> _showAddFineDialog(BuildContext context, WidgetRef ref) async {
    final labelController = TextEditingController();
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Nouvelle amende'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: labelController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Libellé',
                    hintText: 'Retard à l\'entraînement',
                  ),
                  validator: _requiredTextValidator,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: Gap.md),
                TextFormField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Montant',
                    suffixText: '€',
                  ),
                  validator: _requiredAmountValidator,
                ),
                const SizedBox(height: Gap.md),
                // The backend needs a stable per-space code; asking a
                // treasurer to invent `late_training` was exposing a
                // database column as a form field. It's derived from the
                // label and shown, not hidden.
                Text(
                  'Identifiant : ${_slugify(labelController.text)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
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
      ),
    );

    if (confirmed != true) return;
    final euros = double.tryParse(amountController.text.replaceAll(',', '.'));
    final label = labelController.text.trim();
    if (euros == null || euros < 0 || label.isEmpty) return;

    try {
      await ref
          .read(cagnotteRepositoryProvider)
          .createFineType(_slugify(label), label, (euros * 100).round());
      if (context.mounted) showSuccess(context, '« $label » ajoutée au barème.');
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
    ref.invalidate(fineTypesProvider);
  }
}

/// Same rule as the backend's own `slugify` for space names: lowercase,
/// alphanumerics kept, everything else collapsed into a single separator.
String _slugify(String label) {
  const accents = 'àáâãäçèéêëìíîïñòóôõöùúûüýÿ';
  const plain = 'aaaaaceeeeiiiinooooouuuuyy';
  final buffer = StringBuffer();
  var lastWasSeparator = true;
  for (final rune in label.toLowerCase().runes) {
    var char = String.fromCharCode(rune);
    final accentIndex = accents.indexOf(char);
    if (accentIndex >= 0) char = plain[accentIndex];
    final isAlphanumeric = RegExp(r'[a-z0-9]').hasMatch(char);
    if (isAlphanumeric) {
      buffer.write(char);
      lastWasSeparator = false;
    } else if (!lastWasSeparator) {
      buffer.write('_');
      lastWasSeparator = true;
    }
  }
  final slug = buffer.toString().replaceAll(RegExp(r'_+$'), '');
  return slug.isEmpty ? 'amende' : slug;
}

/// One row of the tariff and fine lists: what it is, what it costs, and
/// whether it's still offered.
class _RateCard extends StatelessWidget {
  const _RateCard({
    required this.icon,
    required this.label,
    required this.amountCents,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int amountCents;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.lg,
        vertical: Gap.md,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 22,
            color: active
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: active ? null : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (!active)
                  Text(
                    'Désactivée',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          MoneyText(
            amountCents,
            colored: false,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(width: Gap.sm),
          Icon(
            Icons.chevron_right,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
