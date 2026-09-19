# 09 — Statistiques

## En deux phrases

Un écran de graphiques mensuels sur l'année : combien de bières et de softs,
combien d'amendes et de crédits, et l'évolution du solde cumulé de la cagnotte.
Les agrégats sont calculés en SQL côté serveur, sur l'espace du jeton.

## La route

`GET /api/stats/monthly?year=<année>` (année en cours par défaut), accessible à
**tous les rôles de l'espace** : ce ne sont que des agrégats de données que
l'historique montre déjà ligne à ligne.

Chaque élément renvoyé correspond à un mois :

| Champ | Sens |
|---|---|
| `month` | le premier jour du mois |
| `beer_count` / `soft_count` | nombre de verres (quantités cumulées) |
| `fine_total_cents` | total des amendes du mois, en positif |
| `credit_total_cents` | total des crédits du mois |
| `net_cents` | solde net du mois |
| `balance_cents` | **solde cumulé** à la fin du mois |

Détail qui compte : `balance_cents` est calculé sur **tout l'historique** de
l'espace, pas seulement sur l'année demandée — un janvier reflète donc bien tout
ce qui a été mis de côté les années précédentes.

## Ce que l'API ne fait pas

Elle ne renvoie que les mois où il s'est passé quelque chose. Un espace sans
mouvement renvoie une liste vide, pas douze zéros. C'est l'écran qui complète
l'année pour tracer un axe continu.

## Écran

**Statistiques** (`/stats`), navigation d'année en année (pas de futur, et le
sélecteur reste visible sous le titre au lieu de défiler). Trois chiffres
d'abord — consommations, amendes, cagnotte en fin de période — parce qu'ils
répondent à « comment s'est passée la saison » avant qu'on lise un graphique ;
puis les trois graphiques `fl_chart` (bières & softs, amendes & crédits, solde
cumulé) et un tableau récapitulatif mois par mois, qui sert aussi de version
accessible des graphiques.

## Limites connues

- Pas de statistiques par joueur (qui boit le plus, qui est le plus amendé).
- Pas de comparaison entre années sur un même graphique.
- Pas de filtre sur une période libre : la granularité est le mois, la fenêtre
  est l'année.

## Scénarios

- [`features/transverse/statistiques.feature`](../features/transverse/statistiques.feature)
