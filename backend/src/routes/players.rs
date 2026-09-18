use axum::{
    Json,
    extract::{Path, Query, State},
};
use serde::Deserialize;
use uuid::Uuid;

use crate::auth::{AdminUser, OrgUser, SuperAdminUser};
use crate::db::models::Player;
use crate::dto::{InvitePlayer, PatchPlayer};
use crate::error::{AppError, AppResult};
use crate::state::AppState;

#[derive(Debug, Deserialize)]
pub struct ListPlayersQuery {
    active: Option<bool>,
}

pub async fn list_players(
    State(state): State<AppState>,
    org: OrgUser,
    Query(query): Query<ListPlayersQuery>,
) -> AppResult<Json<Vec<Player>>> {
    let players = match query.active {
        Some(active) => {
            sqlx::query_as!(
                Player,
                "SELECT * FROM players WHERE organization_id = $1 AND active = $2 ORDER BY last_name, first_name",
                org.org_id,
                active
            )
            .fetch_all(&state.pool)
            .await?
        }
        None => {
            sqlx::query_as!(
                Player,
                "SELECT * FROM players WHERE organization_id = $1 ORDER BY last_name, first_name",
                org.org_id
            )
            .fetch_all(&state.pool)
            .await?
        }
    };
    Ok(Json(players))
}

/// Same listing as `list_players`, but for the super-admin operator: it
/// isn't tied to an org (`OrgUser` doesn't apply to it), so the target org
/// comes from the path instead of the token, and there's no approval check
/// — the operator needs to see a space's players before/without approving it.
pub async fn list_players_for_org(
    State(state): State<AppState>,
    _super_admin: SuperAdminUser,
    Path(org_id): Path<Uuid>,
) -> AppResult<Json<Vec<Player>>> {
    let players = sqlx::query_as!(
        Player,
        "SELECT * FROM players WHERE organization_id = $1 ORDER BY last_name, first_name",
        org_id
    )
    .fetch_all(&state.pool)
    .await?;
    Ok(Json(players))
}

pub async fn create_player(
    State(state): State<AppState>,
    admin: AdminUser,
    Json(body): Json<crate::dto::CreatePlayer>,
) -> AppResult<Json<Player>> {
    let player = sqlx::query_as!(
        Player,
        "INSERT INTO players (organization_id, first_name, last_name) VALUES ($1, $2, $3) RETURNING *",
        admin.0.org_id,
        body.first_name,
        body.last_name,
    )
    .fetch_one(&state.pool)
    .await?;
    Ok(Json(player))
}

pub async fn get_player(
    State(state): State<AppState>,
    org: OrgUser,
    Path(id): Path<Uuid>,
) -> AppResult<Json<Player>> {
    let player = sqlx::query_as!(
        Player,
        "SELECT * FROM players WHERE id = $1 AND organization_id = $2",
        id,
        org.org_id
    )
    .fetch_optional(&state.pool)
    .await?
    .ok_or(AppError::NotFound)?;
    Ok(Json(player))
}

pub async fn patch_player(
    State(state): State<AppState>,
    admin: AdminUser,
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
        WHERE id = $4 AND organization_id = $5
        RETURNING *
        "#,
        body.first_name,
        body.last_name,
        body.active,
        id,
        admin.0.org_id,
    )
    .fetch_optional(&state.pool)
    .await?
    .ok_or(AppError::NotFound)?;
    Ok(Json(player))
}

/// Gives a player their own read-only login: creates a Keycloak account for
/// them (in the org's `player` group) and stamps their email onto the row.
/// Most players never get one — this is opt-in per player.
pub async fn invite_player(
    State(state): State<AppState>,
    admin: AdminUser,
    Path(id): Path<Uuid>,
    Json(body): Json<InvitePlayer>,
) -> AppResult<Json<Player>> {
    let player = sqlx::query_as!(
        Player,
        "SELECT * FROM players WHERE id = $1 AND organization_id = $2",
        id,
        admin.0.org_id
    )
    .fetch_optional(&state.pool)
    .await?
    .ok_or(AppError::NotFound)?;

    let player_group_id = state
        .keycloak_admin
        .find_group_id(admin.0.org_id, "player")
        .await?;
    state
        .keycloak_admin
        .create_user_with_temp_password(
            &body.email,
            &player.first_name,
            &player.last_name,
            &player_group_id,
        )
        .await?;

    let updated = sqlx::query_as!(
        Player,
        "UPDATE players SET email = $1, updated_at = now() WHERE id = $2 RETURNING *",
        body.email,
        id,
    )
    .fetch_one(&state.pool)
    .await?;
    Ok(Json(updated))
}
