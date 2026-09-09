import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/auth/auth_providers.dart';
import 'features/auth/login_screen.dart';
import 'features/players/dashboard_screen.dart';
import 'features/players/player_detail_screen.dart';
import 'features/settings/settings_screen.dart';

/// Notifies GoRouter to re-run `redirect` whenever the oidc init/user state
/// changes, without recreating the GoRouter instance itself (which would
/// otherwise reset in-app navigation state on every auth event).
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(oidcInitProvider, (_, _) => notifyListeners());
    ref.listen(currentUserProvider, (_, _) => notifyListeners());
  }
}

final _routerRefreshProvider = Provider<_RouterRefresh>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);
  return refresh;
});

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(_routerRefreshProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final oidcInit = ref.read(oidcInitProvider);
      if (oidcInit.isLoading) return null;

      final loggedIn = ref.read(currentUserProvider).value != null;
      final onLogin = state.matchedLocation == '/login';
      if (!loggedIn && !onLogin) return '/login';
      if (loggedIn && onLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const DashboardScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/players/:id',
        builder: (context, state) =>
            PlayerDetailScreen(playerId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
    ],
  );
});
