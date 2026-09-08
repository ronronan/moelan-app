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
