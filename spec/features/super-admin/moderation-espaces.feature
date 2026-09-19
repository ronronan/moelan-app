# language: fr
Fonctionnalité: Modération des demandes d'espace
  Le super-admin est l'opérateur de l'instance. Son travail : valider ou
  refuser les demandes de création d'espace. Valider ouvre l'espace à son
  équipe ; refuser le supprime entièrement — ligne, tarifs/amendes initiaux et
  groupes Keycloak — pour que le demandeur reparte d'une page blanche.

  Scénario: Lister les demandes en attente
    Soit un espace en attente de validation nommé "Les Loups"
    Et que je suis connecté comme super-admin
    Quand j'appelle GET "/api/organizations/pending"
    Alors le statut de la réponse est 200
    Et la réponse contient l'espace "Les Loups"

  Scénario: Un espace validé ne figure plus dans les demandes en attente
    Soit un espace validé nommé "Les Ours"
    Et que je suis connecté comme super-admin
    Quand j'appelle GET "/api/organizations/pending"
    Alors le statut de la réponse est 200
    Et la réponse ne contient pas l'espace "Les Ours"

  Scénario: Valider une demande ouvre l'espace
    Soit un espace en attente de validation nommé "Les Loups"
    Et que je suis connecté comme super-admin
    Quand je valide l'espace "Les Loups"
    Alors le statut de la réponse est 200
    Et l'espace "Les Loups" est validé

  Scénario: Refuser une demande la supprime définitivement
    Soit un espace en attente de validation nommé "Les Loups"
    Et que je suis connecté comme super-admin
    Quand je refuse l'espace "Les Loups"
    Alors le statut de la réponse est 204
    Et l'espace "Les Loups" n'existe plus
    Et les données de l'espace "Les Loups" ont été supprimées
    Et les groupes Keycloak de l'espace "Les Loups" ont été supprimés

  Scénario: Un espace déjà validé ne peut pas être supprimé par cette route
    Soit un espace validé nommé "Les Ours"
    Et que je suis connecté comme super-admin
    Quand je refuse l'espace "Les Ours"
    Alors le statut de la réponse est 400
    Et l'espace "Les Ours" existe toujours
    Et les groupes Keycloak de l'espace "Les Ours" existent toujours

  Scénario: Un admin d'espace ne peut pas modérer les demandes
    Soit un espace validé nommé "Les Ours"
    Et un espace en attente de validation nommé "Les Loups"
    Et que je suis connecté comme admin de l'espace "Les Ours"
    Quand je refuse l'espace "Les Loups"
    Alors le statut de la réponse est 403
    Et l'espace "Les Loups" existe toujours

  Scénario: Un admin d'espace ne peut pas valider une demande
    Soit un espace validé nommé "Les Ours"
    Et un espace en attente de validation nommé "Les Loups"
    Et que je suis connecté comme admin de l'espace "Les Ours"
    Quand je valide l'espace "Les Loups"
    Alors le statut de la réponse est 403
    Et l'espace "Les Loups" est toujours en attente

  Scénario: Un admin d'espace ne voit pas la file des demandes
    Soit un espace validé nommé "Les Ours"
    Et que je suis connecté comme admin de l'espace "Les Ours"
    Quand j'appelle GET "/api/organizations/pending"
    Alors le statut de la réponse est 403
