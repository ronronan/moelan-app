import 'package:flutter/material.dart';

import '../core/design/theme.dart';
import '../core/design/tokens.dart';
import '../core/format.dart';

/// The colour a balance should be shown in: in the black, in the red, or
/// neutral at exactly zero (which is neither good news nor bad).
Color balanceColor(BuildContext context, int cents) {
  final colors = MoelanColors.of(context);
  if (cents < 0) return colors.negative;
  if (cents > 0) return colors.positive;
  return Theme.of(context).colorScheme.onSurfaceVariant;
}

/// An amount of money.
///
/// Always uses tabular figures, so a column of balances lines up digit under
/// digit — the whole roster is read as a column, and proportional digits make
/// it jitter. Never takes a double: cents in, formatted string out.
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.cents, {
    this.style,
    this.colored = true,
    this.showSign = false,
    super.key,
  });

  final int cents;
  final TextStyle? style;

  /// False to inherit the surrounding colour — for an amount shown on a
  /// coloured surface, where the semantic red/green would clash.
  final bool colored;

  /// True to force a leading `+` on a credit, for a ledger line where the
  /// direction of the movement matters more than the resulting balance.
  final bool showSign;

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.bodyLarge;
    final text = showSign && cents > 0
        ? '+${formatCents(cents)}'
        : formatCents(cents);
    return Text(
      text,
      style: (base ?? const TextStyle()).copyWith(
        color: colored ? balanceColor(context, cents) : null,
        fontFeatures: const [FontFeature.tabularFigures()],
        fontWeight: base?.fontWeight ?? FontWeight.w600,
      ),
    );
  }
}

/// A balance shown as a tinted pill — used on the roster, where the eye
/// scans for who's deep in the red rather than reading each number.
class BalancePill extends StatelessWidget {
  const BalancePill(this.cents, {super.key});

  final int cents;

  @override
  Widget build(BuildContext context) {
    final colors = MoelanColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (cents) {
      < 0 => (colors.negativeContainer, colors.onNegativeContainer),
      > 0 => (colors.positiveContainer, colors.onPositiveContainer),
      _ => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: MoneyText(
        cents,
        colored: false,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(color: foreground),
      ),
    );
  }
}
