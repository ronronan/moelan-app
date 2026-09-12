import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/auth_providers.dart';
import 'router.dart';

class MoelanApp extends ConsumerWidget {
  const MoelanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A desaturated, mid-tone green (not the saturated Colors.green, which
    // gives too-low contrast text on a light surface) — Material 3 derives
    // the full accessible tonal palette (onPrimary, container colors, etc.)
    // from this single seed, in both light and dark mode.
    final theme = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF2E7D5B),
    );
    final oidcInit = ref.watch(oidcInitProvider);

    if (oidcInit.isLoading) {
      return MaterialApp(
        title: 'Moelan App',
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Moelan App',
      debugShowCheckedModeBanner: false,
      theme: theme,
      routerConfig: router,
    );
  }
}
