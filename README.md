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

Voir le plan d'implémentation complet dans `PLAN.md` (jalons M0 à M10).
