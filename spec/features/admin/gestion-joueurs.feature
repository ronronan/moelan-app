# language: fr
Fonctionnalité: Gestion des joueurs
  L'effectif est géré par l'admin de l'espace. Un joueur n'est jamais
  supprimé — il est désactivé, pour que son historique dans le grand livre
  reste lisible.

  Contexte:
    Soit un espace validé nommé "Les Ours"

  Scénario: L'admin ajoute un joueur
    Soit je suis connecté comme admin de l'espace "Les Ours"
    Quand je crée le joueur "Paul Durand"
    Alors le statut de la réponse est 200
    Et le solde du joueur "Paul Durand" est de 0 centimes

  Scénario: L'admin désactive un joueur
    Soit le joueur "Paul Durand" dans l'espace "Les Ours"
    Et que je suis connecté comme admin de l'espace "Les Ours"
    Quand je désactive le joueur "Paul Durand"
    Alors le statut de la réponse est 200
    Et le joueur "Paul Durand" est inactif

  Scénario: Un membre ne peut pas ajouter de joueur
    Soit je suis connecté comme membre de l'espace "Les Ours"
    Quand je crée le joueur "Paul Durand"
    Alors le statut de la réponse est 403

  Scénario: Un joueur ne peut pas ajouter de joueur
    Soit je suis connecté comme joueur de l'espace "Les Ours"
    Quand je crée le joueur "Paul Durand"
    Alors le statut de la réponse est 403

  Scénario: Un membre peut consulter l'effectif
    Soit le joueur "Paul Durand" dans l'espace "Les Ours"
    Et que je suis connecté comme membre de l'espace "Les Ours"
    Quand j'appelle GET "/api/players"
    Alors le statut de la réponse est 200
    Et la réponse contient le joueur "Paul Durand"

  Scénario: L'admin donne un accès en lecture à un joueur
    Soit le joueur "Paul Durand" dans l'espace "Les Ours"
    Et que je suis connecté comme admin de l'espace "Les Ours"
    Quand j'invite le joueur "Paul Durand" avec l'email "paul@ours.test"
    Alors le statut de la réponse est 200
    Et un email d'invitation a été envoyé à "paul@ours.test"

  Scénario: Un membre ne peut pas inviter un joueur
    Soit le joueur "Paul Durand" dans l'espace "Les Ours"
    Et que je suis connecté comme membre de l'espace "Les Ours"
    Quand j'invite le joueur "Paul Durand" avec l'email "paul@ours.test"
    Alors le statut de la réponse est 403
