import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:oidc/oidc.dart';
import 'package:oidc_default_store/oidc_default_store.dart';

import '../config.dart';
import 'web_redirect_uri.dart';

/// Builds the single [OidcUserManager] used across the app: Keycloak realm
/// as the authority, PKCE-only public clients (no client secret anywhere),
/// and a platform-specific client/redirect pair (moelan-web on the web,
/// moelan-mobile with a custom-scheme redirect on Android/iOS).
OidcUserManager buildOidcUserManager() {
  final clientId = kIsWeb ? AppConfig.webClientId : AppConfig.mobileClientId;

  final redirectUri = kIsWeb
      ? resolveWebRedirectUri(Uri.base)
      : Uri.parse(AppConfig.mobileRedirectUri);

  return OidcUserManager.lazy(
    discoveryDocumentUri: OidcUtils.getOpenIdConfigWellKnownUri(
      Uri.parse(AppConfig.keycloakIssuer),
    ),
    clientCredentials: OidcClientAuthentication.none(clientId: clientId),
    store: OidcDefaultStore(),
    settings: OidcUserManagerSettings(
      scope: const ['openid', 'profile', 'email'],
      redirectUri: redirectUri,
      postLogoutRedirectUri: kIsWeb
          ? resolveWebRedirectUri(Uri.base)
          : Uri.parse(AppConfig.mobileRedirectUri),
    ),
  );
}
