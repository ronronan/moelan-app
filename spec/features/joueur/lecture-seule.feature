# language: fr
Fonctionnalité: Compte joueur en lecture seule
  Un joueur invité peut suivre son ardoise et celle de l'équipe, mais ne peut
  rien débiter ni créditer : toutes les routes d'écriture lui sont fermées.

  Contexte:
    Soit un espace validé nommé "Les Ours"
    Et le joueur "Paul Durand" dans l'espace "Les Ours"
    Et que je suis connecté comme joueur de l'espace "Les Ours"

  Scénario: Le joueur consulte l'effectif et les soldes
    Quand j'appelle GET "/api/players"
    Alors le statut de la réponse est 200
    Et la réponse contient le joueur "Paul Durand"

  Scénario: Le joueur consulte l'historique de l'espace
    Quand j'appelle GET "/api/transactions"
    Alors le statut de la réponse est 200

  Scénario: Le joueur consulte les statistiques
    Quand j'appelle GET "/api/stats/monthly"
    Alors le statut de la réponse est 200

  Scénario: Le joueur consulte les tarifs
    Quand j'appelle GET "/api/consumable-types"
    Alors le statut de la réponse est 200

  Scénario: Le joueur ne peut pas enregistrer une bière
    Quand j'enregistre une bière pour le joueur "Paul Durand"
    Alors le statut de la réponse est 403
    Et le solde du joueur "Paul Durand" est de 0 centimes

  Scénario: Le joueur ne peut pas infliger une amende
    Quand j'inflige l'amende "red_card" au joueur "Paul Durand"
    Alors le statut de la réponse est 403

  Scénario: Le joueur ne peut pas créditer un compte
    Quand je crédite le joueur "Paul Durand" de 2000 centimes
    Alors le statut de la réponse est 403

  Scénario: Le joueur ne peut pas modifier les tarifs
    Quand je change le prix de la bière à 150 centimes
    Alors le statut de la réponse est 403
