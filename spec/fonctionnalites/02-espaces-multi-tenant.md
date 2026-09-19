# 02 — Espaces multi-tenant

## En deux phrases

Chaque équipe a sa propre caisse noire — un « espace » — créée en self-service
par n'importe quel compte Keycloak, puis validée par un super-admin avant de
devenir utilisable. Toutes les données métier (joueurs, tarifs, amendes, grand
livre) portent une colonne `organization_id`, et chaque requête est filtrée par
l'espace du jeton.

## Le cycle de vie d'un espace

1. **Demande** — un compte sans espace appelle `POST /api/organizations` avec
   un nom et un email de contact. La ligne naît `approved = false`.
2. **Provisionnement immédiat** — dans la foulée, le backend crée dans Keycloak
   le groupe `/org-<uuid>` et ses trois sous-groupes `admin`/`member`/`player`,
   chacun mappé sur le rôle réalm homonyme, et ajoute le demandeur au groupe
   `admin`. Il sème aussi les tarifs (bière/soft à 1 €) et deux amendes
   d'exemple, puisqu'il n'existe pas de route « créer un type de consommation ».
3. **Attente** — le demandeur peut se connecter, mais toute route métier lui
   répond 403 `org_pending`. L'écran « En attente de validation » propose de
   revérifier.
4. **Validation ou refus** — un super-admin tranche. Valider ouvre l'espace ;
   refuser le supprime (voir [03](03-super-administration.md)).

Le slug est dérivé du nom (`Les Handballeurs Fous !` → `les-handballeurs-fous`)
et suffixé en cas de collision (`-2`, `-3`, …).

## L'étanchéité

Elle est dans le SQL, pas dans l'interface. Chaque requête porte
`WHERE organization_id = $1` avec l'identifiant venu du jeton, y compris sur
les lectures par identifiant :

```sql
SELECT * FROM players WHERE id = $1 AND organization_id = $2
```

Conséquence voulue : demander la fiche d'un joueur d'un autre club renvoie
**404, pas 403** — de l'extérieur, l'espace voisin n'existe simplement pas.

Les contraintes d'unicité ont suivi la même logique lors de la migration
multi-tenant : le code d'un type de consommation ou d'amende n'est unique que
*dans* un espace (`UNIQUE (organization_id, code)`), pas globalement.

## Migration de l'existant

`0003_organizations.sql` crée une organisation `moelan` et y rattache toutes les
lignes préexistantes avant de rendre `organization_id` obligatoire : rien de ce
qui avait été saisi avant le multi-tenant n'a été perdu.

## Écrans

| Écran | Chemin | Pour qui |
|---|---|---|
| Créer mon espace | `/create-organization` | compte sans espace |
| En attente de validation | `/pending-approval` | espace non validé |

Le routeur (`frontend/lib/router.dart`) redirige automatiquement vers l'un ou
l'autre selon l'état renvoyé par `GET /api/me`. Le super-admin est explicitement
exempté de cette redirection : son travail ne suppose pas d'avoir un espace.

## Limites connues

- La création d'espace n'est pas transactionnelle de bout en bout : si Keycloak
  échoue après l'insertion de la ligne, l'espace existe sans ses groupes. Le
  cas se rattrape en refusant la demande depuis l'écran super-admin.
- Un espace validé ne peut pas être supprimé par l'API (choix délibéré, cf.
  [03](03-super-administration.md)).
- Pas de transfert de propriété ni de suppression d'un membre d'un espace
  depuis l'application : ça se fait dans la console Keycloak.

## Scénarios

- [`features/sans-espace/creation-espace.feature`](../features/sans-espace/creation-espace.feature)
- [`features/transverse/isolation-des-espaces.feature`](../features/transverse/isolation-des-espaces.feature)
