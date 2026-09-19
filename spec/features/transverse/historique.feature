# language: fr
Fonctionnalité: Historique et traçabilité
  La table des transactions est la source de vérité : chaque geste y laisse
  une ligne signée du compte qui l'a passé. Le solde affiché n'est qu'un cache
  de cette somme.

  Contexte:
    Soit un espace validé nommé "Les Ours"
    Et le joueur "Paul Durand" dans l'espace "Les Ours"
    Et que je suis connecté comme membre de l'espace "Les Ours"

  Scénario: L'historique global liste les mouvements de l'espace
    Quand j'enregistre une bière pour le joueur "Paul Durand"
    Et j'appelle GET "/api/transactions"
    Alors le statut de la réponse est 200
    Et la réponse contient 1 éléments

  Scénario: L'historique se filtre par type de mouvement
    Quand j'enregistre une bière pour le joueur "Paul Durand"
    Et j'inflige l'amende "red_card" au joueur "Paul Durand"
    Et j'appelle GET "/api/transactions?kind=fine"
    Alors le statut de la réponse est 200
    Et la réponse contient 1 éléments

  Scénario: L'historique d'un joueur ne contient que ses mouvements
    Soit le joueur "Marc Petit" dans l'espace "Les Ours"
    Quand j'enregistre une bière pour le joueur "Paul Durand"
    Et j'enregistre une bière pour le joueur "Marc Petit"
    Et j'appelle GET "/api/players/<Paul Durand>/transactions"
    Alors le statut de la réponse est 200
    Et la réponse contient 1 éléments

  Scénario: La pagination borne le nombre de lignes renvoyées
    Quand j'enregistre une bière pour le joueur "Paul Durand"
    Et j'enregistre une bière pour le joueur "Paul Durand"
    Et j'enregistre une bière pour le joueur "Paul Durand"
    Et j'appelle GET "/api/transactions?page=1&page_size=2"
    Alors le statut de la réponse est 200
    Et la réponse contient 2 éléments

  Scénario: Un mouvement annulé par un ajustement reste visible
    Soit je suis connecté comme admin de l'espace "Les Ours"
    Quand j'enregistre une bière pour le joueur "Paul Durand"
    Et j'ajuste le solde du joueur "Paul Durand" de 100 centimes
    Alors le solde du joueur "Paul Durand" est de 0 centimes
    Et le joueur "Paul Durand" a 2 transactions
