# Moelan App — plan de mise en œuvre

## Contexte

Moelan App est une caisse noire numérique pour l'équipe de handball : suivi des joueurs et de leur solde, actions rapides (bière, soft, amende, crédit), historique complet des mouvements, dans le but de financer un week-end à Moelan-sur-Mer avec le surplus en fin de saison. Le dossier `/home/rmorel/Projects/moelan-app` est vide (pas encore de repo git) : c'est un projet greenfield.

Décisions déjà validées avec l'utilisateur :
- **Monorepo** avec `backend/`, `frontend/`, `infra/`.
- **Frontend Flutter** (un seul code pour web + mobile).
- **Backend Rust** connecté à Postgres.
- **PostgreSQL** comme base de données.
- **Keycloak dès la v1**, partageant l'instance Postgres (base `keycloak` séparée).
- **Déploiement auto-hébergé via Docker Compose**.

Environnement déjà installé et vérifié : Rust 1.95 / cargo 1.95, Flutter 3.44.8 (Dart 3.12.2), Docker Compose v5.5.1.

## Architecture retenue

### Repo layout
```
moelan-app/
├── docker-compose.yml
├── .env.example
├── backend/            (API Rust)
│   ├── migrations/
│   └── src/{auth,db,services,routes}/
├── frontend/           (Flutter web+mobile)
│   └── lib/{core,features,models,widgets}/
└── infra/
    ├── postgres/init-multiple-dbs.sh   (crée la base `keycloak` en plus de `app`)
    ├── keycloak/realm-export.json      (realm/clients/roles committés)
    ├── web/Dockerfile                  (build flutter web -> nginx)
    └── caddy/Caddyfile                 (reverse proxy, optionnel mais recommandé hors localhost)
```

### Backend Rust
- **axum 0.8** (web framework) + **tokio** — choix par défaut de l'écosystème, s'intègre nativement avec les libs JWT/Keycloak.
- **sqlx 0.9** (Postgres, requêtes SQL vérifiées à la compilation, migrations intégrées via `sqlx::migrate!()`), pas d'ORM — les besoins sont simples (peu de tables, peu de jointures).
- **Validation JWT Keycloak** : JWKS fetch/cache (`axum-keycloak-auth` ou `axum-jwt-auth` + `jsonwebtoken`), extracteurs `CurrentUser` / `RequireRole` (rôles réalm `admin` / `member`).
- **Argent en centimes** (`BIGINT`/`i64`), jamais de float.
- Erreurs via `thiserror` + `IntoResponse`, logs via `tracing`.
- **Point unique de vérité pour le solde** : `services/transactions.rs` insère la ligne dans le ledger et met à jour `players.balance_cents` dans la même transaction SQL — le solde est un cache toujours dérivable du ledger (source de vérité = table `transactions`), ce qui satisfait à la fois la rapidité d'affichage et l'exigence de traçabilité complète.

### Schéma de base de données
- `players` (id, first_name, last_name, balance_cents, active)
- `consumable_types` (id, code, label, price_cents, active) — remplace "bière/soft" en dur, configurable
- `fine_types` (id, code, label, amount_cents, active) — liste d'amendes configurable
- `transactions` (id, player_id, kind enum[beer,soft,fine,credit,manual_adjustment], amount_cents signé, unit_price_cents en snapshot, consumable_type_id / fine_type_id nullable, note, created_by = sub Keycloak, created_at) — **c'est l'historique/traçabilité demandé**, avec un CHECK constraint reliant `kind` aux colonnes de référence attendues.
- Migration de seed : bière/soft à 1€ par défaut + 2-3 amendes d'exemple, éditables ensuite depuis l'app.

### API REST (aperçu)
```
GET  /health
GET  /api/me
GET/POST/PATCH /api/players[...]
GET/POST/PATCH /api/consumable-types[...]     (admin)
GET/POST/PATCH /api/fine-types[...]           (admin)
POST /api/players/:id/consumptions            { consumable_type_id }
POST /api/players/:id/fines                   { fine_type_id, note? }
POST /api/players/:id/credits                 { amount_cents, note? }
POST /api/players/:id/adjustments (admin)     { amount_cents, note }
GET  /api/players/:id/transactions
GET  /api/transactions?player_id=&kind=&from=&to=
```

