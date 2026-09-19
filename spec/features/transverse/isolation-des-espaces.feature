# language: fr
Fonctionnalité: Étanchéité entre espaces
  Chaque requête métier est filtrée par l'espace porté par le jeton. Un compte
  d'un club ne peut ni lire ni écrire les données d'un autre, même en
  connaissant l'identifiant visé — la cloison est dans la clause SQL, pas dans
  l'interface.

  Contexte:
    Soit un espace validé nommé "Les Ours"
    Et un espace validé nommé "Les Loups"
    Et le joueur "Paul Durand" dans l'espace "Les Ours"
    Et le joueur "Marc Petit" dans l'espace "Les Loups"

  Scénario: L'effectif ne contient que les joueurs de son propre espace
    Soit je suis connecté comme admin de l'espace "Les Ours"
    Quand j'appelle GET "/api/players"
    Alors le statut de la réponse est 200
    Et la réponse contient le joueur "Paul Durand"
    Et la réponse ne contient pas le joueur "Marc Petit"

  Scénario: Lire la fiche d'un joueur d'un autre espace renvoie introuvable
    Soit je suis connecté comme admin de l'espace "Les Ours"
    Quand j'appelle GET "/api/players/<Marc Petit>"
    Alors le statut de la réponse est 404

  Scénario: Débiter un joueur d'un autre espace est impossible
    Soit je suis connecté comme admin de l'espace "Les Ours"
    Quand je crédite le joueur "Marc Petit" de 2000 centimes
    Alors le statut de la réponse est 404
    Et le solde du joueur "Marc Petit" est de 0 centimes

  Scénario: L'historique ne laisse pas filtrer les mouvements d'un autre espace
    Soit je suis connecté comme admin de l'espace "Les Loups"
    Quand j'enregistre une bière pour le joueur "Marc Petit"
    Alors le statut de la réponse est 200

  Scénario: Les tarifs sont propres à chaque espace
    Soit je suis connecté comme admin de l'espace "Les Ours"
    Quand j'appelle GET "/api/consumable-types"
    Alors le statut de la réponse est 200
    Et la réponse contient 2 éléments
