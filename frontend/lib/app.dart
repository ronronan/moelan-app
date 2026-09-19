import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/auth_providers.dart';
import 'core/design/theme.dart';
import 'router.dart';

/// The app is French-only: there's no language switcher, and every string it
/// owns is written in French. Declaring a single supported locale makes
/// Flutter's own widgets — the date range picker, its OK/Cancel labels,
/// every built-in tooltip — follow, instead of staying English inside an
/// otherwise French screen.
const _locale = Locale('fr', 'FR');
const _localizationsDelegates = <LocalizationsDelegate<dynamic>>[
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

class MoelanApp extends ConsumerWidget {
  const MoelanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final light = MoelanTheme.light();
    final dark = MoelanTheme.dark();
    final oidcInit = ref.watch(oidcInitProvider);

    // Follows the system setting rather than offering an in-app switch:
    // there's nowhere sensible to put one (no account screen), and a club
    // treasurer entering rounds at night wants whatever their phone already
    // decided.
    if (oidcInit.isLoading) {
      return MaterialApp(
        title: 'Moelan',
        debugShowCheckedModeBanner: false,
        theme: light,
        darkTheme: dark,
        themeMode: ThemeMode.system,
        locale: _locale,
        localizationsDelegates: _localizationsDelegates,
        supportedLocales: const [_locale],
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Moelan',
      debugShowCheckedModeBanner: false,
      theme: light,
      darkTheme: dark,
      themeMode: ThemeMode.system,
      locale: _locale,
      localizationsDelegates: _localizationsDelegates,
      supportedLocales: const [_locale],
      routerConfig: router,
    );
  }
}
