use axum::{
    Json,
    extract::{Path, Query, State},
};
use sqlx::{PgPool, QueryBuilder};
use uuid::Uuid;

use crate::db::models::{Transaction, TransactionKind};
use crate::dto::{CreateAdjustment, CreateConsumption, CreateCredit, CreateFine, TransactionQuery};
use crate::error::AppResult;
use crate::services::transactions as service;

/// Placeholder actor identity until Keycloak auth lands (M4), which will
/// replace this with the `sub` claim of the validated bearer token.
const DEV_ACTOR: &str = "local-dev";

pub async fn create_consumption(
    State(pool): State<PgPool>,
    Path(player_id): Path<Uuid>,
    Json(body): Json<CreateConsumption>,
) -> AppResult<Json<Transaction>> {
    let tx = service::record_consumption(
        &pool,
        player_id,
        body.consumable_type_id,
        body.quantity,
        DEV_ACTOR,
    )
    .await?;
    Ok(Json(tx))
}

pub async fn create_fine(
    State(pool): State<PgPool>,
    Path(player_id): Path<Uuid>,
    Json(body): Json<CreateFine>,
) -> AppResult<Json<Transaction>> {
    let tx = service::record_fine(&pool, player_id, body.fine_type_id, body.note, DEV_ACTOR).await?;
    Ok(Json(tx))
}

pub async fn create_credit(
    State(pool): State<PgPool>,
    Path(player_id): Path<Uuid>,
    Json(body): Json<CreateCredit>,
) -> AppResult<Json<Transaction>> {
    let tx =
        service::record_credit(&pool, player_id, body.amount_cents, body.note, DEV_ACTOR).await?;
    Ok(Json(tx))
}

pub async fn create_adjustment(
    State(pool): State<PgPool>,
    Path(player_id): Path<Uuid>,
    Json(body): Json<CreateAdjustment>,
) -> AppResult<Json<Transaction>> {
    let tx =
        service::record_adjustment(&pool, player_id, body.amount_cents, body.note, DEV_ACTOR)
            .await?;
    Ok(Json(tx))
}

pub async fn list_player_transactions(
    State(pool): State<PgPool>,
    Path(player_id): Path<Uuid>,
    Query(query): Query<TransactionQuery>,
) -> AppResult<Json<Vec<Transaction>>> {
    let (limit, offset) = paginate(&query);
    let transactions = sqlx::query_as!(
        Transaction,
        r#"
        SELECT id, player_id, kind AS "kind: TransactionKind", amount_cents, quantity,
               unit_price_cents, consumable_type_id, fine_type_id, note, created_by, created_at
        FROM transactions
        WHERE player_id = $1
        ORDER BY created_at DESC
        LIMIT $2 OFFSET $3
        "#,
        player_id,
        limit,
        offset,
    )
    .fetch_all(&pool)
    .await?;
    Ok(Json(transactions))
}

pub async fn list_transactions(
    State(pool): State<PgPool>,
    Query(query): Query<TransactionQuery>,
) -> AppResult<Json<Vec<Transaction>>> {
    let (limit, offset) = paginate(&query);

    let mut builder = QueryBuilder::new(
        r#"SELECT id, player_id, kind, amount_cents, quantity, unit_price_cents,
                  consumable_type_id, fine_type_id, note, created_by, created_at
           FROM transactions WHERE 1 = 1"#,
    );
    if let Some(player_id) = query.player_id {
        builder.push(" AND player_id = ").push_bind(player_id);
    }
    if let Some(kind) = &query.kind {
        builder.push(" AND kind = ").push_bind(kind.clone()).push("::transaction_kind");
    }
    if let Some(from) = query.from {
        builder.push(" AND created_at >= ").push_bind(from);
    }
    if let Some(to) = query.to {
        builder.push(" AND created_at <= ").push_bind(to);
    }
    builder.push(" ORDER BY created_at DESC LIMIT ");
    builder.push_bind(limit);
    builder.push(" OFFSET ");
    builder.push_bind(offset);

    let transactions = builder
        .build_query_as::<Transaction>()
        .fetch_all(&pool)
        .await?;
    Ok(Json(transactions))
}

fn paginate(query: &TransactionQuery) -> (i64, i64) {
    let page = query.page.unwrap_or(1).max(1);
    let page_size = query.page_size.unwrap_or(50).clamp(1, 200);
    (page_size, (page - 1) * page_size)
}
