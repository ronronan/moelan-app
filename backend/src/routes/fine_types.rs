use axum::{
    Json,
    extract::{Path, State},
};
use uuid::Uuid;

use crate::auth::{AdminUser, OrgUser};
use crate::db::models::FineType;
use crate::dto::{CreateFineType, PatchFineType};
use crate::error::{AppError, AppResult};
use crate::state::AppState;

pub async fn list_fine_types(
    State(state): State<AppState>,
    org: OrgUser,
) -> AppResult<Json<Vec<FineType>>> {
    let types = sqlx::query_as!(
        FineType,
        "SELECT * FROM fine_types WHERE organization_id = $1 ORDER BY label",
        org.org_id
    )
    .fetch_all(&state.pool)
    .await?;
    Ok(Json(types))
}

pub async fn create_fine_type(
    State(state): State<AppState>,
    admin: AdminUser,
    Json(body): Json<CreateFineType>,
) -> AppResult<Json<FineType>> {
    let fine_type = sqlx::query_as!(
        FineType,
        "INSERT INTO fine_types (organization_id, code, label, amount_cents) VALUES ($1, $2, $3, $4) RETURNING *",
        admin.0.org_id,
        body.code,
        body.label,
        body.amount_cents,
    )
    .fetch_one(&state.pool)
    .await?;
    Ok(Json(fine_type))
}

pub async fn patch_fine_type(
    State(state): State<AppState>,
    admin: AdminUser,
    Path(id): Path<Uuid>,
    Json(body): Json<PatchFineType>,
) -> AppResult<Json<FineType>> {
    let updated = sqlx::query_as!(
        FineType,
        r#"
        UPDATE fine_types SET
            label = COALESCE($1, label),
            amount_cents = COALESCE($2, amount_cents),
            active = COALESCE($3, active),
            updated_at = now()
        WHERE id = $4 AND organization_id = $5
        RETURNING *
        "#,
        body.label,
        body.amount_cents,
        body.active,
        id,
        admin.0.org_id,
    )
    .fetch_optional(&state.pool)
    .await?
    .ok_or(AppError::NotFound)?;
    Ok(Json(updated))
}
