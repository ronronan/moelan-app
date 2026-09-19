# Spécification de Moelan App

Ce dossier décrit **ce que l'application fait aujourd'hui**, fonctionnalité par
fonctionnalité, et le traduit en scénarios exécutables.

Deux moitiés complémentaires :

| Dossier | Contenu | Public |
|---|---|---|
| [`fonctionnalites/`](fonctionnalites/) | La description en prose de chaque fonctionnalité : règles métier, écrans, routes, limites connues. | Se relire, embarquer quelqu'un, décider de la suite. |
| [`features/`](features/) | Les mêmes règles en Gherkin, **exécutées à chaque `cargo test`**. | Empêcher une régression silencieuse. |

La prose explique le *pourquoi*, le Gherkin verrouille le *quoi*. Quand les deux
divergent, c'est le Gherkin qui a raison : lui, il tourne.

## Les fonctionnalités

1. [Authentification et rôles](fonctionnalites/01-authentification-et-roles.md)
2. [Espaces multi-tenant](fonctionnalites/02-espaces-multi-tenant.md)
3. [Super-administration](fonctionnalites/03-super-administration.md)
4. [Joueurs et effectif](fonctionnalites/04-joueurs-et-effectif.md)
5. [Actions et grand livre](fonctionnalites/05-actions-et-grand-livre.md)
6. [Tarifs et barème d'amendes](fonctionnalites/06-tarifs-et-amendes.md)
7. [Trésorerie et alertes](fonctionnalites/07-tresorerie-et-alertes.md)
8. [Historique et audit](fonctionnalites/08-historique-et-audit.md)
9. [Statistiques](fonctionnalites/09-statistiques.md)
10. [Notifications push](fonctionnalites/10-notifications-push.md)
11. [Infrastructure et déploiement](fonctionnalites/11-infrastructure-et-deploiement.md)
12. [Design system et conventions d'interface](fonctionnalites/12-design-system.md)

Vue d'ensemble transversale : [**matrice des rôles**](roles.md) — qui a le droit
de faire quoi, avec le code HTTP renvoyé quand la réponse est non.

## Lancer les scénarios

Les scénarios tournent contre le **vrai** routeur axum, les **vrais**
extracteurs d'autorisation et un **vrai** Postgres. Seul Keycloak est simulé
(`backend/tests/support/mod.rs`) : un serveur HTTP en mémoire qui sert le JWKS
et la portion d'Admin REST API que l'application appelle. Les jetons sont de
vrais JWT RS256, signés avec la clé de test que ce JWKS publie — rien de la
chaîne d'authentification n'est court-circuité.

```bash
docker compose up -d postgres

cd backend
DATABASE_URL="postgres://moelan:changeme@localhost:5432/app" cargo test --test cucumber
```

La base doit être migrée (`backend/migrations/*.sql`). Chaque scénario repart
d'une ardoise propre : tout ce que les scénarios créent est marqué
`created_by = 'cucumber'` et purgé au scénario suivant — les données de
développement d'à côté ne sont jamais touchées.

Filtrer un seul fichier :

```bash
cargo test --test cucumber -- --input ../spec/features/super-admin
```

## Organisation des scénarios

Par **rôle**, parce que c'est l'axe qui décide de tout dans cette application :

```
features/
├── anonyme/         ce qui est possible sans jeton (presque rien)
├── sans-espace/     un compte Keycloak qui n'a pas encore d'espace
├── joueur/          rôle lecture seule
├── membre/          les gestes du quotidien
├── admin/           l'administration d'un espace
├── super-admin/     l'opérateur de l'instance, au-dessus des espaces
└── transverse/      étanchéité, historique, statistiques
```

Chaque fichier vérifie aussi bien le chemin heureux que les refus : un scénario
qui prouve qu'un membre **ne peut pas** changer les tarifs vaut autant que
celui qui prouve qu'un admin le peut.

## Ajouter un scénario

1. Écrire le scénario dans le fichier du rôle concerné, en français
   (`# language: fr` en tête de fichier).
2. Le lancer. S'il échoue sur « step doesn't match any function », c'est qu'il
   faut une nouvelle step definition dans `backend/tests/cucumber.rs`.
3. Réutiliser le vocabulaire existant avant d'en inventer : la liste complète
   des phrases disponibles se lit en parcourant les attributs `#[given]`,
   `#[when]` et `#[then]` de ce fichier.
