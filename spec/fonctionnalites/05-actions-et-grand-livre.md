# 05 — Actions et grand livre

## En deux phrases

Quatre gestes — bière, soft, amende, crédit — plus un cinquième réservé à
l'admin, l'ajustement manuel. Chacun ajoute une ligne signée au grand livre et
met à jour le solde du joueur **dans la même transaction SQL** : le solde ne
peut pas dériver de l'historique.

## Les cinq mouvements

| Geste | `kind` | Signe | Rôle | Route |
|---|---|---|---|---|
| Bière | `beer` | débit | member, admin | `POST /api/players/{id}/consumptions` |
| Soft | `soft` | débit | member, admin | `POST /api/players/{id}/consumptions` |
| Amende | `fine` | débit | member, admin | `POST /api/players/{id}/fines` |
| Crédit | `credit` | crédit | member, admin | `POST /api/players/{id}/credits` |
| Ajustement | `manual_adjustment` | signé | **admin** | `POST /api/players/{id}/adjustments` |

Le rôle `player` n'a accès à aucun des cinq : c'est exactement ce qui le
distingue de `member`.

## La ligne de grand livre

Chaque transaction porte :

- le joueur et l'espace ;
- son type (`kind`) et son montant **signé** en centimes (négatif = débit) ;
- une quantité (une tournée de 3 bières = une ligne de quantité 3) ;
- le **prix unitaire au moment de l'action** (`unit_price_cents`) : changer le
  tarif plus tard ne réécrit jamais le passé ;
- la référence au type de consommation ou d'amende utilisé ;
- une note libre, optionnelle (obligatoire pour un ajustement) ;
- `created_by` : le `sub` Keycloak du compte qui a passé le geste ;
- l'horodatage.

Une contrainte `CHECK` en base relie le `kind` aux colonnes de référence
attendues : une ligne `fine` *doit* porter un `fine_type_id` et *ne peut pas*
porter de `consumable_type_id`. Une ligne incohérente est impossible à insérer,
même en contournant l'application.

## L'invariante

> `players.balance_cents` est toujours égal à la somme des `amount_cents` des
> transactions de ce joueur.

Tout passe par `services/transactions.rs::insert_and_apply` : une transaction
SQL qui insère la ligne et met à jour le solde, ou ne fait ni l'un ni l'autre.
C'est le seul point d'écriture du solde dans toute l'application.

Deux tests la verrouillent :
- un test unitaire (`balance_matches_sum_of_ledger_after_mixed_actions`) après
  une série mixte d'actions ;
- un scénario Gherkin qui rejoue la même chose à travers l'API HTTP.

## Règles de validation

- Un crédit doit être strictement positif : zéro ou négatif → 400.
- Une action sur un joueur inexistant, **désactivé**, ou appartenant à un autre
  espace renvoie 404. La ligne du joueur est verrouillée (`FOR UPDATE`) le temps
  de l'écriture, pour que deux tournées simultanées ne se marchent pas dessus.
- Un type de consommation ou d'amende inconnu ou **inactif** → 400.
- La liste des consommations est volontairement figée à `beer` et `soft` : la
  contrainte `CHECK` du grand livre ne connaît que ces deux `kind`, et seul leur
  prix est modifiable. Le barème d'amendes, lui, est ouvert.
- Un ajustement exige une note : c'est ce qui le rend auditable.

## Effets de bord d'une action

Après chaque mouvement, deux notifications sont tentées, toutes deux
non bloquantes (un échec n'annule jamais l'écriture) :

- une **alerte email** si le solde vient de passer sous le seuil de dette de
  l'espace (voir [07](07-tresorerie-et-alertes.md)) ;
- une **notification push** sur le téléphone du joueur, s'il a un compte et a
  autorisé les notifications (voir [10](10-notifications-push.md)).

L'alerte email ne se déclenche qu'au **moment du franchissement** du seuil, pas
à chaque action passée dessous — sans quoi une équipe dans le rouge noierait
l'adresse de contact.

## Limites connues

- Pas d'annulation de transaction : une erreur se corrige par un ajustement
  (« Corriger le solde » sur la fiche joueur, réservé à l'admin), qui ajoute une
  ligne plutôt que d'en retirer une. C'est voulu (traçabilité), mais
  l'historique d'un joueur maladroit s'allonge.
- La quantité n'est exposée que pour les consommations, pas pour les amendes.

## Scénarios

- [`features/membre/actions-quotidiennes.feature`](../features/membre/actions-quotidiennes.feature)
- [`features/admin/ajustements.feature`](../features/admin/ajustements.feature)
- [`features/joueur/lecture-seule.feature`](../features/joueur/lecture-seule.feature)
