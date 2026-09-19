# 11 — Infrastructure et déploiement

## La stack

| Brique | Choix | Où |
|---|---|---|
| API | Rust — axum 0.8, sqlx 0.9, pas d'ORM | `backend/` |
| Frontend | Flutter — un seul code web + mobile | `frontend/` |
| Base | PostgreSQL 18 | conteneur `postgres` |
| Auth | Keycloak 26, partage l'instance Postgres (base `keycloak` séparée) | conteneur `keycloak` |
| Web | build Flutter web servi par nginx | conteneur `web` |
| Reverse proxy | Traefik, **optionnel** (profil `proxy`) | conteneur `traefik` |

`docker compose up --build -d` démarre les quatre services dans l'ordre
(healthchecks), et l'API applique ses migrations au boot.

## Base de données

Six tables : `organizations`, `players`, `consumable_types`, `fine_types`,
`transactions`, `device_tokens`. Quatre migrations, appliquées automatiquement
au démarrage via `sqlx::migrate!()`.

Principes tenus partout : l'argent en centimes (`BIGINT`), jamais de flottant ;
le grand livre comme source de vérité et le solde comme cache ; une contrainte
`CHECK` qui rend une ligne de transaction incohérente impossible à insérer.

Sauvegardes : `./infra/postgres/backup.sh` produit une archive gzip par base et
conserve les 14 dernières. À planifier par cron.

## Configuration

Tout par variables d'environnement (`.env`, modèle dans `.env.example`). Deux
blocs sont **entièrement optionnels** et suivent la même règle : non configuré
signifie « ne rien envoyer », pas « échouer » —

- SMTP, pour les alertes de dette ;
- Firebase, pour le push.

C'est ce qui permet de faire tourner l'application complète sans compte chez
qui que ce soit.

Point de vigilance en production : `KEYCLOAK_ISSUER_URL` doit correspondre
exactement à l'`iss` des jetons, c'est-à-dire au hostname que le **navigateur**
utilise pour joindre Keycloak. `KEYCLOAK_JWKS_URL` existe précisément pour le
cas où l'API, elle, le joint autrement (nom de service interne Docker).

## CI

`.github/workflows/ci.yml`, sur chaque push et chaque PR :

- backend — `cargo fmt --check`, `cargo clippy --all-targets`, `cargo test`
  contre un vrai Postgres de service. `cargo test` couvre les tests unitaires
  **et** les scénarios Gherkin de ce dossier.
- frontend — `flutter analyze`, `flutter test`.

## Build mobile

`flutter build apk --release` fonctionne tel quel, signé avec la clé de debug —
suffisant pour installer sur un téléphone, pas pour publier. Pour une vraie
release : générer un keystore et renseigner `android/key.properties` (gitignoré,
comme les `.jks`).

L'app iOS n'a pas été configurée : ça demande un Mac.

## Ce qui n'a pas pu être vérifié

- HTTPS/ACME sur un vrai domaine (pas de nom de domaine public disponible). Le
  routage HTTP et le login complet ont été validés en simulant un hostname
  unique via `http://localhost:8888`.
- Le build Android signé pour le Play Store.
- Les notifications push de bout en bout (cf. [10](10-notifications-push.md)).
