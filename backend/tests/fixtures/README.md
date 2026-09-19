# Fixtures des tests Cucumber

- `test-jwt-key.pem` — paire de clés RSA **générée pour les tests uniquement**,
  jamais utilisée par Keycloak ni par l'application. Les steps s'en servent
  pour signer les jetons d'accès des différents rôles, et le Keycloak stub
  publie sa partie publique sur son endpoint JWKS. Aucun secret réel ici :
  la regénérer (`openssl genrsa -out test-jwt-key.pem 2048`) n'impacte que
  les tests — il faut alors regénérer `test-jwks.json` avec.
- `test-jwks.json` — le JWKS correspondant (modulo `n` et exposant `e` de la
  clé ci-dessus), servi tel quel par le stub.
