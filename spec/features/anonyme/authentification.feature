# language: fr
Fonctionnalité: Authentification
  Toute l'API métier est derrière un jeton Keycloak valide. Un appel sans
  jeton, ou avec un jeton falsifié, n'atteint jamais la couche métier : il est
  rejeté par l'extracteur `CurrentUser`, avant le moindre accès à la base.

  Scénario: La sonde de santé reste publique
    Soit je ne suis pas connecté
    Quand j'appelle GET "/health"
    Alors le statut de la réponse est 200

  Scénario: Sans jeton, aucune donnée métier n'est accessible
    Soit je ne suis pas connecté
    Quand j'appelle GET "/api/players"
    Alors le statut de la réponse est 401

  Scénario: Sans jeton, l'identité n'est pas consultable
    Soit je ne suis pas connecté
    Quand j'appelle GET "/api/me"
    Alors le statut de la réponse est 401

  Scénario: Un jeton dont la signature ne correspond pas au JWKS est rejeté
    Soit un espace validé nommé "Les Ours"
    Et que je suis connecté comme admin de l'espace "Les Ours"
    Et que mon jeton d'accès est falsifié
    Quand j'appelle GET "/api/players"
    Alors le statut de la réponse est 401
