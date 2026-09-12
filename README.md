# Moelan App

Caisse noire numérique pour l'équipe de handball : suivi des joueurs, de leur
solde, des consommations (bière/soft), des amendes et des crédits, avec un
historique complet. L'objectif : financer un week-end à Moelan-sur-Mer avec
le surplus en fin de saison.

## Stack

- **Backend** : Rust (axum + sqlx) — `backend/`
- **Frontend** : Flutter, un seul code pour web et mobile — `frontend/`
- **Base de données** : PostgreSQL
- **Auth** : Keycloak (partage l'instance Postgres)
- **Déploiement** : Docker Compose (auto-hébergé)

## Développement local

### 1. Infra (Postgres + Keycloak)

```bash
cp .env.example .env   # une seule fois
docker compose up -d postgres keycloak
```

Attendre que Keycloak soit prêt (`curl http://localhost:8080/realms/moelan` doit
répondre 200 après quelques secondes).

### 2. Créer un compte utilisateur dans Keycloak

Le realm importé (`infra/keycloak/realm-export.json`) ne contient volontairement
aucun utilisateur (pour ne pas versionner de mots de passe). À faire une fois :

1. Ouvrir http://localhost:8080/admin (admin / changeme, ou les valeurs de `.env`)
2. Réaliser (Realm settings) → sélectionner le realm **moelan**
3. Users → Add user : renseigner un username, cocher "Email verified", enregistrer
4. Onglet **Credentials** → Set password (décocher "Temporary")
5. Onglet **Role mapping** → Assign role → cocher `admin` (pour accéder aux
   réglages tarifs/amendes) ou `member` (accès standard)

### 3. Backend

```bash
cd backend
DATABASE_URL="postgres://moelan:changeme@localhost:5432/app" \
BIND_ADDR="127.0.0.1:8000" \
KEYCLOAK_ISSUER_URL="http://localhost:8080/realms/moelan" \
KEYCLOAK_AUDIENCE="moelan-api" \
cargo run
```

Les migrations (schéma + seed bière/soft/amendes) s'appliquent automatiquement
au démarrage. Vérifier avec `curl http://localhost:8000/health`.

### 4. Frontend

```bash
cd frontend
flutter run -d chrome --web-port=8090
```

Se connecter avec le compte créé à l'étape 2. Les valeurs par défaut de
`AppConfig` (`frontend/lib/core/config.dart`) pointent déjà vers
`localhost:8000` (API) et `localhost:8080` (Keycloak) — rien à changer pour du
développement local.

## Déploiement (Docker Compose complet)

Pour lancer toute la stack conteneurisée (Postgres, Keycloak, API Rust, web
Flutter servi par nginx), sans rien installer d'autre que Docker :

```bash
cp .env.example .env   # une seule fois ; personnaliser les mots de passe
docker compose up --build -d
```

Les 4 services démarrent dans l'ordre (healthchecks), l'API applique les
migrations au boot. Puis, comme en développement :

- Créer un compte utilisateur dans Keycloak (voir étape 2 ci-dessus,
  `http://localhost:8080/admin`)
- Ouvrir l'app sur http://localhost:8090

### Reverse proxy Caddy (optionnel)

Un reverse proxy Caddy (`infra/caddy/Caddyfile`) peut regrouper web/API/Keycloak
sous un seul nom d'hôte — pratique dès que l'app quitte `localhost`, et donne
le HTTPS automatique gratuitement sur un vrai domaine. Désactivé par défaut ;
pour l'activer :

```bash
docker compose --profile proxy up -d
```

Par défaut (`MOELAN_DOMAIN` non défini) Caddy sert en HTTP simple sur
`http://localhost:8888` (`CADDY_HTTP_PORT`), sans jamais tenter d'obtenir de
certificat — pratique pour tester le routage localement (vérifié : `/`, `/api/*`
et `/realms/*` sont bien proxifiés vers web/api/keycloak respectivement).

### Déploiement en production (vrai domaine)

Trois choses à aligner ensemble si vous mettez l'app derrière Caddy sur un vrai
domaine (ex. `moelan.example.com`), sans quoi Keycloak rejettera les tokens
(l'`iss` du token doit correspondre exactement à ce que l'API attend) :

1. Dans `.env` : `MOELAN_DOMAIN=moelan.example.com` (sans `http://`, pour que
   Caddy obtienne un vrai certificat), `KEYCLOAK_HOSTNAME=moelan.example.com`,
   `PUBLIC_API_BASE_URL=https://moelan.example.com/api`,
   `PUBLIC_KEYCLOAK_ISSUER_URL=https://moelan.example.com/realms/moelan`
2. Dans le service `keycloak` du `docker-compose.yml` : ajouter
   `KC_PROXY_HEADERS: xforwarded` (pour que Keycloak fasse confiance aux
   en-têtes `X-Forwarded-*` de Caddy — à ne faire que si Keycloak n'est plus
   exposé directement, sans quoi ces en-têtes sont falsifiables)
3. Dans la console Keycloak (`moelan-web`) : mettre à jour les *Valid redirect
   URIs* et *Web origins* du client pour le vrai domaine (ils sont actuellement
   réglés sur `http://localhost:*` pour le développement) — puis ré-exporter
   le realm (`infra/keycloak/realm-export.json`) si vous voulez que ce
   changement soit reproductible

Le flux de login via Caddy sur un vrai domaine n'a pas pu être testé de bout en
bout dans cet environnement (pas de nom de domaine public disponible) ; seul le
routage des chemins a été vérifié.

Voir le plan d'implémentation complet dans `PLAN.md` (jalons M0 à M10).
