import 'package:app/core/auth/web_redirect_uri.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveWebRedirectUri', () {
    test('resolves against the site root', () {
      expect(
        resolveWebRedirectUri(Uri.parse('http://localhost:8090/')).toString(),
        'http://localhost:8090/redirect.html',
      );
    });

    test('ignores the hash fragment used for app routing', () {
      // The whole reason this function exists: go_router's hash routes
      // (#/players/abc) must never leak into the OIDC redirect_uri Keycloak
      // is asked to send the browser back to.
      expect(
        resolveWebRedirectUri(Uri.parse('http://localhost:8090/#/login')).toString(),
        'http://localhost:8090/redirect.html',
      );
    });

    test('handles a bare origin with no path at all', () {
      expect(
        resolveWebRedirectUri(Uri.parse('http://localhost:8090')).toString(),
        'http://localhost:8090/redirect.html',
      );
    });

    test('resolves against the current directory for a deployment under a subpath', () {
      expect(
        resolveWebRedirectUri(Uri.parse('http://example.com/app/')).toString(),
        'http://example.com/app/redirect.html',
      );
    });

    test('tracks whatever port the app is actually served on', () {
      expect(
        resolveWebRedirectUri(Uri.parse('http://localhost:12345/')).toString(),
        'http://localhost:12345/redirect.html',
      );
    });
  });
}
