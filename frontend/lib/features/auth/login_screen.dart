import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/feedback.dart';

/// The one screen every user sees before anything else, so it carries the
/// whole identity: the sea the season is aiming for, the name, and a single
/// thing to do.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _busy = false;

  Future<void> _login() async {
    setState(() => _busy = true);
    try {
      await ref.read(oidcManagerProvider).loginAuthorizationCodeFlow();
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = MoelanColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SeaGradient(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Gap.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: Layout.formMaxWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _Wordmark(),
                    const SizedBox(height: Gap.xxl),
                    Text(
                      'Moelan',
                      textAlign: TextAlign.center,
                      style: textTheme.displaySmall?.copyWith(
                        color: colors.onSea,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: Gap.md),
                    Text(
                      'La caisse noire du club.\nCap sur Moelan-sur-Mer.',
                      textAlign: TextAlign.center,
                      style: textTheme.titleMedium?.copyWith(
                        color: colors.onSea.withValues(alpha: 0.82),
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: Gap.xxxl),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _busy ? null : _login,
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.sand,
                          foregroundColor: colors.onSand,
                          minimumSize: const Size(0, 56),
                        ),
                        child: _busy
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: colors.onSand,
                                ),
                              )
                            : const Text('Se connecter'),
                      ),
                    ),
                    const SizedBox(height: Gap.lg),
                    Text(
                      'Pas encore de compte ? Créez-en un depuis\nl\'écran de connexion, puis créez votre espace.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.onSea.withValues(alpha: 0.7),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The app's mark: a wave under a coin. Drawn rather than shipped as an
/// asset — it's four shapes, and an SVG dependency (or a PNG at five
/// densities) would cost more than it's worth.
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    final colors = MoelanColors.of(context);
    return SizedBox(
      width: 108,
      height: 108,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.onSea.withValues(alpha: 0.10),
            ),
          ),
          Container(
            margin: const EdgeInsets.all(Gap.md),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.onSea.withValues(alpha: 0.12),
            ),
          ),
          Icon(Icons.savings_outlined, size: 44, color: colors.sand),
        ],
      ),
    );
  }
}
