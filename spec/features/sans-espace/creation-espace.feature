# language: fr
Fonctionnalité: Création d'un espace en self-service
  N'importe quel compte Keycloak peut demander la création de sa propre caisse
  noire. L'espace naît « en attente » : son créateur en est administrateur dans
  Keycloak, mais aucune donnée ne peut y être écrite tant qu'un super-admin ne
  l'a pas validé.

  Scénario: Un compte sans espace crée sa demande
    Soit je suis connecté avec un compte sans espace
    Quand je crée un espace nommé "Les Loups" avec l'email de contact "contact@loups.test"
    Alors le statut de la réponse est 200
    Et la réponse contient le champ "name" égal à "Les Loups"
    Et la réponse indique que l'espace n'est pas encore validé

  Scénario: Un compte sans espace ne voit aucune donnée métier
    Soit je suis connecté avec un compte sans espace
    Quand j'appelle GET "/api/players"
    Alors le statut de la réponse est 403
    Et le code d'erreur est "no_organization"

  Scénario: Un compte qui a déjà un espace ne peut pas en créer un second
    Soit un espace validé nommé "Les Ours"
    Et que je suis connecté comme admin de l'espace "Les Ours"
    Quand je crée un espace nommé "Les Loups" avec l'email de contact "contact@loups.test"
    Alors le statut de la réponse est 400

  Scénario: Un espace non validé bloque toute lecture métier
    Soit un espace en attente de validation nommé "Les Loups"
    Et que je suis connecté comme admin de l'espace "Les Loups"
    Quand j'appelle GET "/api/players"
    Alors le statut de la réponse est 403
    Et le code d'erreur est "org_pending"

  Scénario: Un espace non validé bloque aussi toute écriture
    Soit un espace en attente de validation nommé "Les Loups"
    Et que je suis connecté comme admin de l'espace "Les Loups"
    Quand je crée le joueur "Paul Durand"
    Alors le statut de la réponse est 403
    Et le code d'erreur est "org_pending"

  Scénario: L'identité reste consultable avant validation
    Soit un espace en attente de validation nommé "Les Loups"
    Et que je suis connecté comme admin de l'espace "Les Loups"
    Quand j'appelle GET "/api/me"
    Alors le statut de la réponse est 200
