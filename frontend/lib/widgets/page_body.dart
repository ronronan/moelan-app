import 'package:flutter/material.dart';

import '../core/design/tokens.dart';

/// Centers a screen's content and caps its width.
///
/// The app is built for a phone, but it ships as a web build too, and a
/// roster line stretched across a 1900-pixel browser window is unreadable —
/// the eye loses the row between the name on the left and the balance on the
/// right. On a phone this is a no-op; past the cap it centers.
class PageBody extends StatelessWidget {
  const PageBody({
    required this.child,
    this.maxWidth = Layout.contentMaxWidth,
    this.padding = const EdgeInsets.symmetric(horizontal: Gap.lg),
    super.key,
  });

  /// A narrower body, for a form or a lone centered block.
  const PageBody.form({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: Gap.xl),
    super.key,
  }) : maxWidth = Layout.formMaxWidth;

  /// A wider body, for the dense screens (history, statistics) that have
  /// genuine use for the extra room.
  const PageBody.wide({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: Gap.lg),
    super.key,
  }) : maxWidth = Layout.wideMaxWidth;

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// A vertically centered variant, for the screens that are a single block:
/// login, "create your space", "awaiting approval".
class CenteredPageBody extends StatelessWidget {
  const CenteredPageBody({
    required this.child,
    this.maxWidth = Layout.formMaxWidth,
    super.key,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.xl,
          vertical: Gap.xxl,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}
