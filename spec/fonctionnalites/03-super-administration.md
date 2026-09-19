# 03 — Super-administration

## En deux phrases

Le super-admin est l'opérateur de l'instance, pas un utilisateur de la caisse
noire. Il arbitre les demandes de création d'espace, parcourt n'importe quel
espace en lecture seule, et dispose de la seule vue qui traverse les espaces :
l'annuaire des utilisateurs.

## Modérer les demandes

`GET /api/organizations/pending` liste les espaces `approved = false`, les plus
anciens d'abord. Pour chacun, deux issues :

### Valider — `PATCH /api/organizations/{id}/approve`

Bascule `approved = true`. L'équipe peut travailler immédiatement : les groupes
Keycloak et les tarifs par défaut existent depuis la création.

### Refuser — `DELETE /api/organizations/{id}`

Supprime la demande et tout ce qu'elle a créé :

1. Vérification que l'espace est bien **en attente**. Un espace validé est
   refusé avec un 400 : détruire une caisse noire vivante (joueurs, grand livre,
   historique) n'est pas une décision de modération, et cette route ne l'ouvre
   pas. La suppression d'un espace validé reste un geste manuel en base, à
   assumer explicitement.
2. Suppression en base, dans une seule transaction et dans l'ordre des clés
   étrangères : `device_tokens`, `transactions`, `players`, `consumable_types`,
   `fine_types`, puis `organizations`. Un espace en attente n'a jamais pu être
   utilisé — l'extracteur `OrgUser` bloquait tout le monde — donc en pratique
   seuls les tarifs et amendes semés à la création sont concernés ; le reste est
   défensif.
3. Suppression du groupe Keycloak `/org-<uuid>`, qui emporte ses sous-groupes.
   Ce dernier geste est **best-effort** : s'il échoue, on journalise un
   avertissement mais la requête réussit quand même. Laisser un groupe orphelin
   se rattrape depuis la console Keycloak ; échouer après avoir supprimé les
   lignes laisserait l'opérateur devant un espace à moitié effacé et invisible.

Effet pour le demandeur : son compte n'appartient plus à aucun groupe, donc il
retombe sur « Créer mon espace » — pas sur une erreur. Il peut refaire une
demande.

Côté interface, le bouton **Refuser** de l'écran « Espaces en attente » demande
confirmation et annonce explicitement ce qui va disparaître.

## Parcourir les espaces

- `GET /api/organizations` — tous les espaces, validés ou non.
- `GET /api/organizations/{id}/players` — l'effectif et les soldes d'un espace
  donné, en lecture seule. C'est ce qui permet d'instruire une demande avant de
  trancher.

L'écran `SuperAdminHomeScreen` est l'atterrissage d'un super-admin sans espace :
un sélecteur d'espace et la liste des joueurs avec la cagnotte totale.

## Annuaire des utilisateurs

`GET /api/users` recoud deux sources que ni l'une ni l'autre ne suffit :

- **Keycloak** pour l'identité (username, email, nom, compte actif), les rôles
  réalm et les groupes ;
- **Postgres** pour le nom de l'espace et son état de validation.

Chaque ligne renvoie : identifiant, username, email, prénom/nom, compte activé
ou non, `superadmin` oui/non, rôle dans l'espace (`admin`/`member`/`player` ou
`null`), identifiant et nom de l'espace, et si cet espace est validé.

Le tri est fait côté serveur : groupé par espace, les comptes sans espace en
dernier, puis par username — la liste se lit comme « qui est dans quel espace ».

Coût : un appel pour le roster, puis deux par utilisateur (ses groupes, ses
rôles), parce que Keycloak n'expose pas de « liste des utilisateurs avec leurs
groupes ». À l'échelle de cette application — quelques clubs — c'est moins cher
que de parcourir les groupes de chaque espace. Ça deviendrait un problème à
quelques milliers de comptes.

L'écran `/superadmin/users` affiche cette liste avec une recherche
(nom, email, espace) et deux pastilles par ligne : le rôle et l'espace.

## Limites connues

- Le listing plafonne à 1000 comptes (paramètre `max` de Keycloak), sans
  pagination.
- L'annuaire est en lecture seule : pas de création, désactivation ni
  changement de rôle depuis l'application — ça reste dans la console Keycloak.
- Aucun journal des décisions de modération : on ne sait pas *qui* a validé ou
  refusé quoi, ni quand.

## Scénarios

- [`features/super-admin/moderation-espaces.feature`](../features/super-admin/moderation-espaces.feature)
- [`features/super-admin/listing-utilisateurs.feature`](../features/super-admin/listing-utilisateurs.feature)
- [`features/super-admin/consultation-espaces.feature`](../features/super-admin/consultation-espaces.feature)
