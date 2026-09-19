# 08 — Historique et audit

## En deux phrases

La table `transactions` est le registre complet et immuable de la caisse : tout
geste y laisse une ligne signée du compte qui l'a passé. C'est la raison d'être
de l'application autant que le solde affiché.

## Les deux vues

| Vue | Route | Contenu |
|---|---|---|
| Historique global | `GET /api/transactions` | tous les mouvements de l'espace |
| Historique d'un joueur | `GET /api/players/{id}/transactions` | ses mouvements à lui |

Les deux sont accessibles à **tous les rôles de l'espace**, joueur compris :
l'historique est justement ce que chacun doit pouvoir vérifier.

### Filtres (historique global)

- `player_id` — un joueur en particulier
- `kind` — `beer`, `soft`, `fine`, `credit`, `manual_adjustment`
- `from` / `to` — bornes de date (ISO 8601)
- `page` / `page_size` — pagination, 50 par défaut, 200 au maximum

Le tri est toujours du plus récent au plus ancien. Le filtrage par espace n'est
pas un paramètre : il est ajouté d'office à partir du jeton.

## Ce qu'une ligne conserve

- qui : `created_by`, le `sub` Keycloak de l'auteur du geste ;
- quand : `created_at` ;
- quoi : le type, le montant signé, la quantité ;
- combien ça coûtait alors : `unit_price_cents`, figé ;
- sur quoi : la référence au type de consommation ou d'amende ;
- pourquoi, éventuellement : la note.

Aucune route ne modifie ni ne supprime une transaction. Une erreur se corrige
par un ajustement, qui ajoute une ligne — le registre ne recule jamais.

## Écran

**Historique** (`/history`) : la liste paginée avec « Charger plus », groupée
par jour (« Aujourd'hui », « Hier », puis la date), et une barre de filtres —
joueur, type, période — où un filtre actif se voit. Un registre se lit par
séance (« ce qui s'est passé après le match de samedi »), pas comme un flux
continu. Depuis une fiche joueur, le bouton « Historique complet » ouvre le
même écran pré-filtré sur ce joueur.

## Limites connues

- `created_by` stocke un identifiant Keycloak, pas un nom : l'écran affiche le
  joueur concerné, pas qui a passé le geste. L'information est en base, elle
  n'est simplement pas résolue en nom lisible.
- Pas d'export (CSV, PDF) depuis l'application.
- Pas de journal d'audit des actions *administratives* (changement de tarif,
  validation d'espace, invitation) : seuls les mouvements d'argent sont tracés.

## Scénarios

- [`features/transverse/historique.feature`](../features/transverse/historique.feature)
