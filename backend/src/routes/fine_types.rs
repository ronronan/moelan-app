use axum::{
    Json,
    extract::{Path, State},
};
use sqlx::PgPool;
use uuid::Uuid;

use crate::db::models::FineType;
use crate::dto::{CreateFineType, PatchFineType};
use crate::error::{AppError, AppResult};

pub async fn list_fine_types(State(pool): State<PgPool>) -> AppResult<Json<Vec<FineType>>> {
    let types = sqlx::query_as!(FineType, "SELECT * FROM fine_types ORDER BY label")
        .fetch_all(&pool)
        .await?;
    Ok(Json(types))
}

pub async fn create_fine_type(
    State(pool): State<PgPool>,
    Json(body): Json<CreateFineType>,
) -> AppResult<Json<FineType>> {
    let fine_type = sqlx::query_as!(
        FineType,
        "INSERT INTO fine_types (code, label, amount_cents) VALUES ($1, $2, $3) RETURNING *",
        body.code,
        body.label,
        body.amount_cents,
    )
    .fetch_one(&pool)
    .await?;
    Ok(Json(fine_type))
}

pub async fn patch_fine_type(
    State(pool): State<PgPool>,
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
        WHERE id = $4
        RETURNING *
        "#,
        body.label,
        body.amount_cents,
        body.active,
        id,
    )
    .fetch_optional(&pool)
    .await?
    .ok_or(AppError::NotFound)?;
    Ok(Json(updated))
}
