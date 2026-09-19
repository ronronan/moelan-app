# language: fr
Fonctionnalité: Actions du quotidien sur la caisse
  Bière, soft, amende, crédit : les quatre gestes de la troisième mi-temps.
  Ils sont ouverts à l'admin comme au membre — c'est la différence entre ces
  deux rôles et le rôle joueur, en lecture seule.

  Contexte:
    Soit un espace validé nommé "Les Ours"
    Et le joueur "Paul Durand" dans l'espace "Les Ours"

  Scénario: Un membre enregistre une bière
    Soit je suis connecté comme membre de l'espace "Les Ours"
    Quand j'enregistre une bière pour le joueur "Paul Durand"
    Alors le statut de la réponse est 200
    Et le solde du joueur "Paul Durand" est de -100 centimes

  Scénario: Un membre enregistre un soft
    Soit je suis connecté comme membre de l'espace "Les Ours"
    Quand j'enregistre une soft pour le joueur "Paul Durand"
    Alors le statut de la réponse est 200
    Et le solde du joueur "Paul Durand" est de -100 centimes

  Scénario: Une tournée compte autant de fois que de verres
    Soit je suis connecté comme membre de l'espace "Les Ours"
    Quand j'enregistre 3 bières pour le joueur "Paul Durand"
    Alors le statut de la réponse est 200
    Et le solde du joueur "Paul Durand" est de -300 centimes
    Et le joueur "Paul Durand" a 1 transactions

  Scénario: Un membre inflige une amende du barème
    Soit je suis connecté comme membre de l'espace "Les Ours"
    Quand j'inflige l'amende "red_card" au joueur "Paul Durand"
    Alors le statut de la réponse est 200
    Et le solde du joueur "Paul Durand" est de -500 centimes

  Scénario: Un membre crédite un joueur qui remet au pot
    Soit je suis connecté comme membre de l'espace "Les Ours"
    Quand je crédite le joueur "Paul Durand" de 2000 centimes
    Alors le statut de la réponse est 200
    Et le solde du joueur "Paul Durand" est de 2000 centimes

  Scénario: Le solde reste la somme exacte du grand livre
    Soit je suis connecté comme membre de l'espace "Les Ours"
    Quand je crédite le joueur "Paul Durand" de 2000 centimes
    Et j'enregistre 2 bières pour le joueur "Paul Durand"
    Et j'inflige l'amende "red_card" au joueur "Paul Durand"
    Alors le solde du joueur "Paul Durand" est de 1300 centimes
    Et le solde du joueur "Paul Durand" est cohérent avec son historique
    Et le joueur "Paul Durand" a 3 transactions

  Scénario: Un membre ne peut pas ajuster un solde à la main
    Soit je suis connecté comme membre de l'espace "Les Ours"
    Quand j'ajuste le solde du joueur "Paul Durand" de 500 centimes
    Alors le statut de la réponse est 403
