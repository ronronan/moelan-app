# 10 — Notifications push

> **État : échafaudage.** Le code est écrit et branché des deux côtés, mais
> **rien ne part tant qu'un projet Firebase n'a pas été créé**. Sans
> configuration, chaque tentative d'envoi est journalisée (backend) ou échoue
> silencieusement (frontend), sans jamais bloquer le reste de l'application.

## L'intention

Chaque geste sur le compte d'un joueur — bière, soft, amende, crédit,
ajustement — déclenche une notification sur son téléphone, s'il a un compte
(invité par l'admin) et qu'il a autorisé les notifications. Le message annonce
le mouvement et le nouveau solde : « Bière · −1,00 € — nouveau solde : −4,00 € ».

## Ce qui est en place

### Base

Table `device_tokens` : l'espace, le `sub` du compte, son email, le jeton FCM et
la plateforme. Pas de colonne `player_id` — c'est l'**email** qui fait le
rapprochement entre le compte qui s'enregistre et la ligne joueur
(`players.email`). Possible parce que le realm a `registrationEmailAsUsername`,
donc le username *est* l'email.

### API

- `POST /api/me/device-tokens` enregistre (ou ré-enregistre, au renouvellement
  du jeton) l'appareil courant. Réservé aux comptes d'un espace validé.
- `services/fcm.rs` parle à FCM HTTP v1, avec un jeton OAuth2 obtenu par le flux
  JWT-bearer à partir de la clé de service, mis en cache jusqu'à peu avant
  expiration.

Comme pour le SMTP, l'absence de configuration (`FIREBASE_PROJECT_ID` et
`FIREBASE_SERVICE_ACCOUNT_JSON` vides) vaut « ne pas envoyer », pas « erreur ».
Un JSON de service malformé est traité de la même façon : l'application démarre,
le push reste désactivé, chaque tentative explique pourquoi dans les logs.

### Frontend

`core/push/push_notifications.dart` demande la permission, récupère le jeton FCM
et l'envoie à l'API, au démarrage du tableau de bord. `Firebase.initializeApp()`
sans options échoue proprement tant que la configuration n'existe pas : c'est
capturé, journalisé, et rien ne casse.

## Ce qui reste à faire

Documenté pas à pas dans le README, section « Notifications push (Firebase) » :
créer le projet, ajouter l'app Android (`fr.moelan.app`) et l'app Web, générer
`firebase_options.dart` via `flutterfire configure`, passer les options à
`Firebase.initializeApp()`, puis renseigner la clé de service côté backend.

## Limites connues

- Non testé de bout en bout, faute de projet Firebase.
- Pas de préférence de notification par joueur ni par type de mouvement.
- Les jetons d'appareil périmés ne sont jamais purgés de la table.
- Aucun scénario Gherkin : l'envoi est désactivé par construction dans les
  tests (`FcmSender::disabled()`), il n'y a rien d'observable à vérifier.
