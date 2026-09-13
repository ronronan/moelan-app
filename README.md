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

### 2. Créer un compte super-admin dans Keycloak

L'app est **multi-espaces** : chaque équipe a sa propre caisse noire ("espace"),
créée en self-service par n'importe quel compte Keycloak puis validée par un
**super-admin** (l'opérateur de l'instance — vous). Le realm importé
(`infra/keycloak/realm-export.json`) ne contient volontairement aucun
utilisateur (pour ne pas versionner de mots de passe). À faire une fois, pour
vous donner ce rôle :

1. Ouvrir http://localhost:8080/admin (admin / changeme, ou les valeurs de `.env`)
2. Sélectionner le realm **moelan**
3. Users → Add user : renseigner un username/email, cocher "Email verified", enregistrer
4. Onglet **Credentials** → Set password (décocher "Temporary")
5. Onglet **Role mapping** → Assign role → cocher `superadmin`

Un compte `superadmin` n'a pas besoin d'appartenir à un espace : il accède à
l'écran "Espaces en attente" (icône bouclier dans la barre du haut) pour
valider les nouveaux espaces créés en self-service (voir plus bas).

Tout le monde d'autre (vous y compris, pour votre propre équipe) passe par
**Register** sur l'écran de connexion Keycloak, puis par "Créer mon espace"
dans l'app — pas besoin de créer ces comptes à la main.

### 3. Backend

```bash
cd backend
DATABASE_URL="postgres://moelan:changeme@localhost:5432/app" \
BIND_ADDR="127.0.0.1:8000" \
KEYCLOAK_ISSUER_URL="http://localhost:8080/realms/moelan" \
KEYCLOAK_AUDIENCE="moelan-api" \
KEYCLOAK_SERVICE_CLIENT_SECRET="<voir ci-dessous>" \
cargo run
```

Les migrations (schéma + seed bière/soft/amendes) s'appliquent automatiquement
au démarrage. Vérifier avec `curl http://localhost:8000/health`.

`KEYCLOAK_SERVICE_CLIENT_SECRET` est le secret du client confidentiel
`moelan-api-service` (créé par l'import du realm, service account avec le
rôle `realm-admin`) — le backend l'utilise pour créer les groupes Keycloak
d'un nouvel espace et les comptes des joueurs invités. Le récupérer dans
Keycloak : Clients → `moelan-api-service` → Credentials → Client secret. Sans
cette variable, l'app démarre normalement mais "Créer mon espace" et "Donner
un accès" échoueront.

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

- Créer un compte super-admin dans Keycloak (voir étape 2 ci-dessus,
  `http://localhost:8080/admin`)
- Récupérer le secret du client `moelan-api-service` (Clients →
  `moelan-api-service` → Credentials) — impossible à connaître avant ce
  premier démarrage puisque c'est l'import du realm qui crée ce client.
  Le renseigner dans `.env` (`KEYCLOAK_SERVICE_CLIENT_SECRET`) puis
  `docker compose up -d api` pour redémarrer l'API avec.
- Ouvrir l'app sur http://localhost:8090

### Alertes email de dette (SMTP)

Un admin d'espace peut fixer, dans Réglages → Trésorerie, un seuil de dette :
dès qu'un joueur passe sous ce montant, un email part vers l'adresse de
contact de l'espace. L'envoi passe par un relais SMTP générique
(`SMTP_HOST`/`PORT`/`USERNAME`/`PASSWORD`/`FROM` dans `.env`) — n'importe
quel fournisseur qui expose du SMTP standard convient (Mailgun, Brevo,
SendGrid...), pas de SDK propriétaire à intégrer. Tant que `SMTP_HOST` est
vide, aucune erreur : les alertes sont simplement journalisées
(`RUST_LOG=info`) au lieu d'être envoyées — pratique pour développer sans
identifiants réels, à brancher plus tard.

### Notifications push (Firebase)

Chaque action sur le compte d'un joueur (bière, soft, amende, crédit,
ajustement) peut déclencher une notification push sur son téléphone, s'il a
un compte "joueur" (invité, cf. le bouton "Donner un accès" sur sa fiche) et
qu'il a autorisé les notifications dans l'app. Le code (backend et frontend)
est écrit et branché, mais **ne fera rien tant qu'un projet Firebase n'a pas
été créé** — sans configuration, chaque tentative d'envoi est simplement
journalisée (backend) ou échoue silencieusement (frontend), sans jamais
bloquer le reste de l'app. Pour l'activer :

1. Créer un projet sur https://console.firebase.google.com
2. **Ajouter une app Android** : package `fr.moelan.app` (voir
   `frontend/android/app/build.gradle.kts`). Télécharger le
   `google-services.json` généré et le placer dans `frontend/android/app/`.
   Puis appliquer le plugin Google Services :
   - dans `frontend/android/settings.gradle.kts`, ajouter
     `id("com.google.gms.google-services") version "4.4.2" apply false`
     à côté des autres plugins déclarés ;
   - dans `frontend/android/app/build.gradle.kts`, ajouter
     `id("com.google.gms.google-services")` au bloc `plugins { ... }`.
3. **Ajouter une app Web** (pour le web push) : copier la config JS
   fournie dans un fichier `frontend/lib/firebase_options.dart` — le plus
   simple est de lancer `dart pub global activate flutterfire_cli` puis
   `flutterfire configure` depuis `frontend/`, qui génère ce fichier pour
   toutes les plateformes ajoutées au projet Firebase (Android compris,
   en plus du `google-services.json` ci-dessus).
4. Une fois `firebase_options.dart` généré, passer `Firebase.initializeApp()`
   à `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`
   dans `frontend/lib/core/push/push_notifications.dart`.
