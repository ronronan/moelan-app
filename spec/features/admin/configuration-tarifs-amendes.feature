# language: fr
Fonctionnalité: Tarifs et barème d'amendes
  Chaque espace fixe ses propres prix de consommation et son propre barème
  d'amendes. Un changement de tarif ne réécrit jamais le passé : le prix
  appliqué est figé dans chaque ligne du grand livre au moment de l'action.

  Contexte:
    Soit un espace validé nommé "Les Ours"
    Et le joueur "Paul Durand" dans l'espace "Les Ours"

  Scénario: L'admin change le prix de la bière
    Soit je suis connecté comme admin de l'espace "Les Ours"
    Quand je change le prix de la bière à 150 centimes
    Alors le statut de la réponse est 200
    Et le prix de la bière est de 150 centimes

  Scénario: Le nouveau tarif s'applique aux consommations suivantes
    Soit je suis connecté comme admin de l'espace "Les Ours"
    Quand je change le prix de la bière à 150 centimes
    Et j'enregistre une bière pour le joueur "Paul Durand"
    Alors le solde du joueur "Paul Durand" est de -150 centimes

  Scénario: Un changement de tarif ne rejoue pas les consommations passées
    Soit je suis connecté comme admin de l'espace "Les Ours"
    Quand j'enregistre une bière pour le joueur "Paul Durand"
    Et je change le prix de la bière à 500 centimes
    Alors le solde du joueur "Paul Durand" est de -100 centimes

  Scénario: Un membre ne peut pas changer les tarifs
    Soit je suis connecté comme membre de l'espace "Les Ours"
    Quand je change le prix de la bière à 150 centimes
    Alors le statut de la réponse est 403
    Et le prix de la bière est de 100 centimes

  Scénario: L'admin modifie le montant d'une amende
    Soit je suis connecté comme admin de l'espace "Les Ours"
    Quand je change le montant de l'amende "red_card" à 1000 centimes
    Alors le statut de la réponse est 200
    Et le montant de l'amende "red_card" est de 1000 centimes

  Scénario: L'admin ajoute une amende au barème
    Soit je suis connecté comme admin de l'espace "Les Ours"
    Quand je crée l'amende "oubli_maillot" intitulée "Oubli du maillot" à 300 centimes
    Alors le statut de la réponse est 200
    Et le montant de l'amende "oubli_maillot" est de 300 centimes

  Scénario: Un membre ne peut pas ajouter d'amende
    Soit je suis connecté comme membre de l'espace "Les Ours"
    Quand je crée l'amende "oubli_maillot" intitulée "Oubli du maillot" à 300 centimes
    Alors le statut de la réponse est 403

  Scénario: Un membre peut consulter le barème
    Soit je suis connecté comme membre de l'espace "Les Ours"
    Quand j'appelle GET "/api/fine-types"
    Alors le statut de la réponse est 200
    Et la réponse contient 2 éléments
