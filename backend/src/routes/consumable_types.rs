use axum::{
    Json,
    extract::{Path, State},
};
use sqlx::PgPool;
use uuid::Uuid;

use crate::db::models::ConsumableType;
use crate::dto::PatchConsumableType;
use crate::error::{AppError, AppResult};

pub async fn list_consumable_types(
    State(pool): State<PgPool>,
) -> AppResult<Json<Vec<ConsumableType>>> {
    let types = sqlx::query_as!(ConsumableType, "SELECT * FROM consumable_types ORDER BY code")
        .fetch_all(&pool)
        .await?;
    Ok(Json(types))
}

pub async fn patch_consumable_type(
    State(pool): State<PgPool>,
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
        WHERE id = $4
        RETURNING *
        "#,
        body.label,
        body.price_cents,
        body.active,
        id,
    )
    .fetch_optional(&pool)
    .await?
    .ok_or(AppError::NotFound)?;
    Ok(Json(updated))
}
