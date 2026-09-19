# language: fr
Fonctionnalité: Trésorerie de l'espace
  L'admin fixe l'objectif de la cagnotte (affiché en barre de progression sur
  le tableau de bord) et le seuil de dette au-delà duquel une alerte email
  part vers l'adresse de contact de l'espace.

  Contexte:
    Soit un espace validé nommé "Les Ours"

  Scénario: L'admin fixe un objectif de cagnotte
    Soit je suis connecté comme admin de l'espace "Les Ours"
    Quand je fixe l'objectif de la cagnotte à 150000 centimes
    Alors le statut de la réponse est 200
    Et l'objectif de l'espace "Les Ours" est de 150000 centimes

  Scénario: L'admin fixe un seuil d'alerte de dette
    Soit je suis connecté comme admin de l'espace "Les Ours"
    Quand je fixe le seuil d'alerte de dette à -2000 centimes
    Alors le statut de la réponse est 200

  Scénario: Un membre ne peut pas toucher aux réglages de trésorerie
    Soit je suis connecté comme membre de l'espace "Les Ours"
    Quand je fixe l'objectif de la cagnotte à 150000 centimes
    Alors le statut de la réponse est 403

  Scénario: Un joueur ne peut pas toucher aux réglages de trésorerie
    Soit je suis connecté comme joueur de l'espace "Les Ours"
    Quand je fixe l'objectif de la cagnotte à 150000 centimes
    Alors le statut de la réponse est 403
