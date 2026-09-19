# language: fr
Fonctionnalité: Ajustements manuels de solde
  Corriger une erreur de saisie doit rester traçable : l'ajustement n'écrase
  pas le passé, il ajoute une ligne signée au grand livre, réservée à l'admin
  et obligatoirement commentée.

  Contexte:
    Soit un espace validé nommé "Les Ours"
    Et le joueur "Paul Durand" dans l'espace "Les Ours"

  Scénario: L'admin corrige un solde à la hausse
    Soit je suis connecté comme admin de l'espace "Les Ours"
    Quand j'ajuste le solde du joueur "Paul Durand" de 500 centimes
    Alors le statut de la réponse est 200
    Et le solde du joueur "Paul Durand" est de 500 centimes
    Et le joueur "Paul Durand" a 1 transactions

  Scénario: L'admin corrige un solde à la baisse
    Soit je suis connecté comme admin de l'espace "Les Ours"
    Quand j'ajuste le solde du joueur "Paul Durand" de -500 centimes
    Alors le statut de la réponse est 200
    Et le solde du joueur "Paul Durand" est de -500 centimes

  Scénario: Un membre ne peut pas ajuster un solde
    Soit je suis connecté comme membre de l'espace "Les Ours"
    Quand j'ajuste le solde du joueur "Paul Durand" de 500 centimes
    Alors le statut de la réponse est 403
    Et le solde du joueur "Paul Durand" est de 0 centimes
