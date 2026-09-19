import 'package:flutter/material.dart';

import '../core/design/theme.dart';
import '../core/design/tokens.dart';

/// A small all-caps label introducing a block, with an optional trailing
/// count or action. Gives the long scrolling screens a skeleton the eye can
/// hold on to.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.label, {this.trailing, super.key});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(
        top: Gap.xl,
        bottom: Gap.sm,
        left: Gap.xs,
        right: Gap.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Someone's initials in a tinted disc. Cheap identity for a roster that has
/// no photos and never will.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar(this.name, {this.radius = 20, this.muted = false, super.key});

  final String name;
  final double radius;

  /// Greys the disc out — used for a deactivated player.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Same name, same colour, every time: the tint is derived from the name
    // itself rather than from the row's position, so it survives sorting.
    final palette = [
      scheme.primaryContainer,
      scheme.secondaryContainer,
      scheme.tertiaryContainer,
    ];
    final onPalette = [
      scheme.onPrimaryContainer,
      scheme.onSecondaryContainer,
      scheme.onTertiaryContainer,
    ];
    final index = name.isEmpty ? 0 : name.codeUnits.reduce((a, b) => a + b) % 3;

    return CircleAvatar(
      radius: radius,
      backgroundColor: muted ? scheme.surfaceContainerHighest : palette[index],
      child: Text(
        _initials(name),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.7,
          color: muted ? scheme.onSurfaceVariant : onPalette[index],
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}

/// The wash of sea colour behind the app's hero surfaces — the cagnotte
/// header, the login screen. One definition, so they can't drift apart.
class SeaGradient extends StatelessWidget {
  const SeaGradient({
    required this.child,
    this.borderRadius,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = MoelanColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors.seaGradient,
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// A tappable card — the surface the roster, the settings rows and the
/// history lines are built from. Wraps `Card` with the ink response Material
/// doesn't give for free when the card has a custom shape.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.padding = const EdgeInsets.all(Gap.lg),
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: selected ? scheme.primaryContainer : null,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
