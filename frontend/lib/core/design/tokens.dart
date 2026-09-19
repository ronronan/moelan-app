import 'package:flutter/widgets.dart';

/// The spacing scale. Every gap in the app is one of these — a screen that
/// reaches for a raw number is a screen that will drift out of rhythm with
/// the others.
abstract final class Gap {
  /// 4 — inside a chip, between an icon and its label.
  static const xs = 4.0;

  /// 8 — between tightly related lines.
  static const sm = 8.0;

  /// 12 — between fields of a form.
  static const md = 12.0;

  /// 16 — the default padding of a screen's content.
  static const lg = 16.0;

  /// 24 — between two blocks of a screen.
  static const xl = 24.0;

  /// 32 — around a lone centered block (login, empty state).
  static const xxl = 32.0;

  /// 48 — the breathing room above a hero.
  static const xxxl = 48.0;
}

/// Corner radii. Three values, deliberately: anything more and the app stops
/// reading as one surface.
abstract final class Radii {
  /// 8 — chips, small controls.
  static const sm = 8.0;

  /// 16 — cards, sheets, dialogs.
  static const md = 16.0;

  /// 28 — the cagnotte hero and the bottom sheets that mirror it.
  static const lg = 28.0;
}

/// Motion. Short enough to feel instant, long enough to be followed.
abstract final class Motion {
  static const fast = Duration(milliseconds: 120);
  static const normal = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 400);
  static const curve = Curves.easeOutCubic;
}

/// Layout widths. The app is designed for a phone at the edge of the pitch;
/// on a wide browser window the content is centered rather than stretched,
/// because a roster line 1900 pixels wide is unreadable.
abstract final class Layout {
  /// Below this, we're on a phone: full-bleed content, one column.
  static const compactBreakpoint = 600.0;

  /// Above this, there's room for side-by-side content.
  static const expandedBreakpoint = 1000.0;

  /// Reading width for a list or a feed.
  static const contentMaxWidth = 720.0;

  /// Reading width for a form or a lone centered block.
  static const formMaxWidth = 440.0;

  /// Reading width for a dense, tabular screen (history, stats).
  static const wideMaxWidth = 1040.0;
}

/// True on a phone-sized viewport — the default target, not the exception.
bool isCompact(BuildContext context) =>
    MediaQuery.sizeOf(context).width < Layout.compactBreakpoint;

/// True when there's room to put two things side by side.
bool isExpanded(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= Layout.expandedBreakpoint;
