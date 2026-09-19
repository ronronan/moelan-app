import 'package:flutter/material.dart';

import '../core/design/theme.dart';
import '../core/design/tokens.dart';
import '../core/format.dart';
import 'common.dart';

/// The hero of the dashboard: how much is in the kitty, and how far that is
/// from the trip it's paying for.
///
/// The objective isn't decoration — it's the reason the app exists — so it's
/// stated as a distance left to cover ("encore 753,00 €") rather than as a
/// bare percentage, which is a number nobody acts on.
class CagnotteCard extends StatelessWidget {
  const CagnotteCard({
    required this.totalCents,
    this.targetCents,
    this.playerCount,
    super.key,
  });

  final int totalCents;
  final int? targetCents;
  final int? playerCount;

  @override
  Widget build(BuildContext context) {
    final colors = MoelanColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final target = targetCents;
    // A zero or negative objective can't be filled — treated as "no
    // objective" rather than drawing a nonsensical bar.
    final hasTarget = target != null && target > 0;
    final progress = hasTarget
        ? (totalCents / target).clamp(0.0, 1.0).toDouble()
        : 0.0;
    final remaining = hasTarget ? target - totalCents : 0;

    return SeaGradient(
      borderRadius: BorderRadius.circular(Radii.lg),
      padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.xl, Gap.xl, Gap.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.waves_rounded,
                size: 18,
                color: colors.onSea.withValues(alpha: 0.75),
              ),
              const SizedBox(width: Gap.sm),
              Text(
                'CAGNOTTE',
                style: textTheme.labelMedium?.copyWith(
                  color: colors.onSea.withValues(alpha: 0.75),
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (playerCount != null)
                Text(
                  '$playerCount joueur${playerCount! > 1 ? 's' : ''}',
                  style: textTheme.labelMedium?.copyWith(
                    color: colors.onSea.withValues(alpha: 0.75),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Gap.md),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatCents(totalCents),
              style: textTheme.displaySmall?.copyWith(
                color: colors.onSea,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (hasTarget) ...[
            const SizedBox(height: Gap.xl),
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.sm),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: colors.onSea.withValues(alpha: 0.18),
                valueColor: AlwaysStoppedAnimation(colors.sand),
              ),
            ),
            const SizedBox(height: Gap.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    remaining > 0
                        ? 'Encore ${formatCents(remaining)} avant Moelan-sur-Mer 🌊'
                        : 'Objectif atteint. Direction Moelan-sur-Mer 🌊',
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.onSea.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Text(
                  '${(progress * 100).round()} %',
                  style: textTheme.titleSmall?.copyWith(
                    color: colors.sand,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: Gap.sm),
            Text(
              'Direction Moelan-sur-Mer 🌊',
              style: textTheme.bodySmall?.copyWith(
                color: colors.onSea.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
