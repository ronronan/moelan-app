import 'package:flutter/material.dart';

import '../core/design/tokens.dart';
import '../core/error_message.dart';

/// Confirms that something happened.
///
/// Recording a beer used to be silent — the list refreshed and that was it,
/// which on a noisy pitch-side phone is indistinguishable from a tap that
/// didn't register. Every write now says so.
void showSuccess(BuildContext context, String message) {
  _show(context, message, icon: Icons.check_circle_outline);
}

/// Reports a failed action in French, never as a raw exception.
void showFailure(BuildContext context, Object error) {
  final scheme = Theme.of(context).colorScheme;
  _show(
    context,
    humanizeError(error),
    icon: Icons.error_outline,
    background: scheme.errorContainer,
    foreground: scheme.onErrorContainer,
    duration: const Duration(seconds: 5),
  );
}

void _show(
  BuildContext context,
  String message, {
  required IconData icon,
  Color? background,
  Color? foreground,
  Duration duration = const Duration(seconds: 3),
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: duration,
        backgroundColor: background,
        content: Row(
          children: [
            Icon(icon, size: 20, color: foreground),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Text(message, style: TextStyle(color: foreground)),
            ),
          ],
        ),
      ),
    );
}
