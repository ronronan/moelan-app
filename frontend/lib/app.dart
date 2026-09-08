import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/auth_providers.dart';
import 'router.dart';

class MoelanApp extends ConsumerWidget {
  const MoelanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo);
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
