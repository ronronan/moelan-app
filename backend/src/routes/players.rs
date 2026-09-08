use axum::{
    Json,
    extract::{Path, Query, State},
};
use serde::Deserialize;
use uuid::Uuid;

use crate::auth::{AdminUser, CurrentUser};
use crate::db::models::Player;
use crate::dto::PatchPlayer;
use crate::error::{AppError, AppResult};
use crate::state::AppState;

#[derive(Debug, Deserialize)]
pub struct ListPlayersQuery {
    active: Option<bool>,
}

pub async fn list_players(
    State(state): State<AppState>,
    _user: CurrentUser,
    Query(query): Query<ListPlayersQuery>,
) -> AppResult<Json<Vec<Player>>> {
    let players = match query.active {
        Some(active) => {
            sqlx::query_as!(
                Player,
                "SELECT * FROM players WHERE active = $1 ORDER BY last_name, first_name",
                active
            )
            .fetch_all(&state.pool)
            .await?
        }
        None => {
            sqlx::query_as!(Player, "SELECT * FROM players ORDER BY last_name, first_name")
                .fetch_all(&state.pool)
                .await?
        }
    };
    Ok(Json(players))
}

pub async fn create_player(
    State(state): State<AppState>,
    _admin: AdminUser,
    Json(body): Json<crate::dto::CreatePlayer>,
) -> AppResult<Json<Player>> {
    let player = sqlx::query_as!(
        Player,
        "INSERT INTO players (first_name, last_name) VALUES ($1, $2) RETURNING *",
        body.first_name,
        body.last_name,
    )
    .fetch_one(&state.pool)
    .await?;
    Ok(Json(player))
}

pub async fn get_player(
    State(state): State<AppState>,
    _user: CurrentUser,
    Path(id): Path<Uuid>,
) -> AppResult<Json<Player>> {
    let player = sqlx::query_as!(Player, "SELECT * FROM players WHERE id = $1", id)
        .fetch_optional(&state.pool)
        .await?
        .ok_or(AppError::NotFound)?;
    Ok(Json(player))
}

pub async fn patch_player(
    State(state): State<AppState>,
    _admin: AdminUser,
    Path(id): Path<Uuid>,
    Json(body): Json<PatchPlayer>,
) -> AppResult<Json<Player>> {
    let player = sqlx::query_as!(
        Player,
        r#"
        UPDATE players SET
            first_name = COALESCE($1, first_name),
            last_name = COALESCE($2, last_name),
            active = COALESCE($3, active),
            updated_at = now()
        WHERE id = $4
        RETURNING *
        "#,
        body.first_name,
        body.last_name,
        body.active,
        id,
    )
    .fetch_optional(&state.pool)
    .await?
    .ok_or(AppError::NotFound)?;
    Ok(Json(player))
}
