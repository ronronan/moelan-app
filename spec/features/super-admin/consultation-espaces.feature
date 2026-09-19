# language: fr
Fonctionnalité: Consultation des espaces par le super-admin
  L'opérateur n'a pas d'espace à lui : pour instruire une demande, il peut
  parcourir n'importe quel espace, validé ou non, en lecture seule.

  Contexte:
    Soit un espace validé nommé "Les Ours"
    Et le joueur "Paul Durand" dans l'espace "Les Ours"

  Scénario: Lister tous les espaces
    Soit je suis connecté comme super-admin
    Quand j'appelle GET "/api/organizations"
    Alors le statut de la réponse est 200

  Scénario: Consulter les joueurs d'un espace donné
    Soit je suis connecté comme super-admin
    Quand j'appelle GET "/api/organizations/<Les Ours>/players"
    Alors le statut de la réponse est 200
    Et la réponse contient le joueur "Paul Durand"

  Scénario: Un admin d'espace ne peut pas lister les espaces
    Soit je suis connecté comme admin de l'espace "Les Ours"
    Quand j'appelle GET "/api/organizations"
    Alors le statut de la réponse est 403

  Scénario: Un admin ne peut pas lire les joueurs par la route super-admin
    Soit je suis connecté comme admin de l'espace "Les Ours"
    Quand j'appelle GET "/api/organizations/<Les Ours>/players"
    Alors le statut de la réponse est 403
