/// Build-time configuration, overridable via `--dart-define`.
///
/// Defaults point at the local docker-compose stack so `flutter run` works
/// out of the box during development.
class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  static const keycloakIssuer = String.fromEnvironment(
    'KEYCLOAK_ISSUER_URL',
    defaultValue: 'http://localhost:8080/realms/moelan',
  );

  static const webClientId = 'moelan-web';
  static const mobileClientId = 'moelan-mobile';
  static const mobileRedirectScheme = 'fr.moelan.app';
  static const mobileRedirectUri = '$mobileRedirectScheme://callback';
}
