import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/auth/auth_providers.dart';
import 'core/cagnotte_repository.dart';
import 'features/auth/login_screen.dart';
import 'features/history/history_screen.dart';
import 'features/organizations/create_organization_screen.dart';
import 'features/organizations/pending_approval_screen.dart';
import 'features/organizations/superadmin_home_screen.dart';
import 'features/organizations/superadmin_organizations_screen.dart';
import 'features/players/dashboard_screen.dart';
import 'features/players/player_detail_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/stats/stats_screen.dart';

/// Notifies GoRouter to re-run `redirect` whenever the oidc init/user state
/// changes, without recreating the GoRouter instance itself (which would
/// otherwise reset in-app navigation state on every auth event).
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(oidcInitProvider, (_, _) => notifyListeners());
    ref.listen(currentUserProvider, (_, _) => notifyListeners());
    ref.listen(meStatusProvider, (_, _) => notifyListeners());
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
      if (!loggedIn) return null;

      // A super-admin doesn't need a space of their own to be useful (their
      // job is approving other people's) — they're exempt from the
      // create-space/pending gate below and reach the approval screen via
      // the dashboard's AppBar icon instead. If they *do* have a space of
      // their own, it behaves like anyone else's.
      if (ref.read(isSuperAdminProvider)) return null;

      final meStatus = ref.read(meStatusProvider);
      if (!meStatus.hasValue) return null;
      final organization = meStatus.value?.organization;

      final onCreateOrg = state.matchedLocation == '/create-organization';
      final onPending = state.matchedLocation == '/pending-approval';

      if (organization == null) {
        return onCreateOrg ? null : '/create-organization';
      }
      if (!organization.approved) {
        return onPending ? null : '/pending-approval';
      }
      if (onCreateOrg || onPending) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/create-organization',
        builder: (context, state) => const CreateOrganizationScreen(),
      ),
      GoRoute(
        path: '/pending-approval',
        builder: (context, state) => const PendingApprovalScreen(),
      ),
      GoRoute(
        path: '/superadmin/organizations',
        builder: (context, state) => const SuperAdminOrganizationsScreen(),
      ),
      GoRoute(
        path: '/players/:id',
        builder: (context, state) =>
            PlayerDetailScreen(playerId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/stats',
        builder: (context, state) => const StatsScreen(),
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => HistoryScreen(
          initialPlayerId: state.uri.queryParameters['playerId'],
        ),
      ),
    ],
  );
});

/// `/`: a super-admin with no space of their own has nothing to dashboard
/// (`DashboardScreen` would just 403 on `/api/players`, see `no_organization`
/// handling there) — send them to the cross-org browser instead. Once we
/// know (via `meStatus`) that the account does have its own space, it's
/// dashboarded like anyone else's. While that's still loading, default to
/// `DashboardScreen` to avoid a flash for the common (non-super-admin) case.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSuperAdmin = ref.watch(isSuperAdminProvider);
    final meStatus = ref.watch(meStatusProvider);
    final knownNoOwnOrg =
        isSuperAdmin && meStatus.hasValue && meStatus.value?.organization == null;
    if (knownNoOwnOrg) return const SuperAdminHomeScreen();
    return const DashboardScreen();
  }
}
