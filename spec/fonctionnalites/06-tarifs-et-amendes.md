# 06 — Tarifs et barème d'amendes

## En deux phrases

Chaque espace fixe ses propres prix de consommation et son propre barème
d'amendes, éditables depuis l'écran Réglages par l'admin. Un changement de
tarif ne réécrit jamais le passé : le prix appliqué est figé dans chaque ligne
du grand livre au moment de l'action.

## Types de consommation

Deux, semés à la création de l'espace : `beer` et `soft`, à 1 € chacun. La liste
est **fermée** — la contrainte `CHECK` du grand livre ne reconnaît que ces deux
`kind` pour une ligne liée à une consommation. L'admin peut en changer le
libellé, le prix, et les désactiver ; il ne peut pas en ajouter.

| Action | Route | Rôle |
|---|---|---|
| Lister | `GET /api/consumable-types` | tout l'espace |
| Modifier (libellé, prix, actif) | `PATCH /api/consumable-types/{id}` | admin |

## Types d'amendes

Ouverte, elle. Trois exemples sont semés à la création (retard entraînement,
oubli d'équipement, carton rouge) et l'admin ajoute les siens.

| Action | Route | Rôle |
|---|---|---|
| Lister | `GET /api/fine-types` | tout l'espace |
| Créer | `POST /api/fine-types` | admin |
| Modifier (libellé, montant, actif) | `PATCH /api/fine-types/{id}` | admin |

Un code d'amende est unique **dans un espace**, pas globalement : deux clubs
peuvent chacun avoir leur `carton_rouge`.

## Le prix est figé au moment de l'action

C'est la règle qui compte. Chaque ligne du grand livre porte un
`unit_price_cents` — le prix tel qu'il était à la seconde de l'action. Passer la
bière de 1 € à 1,50 € n'a aucun effet rétroactif : les bières d'hier restent à
1 €, celles de demain sont à 1,50 €.

Un type désactivé disparaît des actions possibles (une tentative renvoie 400)
mais reste lisible dans l'historique — sans quoi les anciennes lignes
deviendraient orphelines.

## Écran

**Réglages** (`/settings`), réservé à l'admin, trois onglets : Trésorerie,
Tarifs, Amendes. Les tarifs se modifient au clic sur la ligne (boîte de
dialogue avec le prix en euros) ; les amendes ont en plus un bouton
d'ajout et un interrupteur Actif/Inactif.

## Limites connues

- Pas de route pour créer un type de consommation, par construction.
- Pas d'historique des changements de tarif : on sait quel prix a été appliqué
  à chaque transaction, mais pas quand ni par qui le tarif a bougé.
- Le code d'une amende est dérivé de son libellé et affiché en clair, plus
  saisi à la main. Un doublon dans le même espace reste rejeté par la base : le
  message renvoyé est celui du serveur, pas une explication sur mesure.

## Scénarios

- [`features/admin/configuration-tarifs-amendes.feature`](../features/admin/configuration-tarifs-amendes.feature)
