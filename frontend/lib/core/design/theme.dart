import 'package:flutter/material.dart';

import 'tokens.dart';

/// The app's own colours, the ones Material's scheme has no slot for: what
/// "in the black" and "in the red" look like, the sand accent, and the sea
/// the cagnotte header is set against.
///
/// A `ThemeExtension` rather than a set of constants, so light and dark each
/// carry their own values and a widget never has to ask which mode it's in.
@immutable
class MoelanColors extends ThemeExtension<MoelanColors> {
  const MoelanColors({
    required this.positive,
    required this.onPositiveContainer,
    required this.positiveContainer,
    required this.negative,
    required this.onNegativeContainer,
    required this.negativeContainer,
    required this.sand,
    required this.onSand,
    required this.seaGradient,
    required this.onSea,
  });

  /// A balance in credit, and the tint behind it.
  final Color positive;
  final Color positiveContainer;
  final Color onPositiveContainer;

  /// A balance in debt. Distinct from `colorScheme.error`: owing two euros to
  /// the kitty is a fact of life, not a failure, and it shouldn't shout like
  /// a validation error.
  final Color negative;
  final Color negativeContainer;
  final Color onNegativeContainer;

  /// The warm accent — the beach at the end of the season.
  final Color sand;
  final Color onSand;

  /// Top-to-bottom wash behind the cagnotte hero and the login screen.
  final List<Color> seaGradient;
  final Color onSea;

  @override
  MoelanColors copyWith({
    Color? positive,
    Color? positiveContainer,
    Color? onPositiveContainer,
    Color? negative,
    Color? negativeContainer,
    Color? onNegativeContainer,
    Color? sand,
    Color? onSand,
    List<Color>? seaGradient,
    Color? onSea,
  }) {
    return MoelanColors(
      positive: positive ?? this.positive,
      positiveContainer: positiveContainer ?? this.positiveContainer,
      onPositiveContainer: onPositiveContainer ?? this.onPositiveContainer,
      negative: negative ?? this.negative,
      negativeContainer: negativeContainer ?? this.negativeContainer,
      onNegativeContainer: onNegativeContainer ?? this.onNegativeContainer,
      sand: sand ?? this.sand,
      onSand: onSand ?? this.onSand,
      seaGradient: seaGradient ?? this.seaGradient,
      onSea: onSea ?? this.onSea,
    );
  }

  @override
  MoelanColors lerp(MoelanColors? other, double t) {
    if (other == null) return this;
    return MoelanColors(
      positive: Color.lerp(positive, other.positive, t)!,
      positiveContainer: Color.lerp(
        positiveContainer,
        other.positiveContainer,
        t,
      )!,
      onPositiveContainer: Color.lerp(
        onPositiveContainer,
        other.onPositiveContainer,
        t,
      )!,
      negative: Color.lerp(negative, other.negative, t)!,
      negativeContainer: Color.lerp(
        negativeContainer,
        other.negativeContainer,
        t,
      )!,
      onNegativeContainer: Color.lerp(
        onNegativeContainer,
        other.onNegativeContainer,
        t,
      )!,
      sand: Color.lerp(sand, other.sand, t)!,
      onSand: Color.lerp(onSand, other.onSand, t)!,
      seaGradient: [
        for (var i = 0; i < seaGradient.length; i++)
          Color.lerp(seaGradient[i], other.seaGradient[i], t)!,
      ],
      onSea: Color.lerp(onSea, other.onSea, t)!,
    );
  }

  /// Shorthand for the extension lookup, which is otherwise a mouthful at
  /// every call site.
  static MoelanColors of(BuildContext context) =>
      Theme.of(context).extension<MoelanColors>()!;
}

/// Deep sea green — the single seed Material derives both tonal palettes
/// from. Chosen dark enough that white text sits on it comfortably, so the
/// same colour works as a fill and as a text colour on light surfaces.
const _seed = Color(0xFF0E6B6F);

abstract final class MoelanTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    ).copyWith(
      // Material's generated tertiary drifts towards pink for a teal seed;
      // the sand accent is the whole point of the palette, so it's set by
      // hand rather than derived.
      tertiary: isDark ? const Color(0xFFE9C68A) : const Color(0xFF9A6C22),
      onTertiary: isDark ? const Color(0xFF3F2B06) : Colors.white,
      tertiaryContainer: isDark
          ? const Color(0xFF5A400F)
          : const Color(0xFFFAE5C1),
      onTertiaryContainer: isDark
          ? const Color(0xFFFFE3B6)
          : const Color(0xFF3F2B06),
    );

    final extension = MoelanColors(
      positive: isDark ? const Color(0xFF6FD3AE) : const Color(0xFF0B6E52),
      positiveContainer: isDark
          ? const Color(0xFF0C4435)
          : const Color(0xFFCDEEDF),
      onPositiveContainer: isDark
          ? const Color(0xFFB8EED8)
          : const Color(0xFF05301F),
      negative: isDark ? const Color(0xFFE79A7A) : const Color(0xFFA6431B),
      negativeContainer: isDark
          ? const Color(0xFF572113)
          : const Color(0xFFFBE0D4),
      onNegativeContainer: isDark
          ? const Color(0xFFFFD9C7)
          : const Color(0xFF41150A),
      sand: isDark ? const Color(0xFFE9C68A) : const Color(0xFFD9A94F),
      onSand: const Color(0xFF3F2B06),
      seaGradient: isDark
          ? const [Color(0xFF07373B), Color(0xFF0B2A33)]
          : const [Color(0xFF0E6B6F), Color(0xFF12414F)],
      onSea: Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
    );

    return base.copyWith(
      extensions: [extension],
      scaffoldBackgroundColor: scheme.surface,
      textTheme: _textTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
      ),
      dividerTheme: DividerThemeData(
        space: 1,
        thickness: 1,
        color: scheme.outlineVariant.withValues(alpha: 0.5),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Gap.lg,
          vertical: Gap.xs,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.sm + 4),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.sm + 4),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        labelStyle: base.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Gap.lg,
          vertical: Gap.lg,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(Gap.lg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        linearTrackColor: scheme.surfaceContainerHighest,
        linearMinHeight: 10,
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        labelStyle: base.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: base.textTheme.titleSmall,
      ),
    );
  }

  /// Tightens the display/headline end of Material's scale — the default
  /// letter spacing is tuned for long-form text, and reads loose on the short
  /// numeric strings this app is mostly made of.
  static TextTheme _textTheme(TextTheme base) {
    return base.copyWith(
      displaySmall: base.displaySmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -1,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}
