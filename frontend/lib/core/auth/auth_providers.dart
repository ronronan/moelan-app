import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oidc/oidc.dart';

import 'auth_service.dart';

/// Decodes a JWT's payload without verifying its signature. Safe here: this
/// is only used to drive UI gating (which buttons to show); every write the
/// UI triggers is re-authorized server-side against the real, verified
/// token, so a tampered claim here can show the wrong button but never
/// bypass anything.
Map<String, dynamic> _unverifiedJwtClaims(String jwt) {
  final payload = jwt.split('.')[1];
  final normalized = base64Url.normalize(payload);
  return jsonDecode(utf8.decode(base64Url.decode(normalized)))
      as Map<String, dynamic>;
}

final oidcManagerProvider = Provider<OidcUserManager>((ref) {
  final manager = buildOidcUserManager();
  ref.onDispose(manager.dispose);
  return manager;
});

/// Completes once the manager has restored (or failed to restore) a
/// persisted session. The router waits on this before deciding whether to
/// show the login screen.
final oidcInitProvider = FutureProvider<void>((ref) async {
  final manager = ref.watch(oidcManagerProvider);
  await manager.init();
});

final currentUserProvider = StreamProvider<OidcUser?>((ref) {
  final manager = ref.watch(oidcManagerProvider);
  return manager.userChanges();
});

/// Realm roles of the signed-in user, read from the access token's
/// `realm_access.roles` claim. Keycloak puts realm_access on the access
/// token, not the id token, so this can't be read via `user.claims`.
final currentRolesProvider = Provider<List<String>>((ref) {
  final accessToken = ref.watch(currentUserProvider).value?.token.accessToken;
  if (accessToken == null) return const [];
  final realmAccess = _unverifiedJwtClaims(accessToken)['realm_access'];
  if (realmAccess is Map && realmAccess['roles'] is List) {
    return (realmAccess['roles'] as List).cast<String>();
  }
  return const [];
});

final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(currentRolesProvider).contains('admin');
});

/// False only for the read-only `player` role — everyone else can record
/// bière/soft/amende/crédit actions.
final canWriteProvider = Provider<bool>((ref) {
  return !ref.watch(currentRolesProvider).contains('player');
});

/// Realm-wide role, unrelated to any space — grants access to the
/// cross-org space-approval screen.
final isSuperAdminProvider = Provider<bool>((ref) {
  return ref.watch(currentRolesProvider).contains('superadmin');
});

/// Keycloak `groups` claim (full group paths, e.g. `/org-<uuid>/admin`),
/// read the same unverified way as `currentRolesProvider` — UI gating only.
final currentGroupsProvider = Provider<List<String>>((ref) {
  final accessToken = ref.watch(currentUserProvider).value?.token.accessToken;
  if (accessToken == null) return const [];
  final groups = _unverifiedJwtClaims(accessToken)['groups'];
  if (groups is List) return groups.cast<String>();
  return const [];
});

final _orgGroupPattern = RegExp(
  r'^/org-([0-9a-fA-F-]{36})/(admin|member|player)$',
);

/// The single `/org-<uuid>/<role>` group this user belongs to, if any —
/// null means the account hasn't created or been invited into a space yet.
final currentOrgIdProvider = Provider<String?>((ref) {
  for (final group in ref.watch(currentGroupsProvider)) {
    final match = _orgGroupPattern.firstMatch(group);
    if (match != null) return match.group(1);
  }
  return null;
});
