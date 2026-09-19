# language: fr
Fonctionnalité: Statistiques mensuelles
  Les agrégats par mois (bières, softs, amendes, crédits, solde cumulé de fin
  de mois) sont calculés côté serveur sur l'espace du jeton, et visibles par
  tous les rôles de l'espace — ils ne montrent rien que l'historique ne montre
  déjà. L'API ne renvoie que les mois où il s'est passé quelque chose ; c'est
  l'écran qui complète l'année.

  Contexte:
    Soit un espace validé nommé "Les Ours"
    Et le joueur "Paul Durand" dans l'espace "Les Ours"

  Scénario: Un espace sans mouvement n'a aucun mois à afficher
    Soit je suis connecté comme membre de l'espace "Les Ours"
    Quand j'appelle GET "/api/stats/monthly"
    Alors le statut de la réponse est 200
    Et la réponse contient 0 éléments

  Scénario: Le mois en cours apparaît dès la première consommation
    Soit je suis connecté comme membre de l'espace "Les Ours"
    Quand j'enregistre 2 bières pour le joueur "Paul Durand"
    Et j'appelle GET "/api/stats/monthly"
    Alors le statut de la réponse est 200
    Et la réponse contient 1 éléments
    Et le premier élément de la réponse contient le champ "beer_count" égal à 2

  Scénario: Les amendes et les crédits sont agrégés séparément
    Soit je suis connecté comme membre de l'espace "Les Ours"
    Quand j'inflige l'amende "red_card" au joueur "Paul Durand"
    Et je crédite le joueur "Paul Durand" de 2000 centimes
    Et j'appelle GET "/api/stats/monthly"
    Alors le statut de la réponse est 200
    Et le premier élément de la réponse contient le champ "fine_total_cents" égal à 500
    Et le premier élément de la réponse contient le champ "credit_total_cents" égal à 2000

  Scénario: Une année révolue sans activité ne renvoie rien
    Soit je suis connecté comme admin de l'espace "Les Ours"
    Quand j'appelle GET "/api/stats/monthly?year=2000"
    Alors le statut de la réponse est 200
    Et la réponse contient 0 éléments

  Scénario: Un joueur en lecture seule accède aux statistiques
    Soit je suis connecté comme joueur de l'espace "Les Ours"
    Quand j'appelle GET "/api/stats/monthly"
    Alors le statut de la réponse est 200

  Scénario: Un compte sans espace n'a pas de statistiques
    Soit je suis connecté avec un compte sans espace
    Quand j'appelle GET "/api/stats/monthly"
    Alors le statut de la réponse est 403
    Et le code d'erreur est "no_organization"
