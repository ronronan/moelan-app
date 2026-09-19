# Matrice des rôles

Quatre rôles, sur deux plans qui ne se mélangent pas.

**Plan réalm** — un seul rôle, assigné directement au compte Keycloak :

- `superadmin` : l'opérateur de l'instance. Il n'appartient à aucun espace (il
  *peut* en avoir un, mais ce n'est pas son rôle). Son travail : valider ou
  refuser les demandes de création d'espace, et voir qui utilise l'instance.

**Plan espace** — porté par l'appartenance à un groupe Keycloak
`/org-<uuid>/<rôle>`, jamais par `realm_access.roles` :

- `admin` : gère l'espace — effectif, tarifs, barème, trésorerie, invitations,
  ajustements de solde.
- `member` : les gestes du quotidien — bière, soft, amende, crédit.
- `player` : lecture seule. C'est le compte qu'un joueur reçoit quand l'admin
  lui « donne un accès » ; il suit son ardoise, il n'écrit rien.

Un compte appartient à **un seul** espace. Le backend lit la première
appartenance `/org-<uuid>/<rôle>` du jeton et ignore les suivantes
(`auth/jwt.rs`, `parse_org_membership`).

## Qui peut quoi

Légende : ✅ autorisé · ❌ refusé (403) · 🔒 refusé tant que l'espace n'est pas
validé (403 `org_pending`) · — hors sujet pour ce rôle.

| Action | Route | anonyme | sans espace | player | member | admin | superadmin |
|---|---|:--:|:--:|:--:|:--:|:--:|:--:|
| Sonde de santé | `GET /health` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Lire son identité | `GET /api/me` | ❌ 401 | ✅ | ✅ | ✅ | ✅ | ✅ |
| Créer son espace | `POST /api/organizations` | ❌ 401 | ✅ | ❌ 400 | ❌ 400 | ❌ 400 | ✅ |
| Lister l'effectif | `GET /api/players` | ❌ 401 | ❌ `no_organization` | ✅ 🔒 | ✅ 🔒 | ✅ 🔒 | ❌ |
| Fiche d'un joueur | `GET /api/players/{id}` | ❌ 401 | ❌ | ✅ 🔒 | ✅ 🔒 | ✅ 🔒 | ❌ |
| Ajouter un joueur | `POST /api/players` | ❌ 401 | ❌ | ❌ | ❌ | ✅ 🔒 | ❌ |
| Modifier/désactiver un joueur | `PATCH /api/players/{id}` | ❌ 401 | ❌ | ❌ | ❌ | ✅ 🔒 | ❌ |
| Donner un accès à un joueur | `POST /api/players/{id}/invite` | ❌ 401 | ❌ | ❌ | ❌ | ✅ 🔒 | ❌ |
| Bière / soft | `POST /api/players/{id}/consumptions` | ❌ 401 | ❌ | ❌ | ✅ 🔒 | ✅ 🔒 | ❌ |
| Amende | `POST /api/players/{id}/fines` | ❌ 401 | ❌ | ❌ | ✅ 🔒 | ✅ 🔒 | ❌ |
| Crédit | `POST /api/players/{id}/credits` | ❌ 401 | ❌ | ❌ | ✅ 🔒 | ✅ 🔒 | ❌ |
| Ajustement manuel | `POST /api/players/{id}/adjustments` | ❌ 401 | ❌ | ❌ | ❌ | ✅ 🔒 | ❌ |
| Historique | `GET /api/transactions` | ❌ 401 | ❌ | ✅ 🔒 | ✅ 🔒 | ✅ 🔒 | ❌ |
| Statistiques | `GET /api/stats/monthly` | ❌ 401 | ❌ | ✅ 🔒 | ✅ 🔒 | ✅ 🔒 | ❌ |
| Lire les tarifs | `GET /api/consumable-types` | ❌ 401 | ❌ | ✅ 🔒 | ✅ 🔒 | ✅ 🔒 | ❌ |
| Changer un tarif | `PATCH /api/consumable-types/{id}` | ❌ 401 | ❌ | ❌ | ❌ | ✅ 🔒 | ❌ |
| Lire le barème | `GET /api/fine-types` | ❌ 401 | ❌ | ✅ 🔒 | ✅ 🔒 | ✅ 🔒 | ❌ |
| Créer/modifier une amende | `POST`/`PATCH /api/fine-types` | ❌ 401 | ❌ | ❌ | ❌ | ✅ 🔒 | ❌ |
| Objectif et seuil d'alerte | `PATCH /api/organizations/me` | ❌ 401 | ❌ | ❌ | ❌ | ✅ 🔒 | ❌ |
| Enregistrer un appareil (push) | `POST /api/me/device-tokens` | ❌ 401 | ❌ | ✅ 🔒 | ✅ 🔒 | ✅ 🔒 | ❌ |
| Lister tous les espaces | `GET /api/organizations` | ❌ 401 | ❌ | ❌ | ❌ | ❌ | ✅ |
| File des demandes | `GET /api/organizations/pending` | ❌ 401 | ❌ | ❌ | ❌ | ❌ | ✅ |
| Valider une demande | `PATCH /api/organizations/{id}/approve` | ❌ 401 | ❌ | ❌ | ❌ | ❌ | ✅ |
| Refuser une demande | `DELETE /api/organizations/{id}` | ❌ 401 | ❌ | ❌ | ❌ | ❌ | ✅ |
| Joueurs d'un espace donné | `GET /api/organizations/{id}/players` | ❌ 401 | ❌ | ❌ | ❌ | ❌ | ✅ |
| Lister les utilisateurs | `GET /api/users` | ❌ 401 | ❌ | ❌ | ❌ | ❌ | ✅ |

## Où c'est appliqué

L'autorisation n'est pas dispersée dans les handlers : elle tient dans quatre
extracteurs axum (`backend/src/auth/extractor.rs`), et le type demandé par la
signature d'une route *est* sa règle d'accès.

| Extracteur | Exige | Refus |
|---|---|---|
| `CurrentUser` | un jeton valide | 401 |
| `OrgUser` | + appartenir à un espace **validé** | 403 `no_organization` / `org_pending` |
| `WriterUser` | + rôle `admin` ou `member` | 403 |
| `AdminUser` | + rôle `admin` | 403 |
| `SuperAdminUser` | rôle réalm `superadmin` (sans lien avec un espace) | 403 |

Côté Flutter, les mêmes rôles pilotent l'affichage des boutons
(`core/auth/auth_providers.dart`), en décodant le JWT **sans vérifier sa
signature**. C'est volontaire et sans danger : c'est du confort d'interface,
chaque écriture est réautorisée côté serveur contre le jeton réellement
vérifié. Un jeton bricolé peut faire apparaître un bouton ; il ne fait jamais
passer l'action.

Les scénarios correspondants : un refus est testé pour chaque ❌ du tableau,
dans le fichier du rôle concerné sous [`features/`](features/).
