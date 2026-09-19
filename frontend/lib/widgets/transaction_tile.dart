import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/design/theme.dart';
import '../core/design/tokens.dart';
import '../models/transaction.dart';
import 'money.dart';

/// One vocabulary for the five kinds of movement, shared by the player sheet
/// and the history screen — before this, each screen had its own copy of the
/// icon/label switch and they had already drifted apart.
extension TransactionKindVisuals on TransactionKind {
  String get label => switch (this) {
    TransactionKind.beer => 'Bière',
    TransactionKind.soft => 'Soft',
    TransactionKind.fine => 'Amende',
    TransactionKind.credit => 'Crédit',
    TransactionKind.manualAdjustment => 'Ajustement',
  };

  IconData get icon => switch (this) {
    TransactionKind.beer => Icons.sports_bar_outlined,
    TransactionKind.soft => Icons.local_drink_outlined,
    TransactionKind.fine => Icons.gavel_outlined,
    TransactionKind.credit => Icons.savings_outlined,
    TransactionKind.manualAdjustment => Icons.tune,
  };

  /// The tint of the icon's disc. Debits share the app's "negative" tone,
  /// credits its "positive" one, and an adjustment stays neutral — it's a
  /// correction, not a purchase.
  (Color, Color) tones(BuildContext context) {
    final colors = MoelanColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    return switch (this) {
      TransactionKind.beer ||
      TransactionKind.soft ||
      TransactionKind.fine => (
        colors.negativeContainer,
        colors.onNegativeContainer,
      ),
      TransactionKind.credit => (
        colors.positiveContainer,
        colors.onPositiveContainer,
      ),
      TransactionKind.manualAdjustment => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
    };
  }
}

final _dayFormat = DateFormat('d MMM', 'fr_FR');
final _timeFormat = DateFormat('HH:mm', 'fr_FR');

/// A ledger line. Reads left to right as: what happened, when, how much.
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    required this.transaction,
    this.leadingLabel,
    super.key,
  });

  final Transaction transaction;

  /// The player's name, on the global history where the line could be
  /// anyone's. Omitted on a player's own sheet, where it would repeat.
  final String? leadingLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (background, foreground) = transaction.kind.tones(context);
    final quantity = transaction.quantity;
    final subtitle = [
      ?leadingLabel,
      '${_dayFormat.format(transaction.createdAt)} · '
          '${_timeFormat.format(transaction.createdAt)}',
      ?transaction.note,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.sm),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(Radii.sm + 2),
            ),
            child: Icon(transaction.kind.icon, size: 19, color: foreground),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quantity > 1
                      ? '${transaction.kind.label} × $quantity'
                      : transaction.kind.label,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Gap.sm),
          MoneyText(
            transaction.amountCents,
            showSign: true,
            style: theme.textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}
