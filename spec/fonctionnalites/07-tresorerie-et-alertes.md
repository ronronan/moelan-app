# 07 — Trésorerie et alertes de dette

## En deux phrases

L'espace porte deux réglages financiers : un objectif de cagnotte, affiché en
barre de progression sur le tableau de bord, et un seuil de dette au-delà
duquel un email part vers l'adresse de contact. Les deux sont à la main de
l'admin.

## Les deux réglages

`PATCH /api/organizations/me` (admin) écrit les deux champs **ensemble** :

| Champ | Contrainte | Effet |
|---|---|---|
| `target_cents` | ≥ 0 ou `null` | barre de progression sur le tableau de bord |
| `debt_alert_threshold_cents` | ≤ 0 ou `null` | déclenche l'alerte email |

La route remplace les deux valeurs inconditionnellement : il n'existe pas de
« laisser tel quel ». Chaque appel doit envoyer l'état complet souhaité,
`null` pour effacer. Le client Flutter est écrit en conséquence — c'est une
API à assumer, pas un oubli.

Un objectif nul ou négatif est traité comme « pas d'objectif » à l'affichage
plutôt que de dessiner une barre absurde.

## L'alerte de dette

Déclenchée après une écriture au grand livre, **uniquement au moment du
franchissement** : quand le solde passe d'au-dessus du seuil à en dessous. Un
joueur déjà profondément dans le rouge ne redéclenche pas d'alerte à chaque
bière — seulement la première fois qu'il passe la ligne, ou s'il la repasse
après être remonté.

L'email part vers l'adresse de contact de l'espace (pas vers le joueur), via un
relais SMTP générique (`SMTP_HOST`/`PORT`/`USERNAME`/`PASSWORD`/`FROM`).
N'importe quel fournisseur exposant du SMTP standard convient — pas de SDK
propriétaire à intégrer.

**Tant que `SMTP_HOST` est vide, il ne se passe rien de fâcheux** : l'alerte est
journalisée (`RUST_LOG=info`) au lieu d'être envoyée. C'est ce qui permet de
développer sans identifiants réels. Et un échec d'envoi n'annule jamais
l'écriture qui l'a déclenché : un problème de messagerie ne doit pas faire
perdre une bière au grand livre.

## Écran

**Réglages → Trésorerie** : deux champs en euros (objectif, seuil d'alerte) et
un bouton Enregistrer. Le tableau de bord affiche la cagnotte totale, la barre
de progression et le pourcentage de l'objectif atteint, sous le bandeau
« Direction Moelan-sur-Mer 🌊 ».

## Limites connues

- Un seul seuil pour tout l'espace, pas de seuil par joueur.
- L'alerte va à l'adresse de contact de l'espace ; le joueur concerné n'est pas
  prévenu par email (il l'est éventuellement par push, cf. [10](10-notifications-push.md)).
- Pas de relance ni de récapitulatif périodique des joueurs en dette.
- Le franchissement est calculé sur le solde d'avant/après la transaction en
  cours ; un rattrapage de saisie a posteriori peut donc ne déclencher aucune
  alerte.

## Scénarios

- [`features/admin/tresorerie.feature`](../features/admin/tresorerie.feature)