5. **Créer la clé de service pour l'envoi serveur** : Paramètres du projet
   → Comptes de service → Générer une nouvelle clé privée (JSON). Mettre
   le contenu complet de ce fichier dans `FIREBASE_SERVICE_ACCOUNT_JSON`
   (pas un chemin de fichier, tout le JSON), et l'ID du projet dans
   `FIREBASE_PROJECT_ID`, puis `docker compose up -d api`.

Sans les étapes 2-4, `Firebase.initializeApp()` échoue proprement côté
Flutter (capturé, journalisé, rien ne casse) : rien n'empêche de déployer
l'app ou de démarrer le backend avant d'avoir fait ce travail.

### Reverse proxy Traefik (optionnel)

Un reverse proxy Traefik peut regrouper web/API/Keycloak sous un seul nom
d'hôte — pratique dès que l'app quitte `localhost`. Le routage est défini par
des labels Docker directement sur les services `web`/`api`/`keycloak`
(`docker-compose.yml`) ; `infra/traefik/traefik.yml` ne contient que le point
d'entrée et l'activation du provider Docker. Désactivé par défaut ; pour
l'activer :

```bash
docker compose --profile proxy up -d
```

Par défaut (`MOELAN_DOMAIN` non défini) Traefik sert en HTTP simple sur
`http://localhost:8888` (`TRAEFIK_HTTP_PORT`) — pratique pour tester le
routage localement. Vérifié de bout en bout : login complet (redirection
Keycloak, échange de token, dashboard) en passant uniquement par
`http://localhost:8888`, avec `/` → web, `/api/*` → api, `/realms/*`
`/resources/*` `/admin/*` → keycloak.

### Déploiement en production (vrai domaine)

Trois choses à aligner ensemble si vous mettez l'app derrière Traefik sur un
vrai domaine (ex. `moelan.example.com`), sans quoi Keycloak rejettera les
tokens (l'`iss` du token doit correspondre exactement à ce que l'API attend) :

1. Dans `.env` : `MOELAN_DOMAIN=moelan.example.com`,
   `KEYCLOAK_HOSTNAME=moelan.example.com`,
   `KEYCLOAK_ISSUER_URL=https://moelan.example.com/realms/moelan`,
   `PUBLIC_API_BASE_URL=https://moelan.example.com` (l'origine seule, **sans**
   `/api` — chaque appel ajoute déjà ce préfixe lui-même),
   `PUBLIC_KEYCLOAK_ISSUER_URL=https://moelan.example.com/realms/moelan`
2. HTTPS : Traefik n'obtient pas de certificat automatiquement comme Caddy —
   il faut ajouter un point d'entrée `websecure` (443) et un
   `certificatesResolvers` (Let's Encrypt) dans `infra/traefik/traefik.yml`,
   puis un label `traefik.http.routers.<nom>.tls.certresolver=<resolver>` sur
   chaque service. Voir la [doc Traefik ACME](https://doc.traefik.io/traefik/https/acme/).
3. Dans le service `keycloak` du `docker-compose.yml` : ajouter
   `KC_PROXY_HEADERS: xforwarded` (pour que Keycloak fasse confiance aux
   en-têtes `X-Forwarded-*` de Traefik — à ne faire que si Keycloak n'est plus
   exposé directement, sans quoi ces en-têtes sont falsifiables)
4. Dans la console Keycloak (`moelan-web`) : mettre à jour les *Valid redirect
   URIs* et *Web origins* du client pour le vrai domaine (ils sont actuellement
   réglés sur `http://localhost:*` pour le développement) — puis ré-exporter
   le realm (`infra/keycloak/realm-export.json`) si vous voulez que ce
   changement soit reproductible

Le HTTPS/ACME sur un vrai domaine n'a pas pu être testé dans cet environnement
(pas de nom de domaine public disponible) ; le routage HTTP et le login complet
ont été vérifiés en simulant un hostname unique via un port local
(`http://localhost:8888`), ce qui a d'ailleurs révélé et corrigé deux bugs :
`KEYCLOAK_ISSUER_URL` de l'API codait en dur le port `:8080` (cassait dès que
Keycloak était joint via un autre hostname/port), et cette doc elle-même disait
à tort d'ajouter `/api` à `PUBLIC_API_BASE_URL`.

## Sauvegardes Postgres

```bash
./infra/postgres/backup.sh                 # -> ./backups/{app,keycloak}-<date>.sql.gz
./infra/postgres/backup.sh /var/backups/moelan
```

Conserve les 14 dernières sauvegardes par base. À planifier via cron pour des
sauvegardes régulières (voir l'en-tête du script pour un exemple de ligne
crontab).

## Build Android

Un `flutter build apk --release` (ou `--appbundle`) fonctionne tel quel,
signé avec la clé de debug — suffisant pour tester l'installation sur un
téléphone, pas pour publier sur le Play Store. Pour une vraie release :

1. `cp frontend/android/key.properties.example frontend/android/key.properties`
2. Suivre les instructions dans ce fichier pour générer un keystore et
   renseigner les mots de passe
3. `flutter build appbundle --release`

`key.properties` et les fichiers `.jks` sont gitignorés — ne jamais les
committer (leur perte empêche de publier une mise à jour d'une app déjà en
ligne sur le Play Store).

L'app iOS n'a pas été configurée (nécessite un Mac).

## CI

`.github/workflows/ci.yml` fait tourner, sur chaque push/PR : `cargo fmt
--check`, `cargo clippy`, `cargo test` (contre un vrai Postgres de service) côté
backend, et `flutter analyze` côté frontend.

Voir le plan d'implémentation complet dans `PLAN.md` (jalons M0 à M10).
