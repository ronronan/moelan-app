# 01 — Authentification et rôles

## En deux phrases

L'application ne gère aucun mot de passe : Keycloak est la seule autorité
d'identité, l'API ne fait que valider les jetons qu'il émet. Les rôles sont
portés par le jeton lui-même, sur deux plans indépendants — un rôle réalm
(`superadmin`) et une appartenance à un groupe d'espace (`admin`/`member`/`player`).

## Ce qui existe

### Côté Keycloak

- Realm `moelan`, importé depuis `infra/keycloak/realm-export.json` au premier
  démarrage — reproductible sur toute nouvelle machine.
- Deux clients publics PKCE : `moelan-web` et `moelan-mobile`
  (scheme `fr.moelan.app://callback`).
- Un client confidentiel `moelan-api-service`, service account porteur de
  `realm-admin` : c'est lui que le backend utilise pour créer les groupes d'un
  nouvel espace et les comptes des joueurs invités.
- Un mapper d'audience qui ajoute `moelan-api` dans l'`aud` des jetons — sans
  lui, l'API rejette tout.
- Rôles réalm : `superadmin`, `admin`, `member`, `player`.
- `registrationEmailAsUsername` activé : le `preferred_username` d'un compte
  *est* son email, ce dont dépend le rapprochement compte ↔ joueur pour le push.

### Côté API

`backend/src/auth/jwt.rs` valide chaque jeton : signature RS256 contre le JWKS
du realm (mis en cache 10 minutes), `iss` et `aud` attendus. Le `kid` du jeton
sélectionne la clé ; un jeton dont la signature ne correspond pas est rejeté en
401 avant tout accès base.

`jwks_base_url` et `expected_issuer` sont deux champs séparés, et c'est
indispensable : en Docker Compose, l'API joint Keycloak par le nom de service
interne (`http://keycloak:8080/...`) alors que l'`iss` des jetons porte le
hostname que le **navigateur** a utilisé. Deux URLs différentes pour la même
chose.

### Rôle d'espace

Il ne vient pas de `realm_access.roles` mais du claim `groups`, sous la forme
`/org-<uuid>/<rôle>`. Deux informations en une : *quel* espace et *quel* rôle
dedans. `realm_access.roles` reste réservé aux rôles réalm — aujourd'hui, le
seul qui compte est `superadmin`.

Un compte appartient à un seul espace : si plusieurs groupes correspondent, le
premier trouvé gagne (hypothèse assumée, pas un cas à gérer).

### Côté Flutter

`core/auth/auth_service.dart` implémente le flux PKCE via le package `oidc`,
qui couvre web et mobile depuis une seule API — c'était la condition pour tenir
la promesse « un seul code ».

`core/auth/auth_providers.dart` décode le JWT **sans vérifier sa signature**
pour piloter l'affichage. Assumé : c'est du confort d'interface, pas de la
sécurité. Chaque écriture est réautorisée côté serveur contre le jeton
réellement validé.

## Règles

- Sans jeton : 401 sur tout sauf `/health`.
- Jeton valide mais compte sans espace : 403 avec le code machine
  `no_organization` — le frontend s'en sert pour router vers « Créer mon espace »
  plutôt que d'afficher une erreur brute.
- Jeton valide, espace pas encore validé : 403 avec le code `org_pending`.
- `GET /api/me` reste accessible dans les deux cas : c'est précisément ce qui
  permet aux écrans « créer un espace » et « en attente » de savoir lequel
  afficher.

## Limites connues

- Pas de rafraîchissement de rôle sans nouveau jeton : après avoir été ajouté à
  un groupe, l'utilisateur doit rafraîchir son jeton pour que l'API le voie
  (géré côté frontend par une invalidation après création d'espace).
- Un utilisateur = un seul espace. Changer d'espace suppose une intervention
  dans la console Keycloak.

## Scénarios

- [`features/anonyme/authentification.feature`](../features/anonyme/authentification.feature)
- [`features/sans-espace/creation-espace.feature`](../features/sans-espace/creation-espace.feature)
