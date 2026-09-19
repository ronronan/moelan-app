# 12 — Design system et conventions d'interface

## En deux phrases

L'application a une identité : bord de mer, parce que c'est le but de la
saison. Tout ce qui se répète d'un écran à l'autre — couleurs, espacements,
états vides, messages d'erreur, retours après action — vient d'un socle unique
plutôt que d'être réécrit à chaque écran.

## Le socle

| Fichier | Rôle |
|---|---|
| `core/design/tokens.dart` | L'échelle d'espacement (`Gap`), les rayons (`Radii`), les durées (`Motion`) et les largeurs de lecture (`Layout`) |
| `core/design/theme.dart` | Les thèmes clair et sombre, et `MoelanColors` — les couleurs que Material n'a pas |
| `core/error_message.dart` | Traduit une erreur en une phrase actionnable |
| `widgets/` | Les composants partagés |

Aucun écran n'écrit un espacement en dur : `Gap.lg` plutôt que `16`. C'est ce
qui garantit que deux écrans écrits à six mois d'intervalle respirent pareil.

### Couleurs

Une seule graine — un vert-bleu profond (`#0E6B6F`) — d'où Material dérive les
deux palettes tonales complètes, claire et sombre. Deux ajouts faits à la main :

- **Sable** (`tertiary`), l'accent chaud : la palette générée dérivait vers le
  rose pour une graine turquoise, ce qui ne raconte rien.
- **`MoelanColors`**, une `ThemeExtension` qui porte ce que le schéma Material
  n'a pas de case pour : `positive` / `negative` (être à découvert n'est pas une
  erreur de validation — ça ne doit pas crier comme un champ invalide),
  le sable, et le dégradé marin des surfaces héros.

Chaque valeur existe en clair **et** en sombre, donc aucun widget n'a jamais à
demander dans quel mode il est.

### Mode sombre

Suivi du réglage système (`ThemeMode.system`), sans bascule dans l'app : il n'y
a pas d'écran de compte où la mettre, et un trésorier qui saisit des tournées
le soir veut ce que son téléphone a déjà décidé.

### Typographie

Les polices système, avec l'échelle Material resserrée sur les gros titres —
son interlettrage par défaut est réglé pour du texte long et flotte sur les
chaînes courtes et numériques dont cette app est faite.

Tout montant passe par `MoneyText`, qui force les **chiffres tabulaires** : une
colonne de soldes s'aligne chiffre sous chiffre. Avec des chiffres
proportionnels, la liste des joueurs tremble d'une ligne à l'autre.

## Les composants partagés

| Composant | Ce qu'il résout |
|---|---|
| `PageBody` | Centre et plafonne la largeur du contenu. Sans lui, une ligne de joueur s'étire sur 1900 px dans un navigateur et l'œil perd la ligne entre le nom et le solde |
| `CagnotteCard` | Le héros du tableau de bord : le total, et **la distance qui reste** (« Encore 753,00 € ») plutôt qu'un pourcentage sec, qui n'est un chiffre sur lequel personne n'agit |
| `MoneyText` / `BalancePill` | Un montant, sa couleur sémantique, ses chiffres tabulaires |
| `TransactionTile` | Une ligne de grand livre. Un seul vocabulaire (icône, libellé, teinte) pour les cinq types de mouvement — avant, chaque écran avait sa copie du `switch` et elles avaient déjà divergé |
| `EmptyState` | Un vide n'est pas une erreur : c'est l'état du premier jour, donc il porte l'étape suivante, pas seulement le constat |
| `ErrorView` | L'erreur en français, avec un bouton **Réessayer** uniquement quand réessayer peut aider |
| `SkeletonBox` | Garde la forme de la page pendant le chargement, au lieu de s'effondrer sur un spinner et de resauter quand les données arrivent |
| `showSuccess` / `showFailure` | Le retour après action |
| `InitialsAvatar` | Une identité bon marché pour un effectif sans photos. La teinte dérive du nom, donc elle survit au tri |
| `SeaGradient` | Le dégradé marin, défini une fois, pour que le héros et l'écran de connexion ne divergent pas |

## Règles d'interface

**Toute écriture donne un retour.** Enregistrer une bière était silencieux — la
liste se rafraîchissait, ce qui, sur un téléphone au bord du terrain, est
indiscernable d'un appui qui n'a pas pris. Chaque écriture affiche maintenant
ce qui a été fait et pour combien.

**Aucune exception brute à l'écran.** `humanizeError` traduit ; un `DioException`
affiché tel quel est un paragraphe illisible qui, en prime, nomme l'hôte et le
port internes. Le code machine du backend (`no_organization`, `org_pending`)
donne une phrase précise ; le reste est déduit du statut HTTP.

**Aucune saisie silencieusement ignorée.** Les formulaires valident et disent
pourquoi. Avant, un montant mal saisi faisait fermer la boîte de dialogue sans
rien enregistrer ni rien dire.

**Rien qui expose la base.** Le code d'une amende (`late_training`) est dérivé
du libellé et affiché en clair, au lieu d'être demandé au trésorier.

**Mobile d'abord.** L'app est conçue pour le téléphone ; sur grand écran le
contenu est centré et plafonné, pas étiré. Trois largeurs de lecture selon la
densité de l'écran (`Layout.formMaxWidth`, `contentMaxWidth`, `wideMaxWidth`).

**Français partout**, y compris les widgets de Flutter : `flutter_localizations`
est branché avec une seule locale, donc le sélecteur de dates et ses boutons
sont en français au lieu de rester anglais au milieu d'un écran français.

## Vérification

`test/golden/design_golden_test.dart` rend toutes les surfaces partagées sur une
même page, en clair et en sombre, et la compare à une image de référence. Une
modification qui change une couleur, un espacement ou une forme fait échouer ce
test à l'endroit précis où tous les composants sont côte à côte.

```bash
flutter test                              # dont les goldens
flutter test --update-goldens test/golden # après un changement volontaire
```

Le texte y apparaît sous forme de rectangles : c'est la police de test de
Flutter, pas un défaut de rendu. Ce que ces images vérifient, ce sont les
couleurs, les espacements et les formes.

## Limites connues

- Pas de police de marque : l'app utilise les polices système. En embarquer une
  demanderait de versionner les fichiers de fonte (et de tenir leur licence).
- Le mode sombre n'est pas réglable depuis l'app.
- Pas de mise en page vraiment adaptative sur grand écran (pas de volet de
  navigation latéral, pas de maître-détail) : le contenu est centré, pas
  réorganisé.
- Pas d'audit de contraste automatisé ; les couleurs sont dérivées par Material
  à partir d'une graine, ce qui donne des paires accessibles par construction,
  mais les quelques valeurs posées à la main (sable, positif/négatif) n'ont pas
  été mesurées.
- Les goldens ne couvrent que les composants partagés, pas chaque écran.
