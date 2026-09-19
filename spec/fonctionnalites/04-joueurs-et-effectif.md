# 04 — Joueurs et effectif

## En deux phrases

L'effectif est la liste des personnes qui ont une ardoise. Un joueur n'est
jamais supprimé — il est désactivé, pour que son passage dans le grand livre
reste lisible.

## Ce qui existe

| Action | Route | Rôle |
|---|---|---|
| Lister | `GET /api/players` (filtre `?active=`) | tout l'espace |
| Consulter | `GET /api/players/{id}` | tout l'espace |
| Ajouter | `POST /api/players` | admin |
| Modifier / désactiver | `PATCH /api/players/{id}` | admin |
| Donner un accès | `POST /api/players/{id}/invite` | admin |

Un joueur porte : prénom, nom, un email optionnel (rempli seulement s'il a été
invité), son solde en centimes et un drapeau `active`. Le tri est alphabétique
sur nom puis prénom.

## Le solde

`players.balance_cents` est un **cache**. La source de vérité est la table
`transactions` : le solde vaut toujours exactement la somme des mouvements du
joueur. Cette invariante est maintenue dans une seule et même transaction SQL
(`services/transactions.rs`) et vérifiée par un test unitaire dédié — c'est la
propriété qui justifie toute l'architecture du grand livre (voir
[05](05-actions-et-grand-livre.md)).

L'argent est toujours en centimes (`BIGINT`), jamais en flottant. Le formatage
en euros se fait à l'affichage uniquement (`core/format.dart`).

## Donner un accès à un joueur

Optionnel et à la main de l'admin, joueur par joueur. Le geste :

1. crée un compte Keycloak avec l'email comme username, sans mot de passe, avec
   l'action requise `UPDATE_PASSWORD` ;
2. l'ajoute au groupe `/org-<uuid>/player` de l'espace ;
3. déclenche l'email « configurez votre compte » de Keycloak, via le SMTP
   configuré dans le realm ;
4. inscrit l'email sur la ligne du joueur.

Si le SMTP du realm n'est pas configuré, l'envoi échoue mais le compte existe :
l'échec est journalisé en avertissement, pas remonté en erreur, et l'admin peut
relancer l'email depuis la console Keycloak.

Cet email est aussi la clé de rapprochement compte ↔ joueur pour les
notifications push (voir [10](10-notifications-push.md)).

## Écrans

- **Tableau de bord** (`/`) — la liste des joueurs, leur solde (en rouge si
  négatif), la cagnotte totale et sa barre de progression vers l'objectif.
  Sélection multiple (appui long ou case à cocher) pour débiter une tournée
  entière d'un geste.
- **Fiche joueur** (`/players/{id}`) — le solde en grand, teinté selon qu'il
  est dans le rouge ou à jour et accompagné de ce qu'il veut dire (« Doit
  4,00 € à la caisse ») ; les quatre gestes du quotidien en grille de quatre
  cibles de même poids ; les dix derniers mouvements. Pour l'admin s'ajoutent
  « Corriger le solde » et, dans le menu de la barre du haut, « Donner un
  accès » et « Désactiver ».

Le bouton « ajouter un joueur » n'apparaît que pour l'admin ; les cases à cocher
de sélection n'apparaissent pas pour le rôle `player`.

## Limites connues

- La tournée groupée est une boucle d'appels unitaires côté client, pas une
  route dédiée : à l'échelle d'une équipe c'est plus simple qu'un endpoint de
  masse, mais ce n'est pas atomique (une erreur au milieu laisse la tournée à
  moitié passée).
- Pas de suppression de joueur, par construction.
- Un joueur désactivé reste dans la liste par défaut : le filtre `?active=` existe
  côté API mais l'écran ne l'expose pas. Il est signalé (avatar grisé, mention
  « Inactif ») mais pas masqué.

## Scénarios

- [`features/admin/gestion-joueurs.feature`](../features/admin/gestion-joueurs.feature)
