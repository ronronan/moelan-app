use axum::{
    Json,
    extract::{Path, State},
};
use uuid::Uuid;

use crate::auth::{AdminUser, OrgUser};
use crate::db::models::ConsumableType;
use crate::dto::PatchConsumableType;
use crate::error::{AppError, AppResult};
use crate::state::AppState;

pub async fn list_consumable_types(
    State(state): State<AppState>,
    org: OrgUser,
) -> AppResult<Json<Vec<ConsumableType>>> {
    let types = sqlx::query_as!(
        ConsumableType,
        "SELECT * FROM consumable_types WHERE organization_id = $1 ORDER BY code",
        org.org_id
    )
    .fetch_all(&state.pool)
    .await?;
    Ok(Json(types))
}

pub async fn patch_consumable_type(
    State(state): State<AppState>,
    admin: AdminUser,
    Path(id): Path<Uuid>,
    Json(body): Json<PatchConsumableType>,
) -> AppResult<Json<ConsumableType>> {
    let updated = sqlx::query_as!(
        ConsumableType,
        r#"
        UPDATE consumable_types SET
            label = COALESCE($1, label),
            price_cents = COALESCE($2, price_cents),
            active = COALESCE($3, active),
            updated_at = now()
        WHERE id = $4 AND organization_id = $5
        RETURNING *
        "#,
        body.label,
        body.price_cents,
        body.active,
        id,
        admin.0.org_id,
    )
    .fetch_optional(&state.pool)
    .await?
    .ok_or(AppError::NotFound)?;
    Ok(Json(updated))
}