### Keycloak
- Realm `moelan`, deux clients publics PKCE : `moelan-web` et `moelan-mobile` (scheme `fr.moelan.app://callback`).
- Mapper d'audience ajoutant `moelan-api` dans l'`aud` des tokens (sinon l'API ne peut pas valider l'audience).
- Rôles réalm `admin` (gère joueurs/tarifs/amendes) et `member` (actions du quotidien).
- Setup une fois dans la console admin, puis export vers `infra/keycloak/realm-export.json`, importé automatiquement au démarrage (`start --import-realm`) — reproductible sur toute nouvelle machine.
- Postgres partagé : script d'init créant la base `keycloak` séparée de `app` au premier démarrage du conteneur.

### Frontend Flutter
- **Riverpod** pour l'état (rapport simplicité/robustesse adapté à la taille de l'app), **dio** pour l'HTTP (intercepteur pour attacher/rafraîchir le token), **go_router** pour la navigation.
- **Package `oidc`** pour l'authentification (PKCE) — contrairement à `flutter_appauth` (mobile uniquement), il couvre web + mobile depuis une seule API, ce qui est indispensable vu l'exigence "même code web/mobile".
- Écrans : Login, Dashboard (liste joueurs + soldes + total cagnotte), Détail joueur (boutons bière/soft/amende/créditer + historique récent), Réglages admin (tarifs, types d'amendes), Historique global (filtres + pagination).
- Argent affiché via `intl` (`NumberFormat.currency`), jamais de calcul en `double`.

### Docker Compose
Services : `postgres` (18-alpine, avec healthcheck), `keycloak` (26.0, `start --import-realm`, DB dédiée), `api` (backend Rust, migrations exécutées au boot), `web` (build multi-stage Flutter web → nginx statique), `caddy` (optionnel, reverse proxy + TLS auto, recommandé dès que l'app sort de localhost).

## Ordre de construction (jalons incrémentaux)

1. **M0** — Scaffolding : git init, arborescence, `docker-compose.yml` avec juste `postgres`, `.env.example`.
2. **M1** — Schéma : migrations sqlx (tables + seed), vérifiées via `psql`.
3. **M2** — API core sans auth : routes CRUD/actions fonctionnelles, testées au `curl`/`httpie` — première tranche démontrable.
4. **M3** — Keycloak : service + DB dédiée, realm/clients/rôles construits dans la console admin puis exportés dans `infra/keycloak/realm-export.json`.
5. **M4** — Auth branchée sur l'API : validation JWT, extracteurs de rôle, `/api/me`, routes admin protégées.
6. **M5** — Flutter skeleton + login : routing, branding, intégration `oidc` (le plus délicat : flux PKCE en web) — jalon à isoler avant de le brancher au reste.
7. **M6** — Écrans cœur : dashboard + détail joueur branchés à l'API réelle.
8. **M7** — Écrans admin : tarifs et types d'amendes.
9. **M8** — Historique/audit avec filtres et pagination.
10. **M9** — Polish : image web nginx, Caddy, README, états vides/erreurs, formatage monétaire, touche finale "objectif Moelan-sur-Mer" sur le dashboard.
11. **M10** (bonus, plus tard) — CI (cargo test/clippy, flutter analyze), sauvegarde Postgres, build Android release, build iOS (nécessite un Mac, non bloquant).

Chaque jalon jusqu'à M8 produit quelque chose de testable, pour éviter un big-bang d'intégration.

## Vérification

- **M1** : `docker compose up postgres`, puis `sqlx migrate run` et `psql` pour vérifier les tables/contraintes/seed.
- **M2** : lancer l'API (`cargo run`), exercer chaque route via `curl`/`httpie`, vérifier que le solde d'un joueur reste cohérent avec la somme des transactions après une série d'actions (bière/soft/amende/crédit).
- **M3/M4** : obtenir un token via le realm Keycloak (`curl` sur `/protocol/openid-connect/token` avec un compte de test), vérifier que l'API accepte le token valide et rejette un token invalide/expiré, et que les routes admin renvoient 403 pour un rôle `member`.
- **M5-M8** : lancer `flutter run -d chrome` et `flutter run` sur un émulateur Android, tester le parcours complet (login → dashboard → actions sur un joueur → historique) et confirmer que les soldes affichés correspondent à ceux vus côté API.
- **Bout en bout** : `docker compose up --build`, vérifier que les 4-5 services démarrent dans le bon ordre (healthchecks) et que l'app web est accessible et fonctionnelle sans rien installer d'autre que Docker sur la machine de déploiement.

## Fichiers critiques à créer en premier

- `docker-compose.yml`
- `backend/migrations/0001_init.sql`
- `backend/src/services/transactions.rs`
- `backend/src/auth/jwt.rs`
- `infra/keycloak/realm-export.json`
- `frontend/lib/core/auth/auth_service.dart`
