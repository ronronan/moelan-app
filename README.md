# Moelan App

Caisse noire numérique pour l'équipe de handball : suivi des joueurs, de leur
solde, des consommations (bière/soft), des amendes et des crédits, avec un
historique complet. L'objectif : financer un week-end à Moelan-sur-Mer avec
le surplus en fin de saison.

## Stack

- **Backend** : Rust (axum + sqlx) — `backend/`
- **Frontend** : Flutter, un seul code pour web et mobile — `frontend/`
- **Base de données** : PostgreSQL
- **Auth** : Keycloak (partage l'instance Postgres)
- **Déploiement** : Docker Compose (auto-hébergé)

## Développement local

```bash
cp .env.example .env
docker compose up -d postgres
cd backend && cargo run
```

Voir le plan d'implémentation complet dans `PLAN.md` (jalons M0 à M10).
