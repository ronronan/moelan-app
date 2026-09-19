# language: fr
Fonctionnalité: Listing des utilisateurs de l'instance
  Le super-admin dispose de la seule vue qui traverse les espaces : tous les
  comptes de l'instance, avec leur rôle et l'espace auquel ils appartiennent.
  Les identités viennent de Keycloak, le nom de l'espace de la base — la route
  recoud les deux.

  Contexte:
    Soit un espace validé nommé "Les Ours"
    Et un espace en attente de validation nommé "Les Loups"

  Scénario: Chaque compte est listé avec son rôle et son espace
    Soit le compte "chef@ours.test" est admin de l'espace "Les Ours"
    Et le compte "tresorier@ours.test" est membre de l'espace "Les Ours"
    Et le compte "paul@ours.test" est joueur de l'espace "Les Ours"
    Et que je suis connecté comme super-admin
    Quand j'appelle GET "/api/users"
    Alors le statut de la réponse est 200
    Et la réponse contient l'utilisateur "chef@ours.test" avec le rôle "admin" dans l'espace "Les Ours"
    Et la réponse contient l'utilisateur "tresorier@ours.test" avec le rôle "membre" dans l'espace "Les Ours"
    Et la réponse contient l'utilisateur "paul@ours.test" avec le rôle "joueur" dans l'espace "Les Ours"

  Scénario: Un compte sans espace apparaît quand même
    Soit le compte "nouveau@moelan.test" n'appartient à aucun espace
    Et que je suis connecté comme super-admin
    Quand j'appelle GET "/api/users"
    Alors le statut de la réponse est 200
    Et la réponse contient l'utilisateur "nouveau@moelan.test" sans espace

  Scénario: Le super-admin se voit lui-même, identifié comme tel
    Soit je suis connecté comme super-admin
    Quand j'appelle GET "/api/users"
    Alors le statut de la réponse est 200
    Et la réponse contient l'utilisateur super-admin "operateur"

  Scénario: Les comptes d'un espace encore en attente sont listés
    Soit le compte "chef@loups.test" est admin de l'espace "Les Loups"
    Et que je suis connecté comme super-admin
    Quand j'appelle GET "/api/users"
    Alors le statut de la réponse est 200
    Et la réponse contient l'utilisateur "chef@loups.test" avec le rôle "admin" dans l'espace "Les Loups"

  Scénario: Un admin d'espace n'a pas accès au listing global
    Soit je suis connecté comme admin de l'espace "Les Ours"
    Quand j'appelle GET "/api/users"
    Alors le statut de la réponse est 403

  Scénario: Un membre n'a pas accès au listing global
    Soit je suis connecté comme membre de l'espace "Les Ours"
    Quand j'appelle GET "/api/users"
    Alors le statut de la réponse est 403

  Scénario: Un appel anonyme est rejeté avant tout
    Soit je ne suis pas connecté
    Quand j'appelle GET "/api/users"
    Alors le statut de la réponse est 401
