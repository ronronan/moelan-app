use sqlx::PgPool;
use uuid::Uuid;

use crate::db::models::{Transaction, TransactionKind};
use crate::error::{AppError, AppResult};

/// Single choke point for every balance-affecting write: inserts the ledger
/// row and updates the cached `players.balance_cents` atomically, so the
/// cache can never drift from the ledger that is the actual source of truth.
async fn insert_and_apply(
    pool: &PgPool,
    player_id: Uuid,
    kind: TransactionKind,
    amount_cents: i64,
    quantity: i32,
    unit_price_cents: Option<i64>,
    consumable_type_id: Option<Uuid>,
    fine_type_id: Option<Uuid>,
    note: Option<String>,
    created_by: &str,
) -> AppResult<Transaction> {
    let mut tx = pool.begin().await?;

    let player_exists = sqlx::query_scalar!(
        "SELECT id FROM players WHERE id = $1 AND active = true FOR UPDATE",
        player_id
    )
    .fetch_optional(&mut *tx)
    .await?;
    if player_exists.is_none() {
        return Err(AppError::NotFound);
    }

    let transaction = sqlx::query_as!(
        Transaction,
        r#"
        INSERT INTO transactions
            (player_id, kind, amount_cents, quantity, unit_price_cents, consumable_type_id, fine_type_id, note, created_by)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
        RETURNING id, player_id, kind AS "kind: TransactionKind", amount_cents, quantity,
                  unit_price_cents, consumable_type_id, fine_type_id, note, created_by, created_at
        "#,
        player_id,
        kind as TransactionKind,
        amount_cents,
        quantity,
        unit_price_cents,
        consumable_type_id,
        fine_type_id,
        note,
        created_by,
    )
    .fetch_one(&mut *tx)
    .await?;

    sqlx::query!(
        "UPDATE players SET balance_cents = balance_cents + $1, updated_at = now() WHERE id = $2",
        amount_cents,
        player_id
    )
    .execute(&mut *tx)
    .await?;

    tx.commit().await?;
    Ok(transaction)
}

pub async fn record_consumption(
    pool: &PgPool,
    player_id: Uuid,
    consumable_type_id: Uuid,
    quantity: i32,
    created_by: &str,
) -> AppResult<Transaction> {
    if quantity < 1 {
        return Err(AppError::BadRequest("quantity must be at least 1".into()));
    }

    let consumable = sqlx::query!(
        "SELECT code, price_cents FROM consumable_types WHERE id = $1 AND active = true",
        consumable_type_id
    )
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| AppError::BadRequest("unknown or inactive consumable type".into()))?;

    // The ledger's `kind_matches_ref` CHECK only allows 'beer'/'soft' for a
    // consumable-linked row, so the seeded set is intentionally fixed (only
    // their price is admin-editable) rather than an open-ended type list.
    let kind = match consumable.code.as_str() {
        "beer" => TransactionKind::Beer,
        "soft" => TransactionKind::Soft,
        other => {
            return Err(AppError::BadRequest(format!(
                "unsupported consumable type code: {other}"
            )));
        }
    };
    let amount_cents = -consumable.price_cents * quantity as i64;

    insert_and_apply(
        pool,
        player_id,
        kind,
        amount_cents,
        quantity,
        Some(consumable.price_cents),
        Some(consumable_type_id),
        None,
        None,
        created_by,
    )
    .await
}

pub async fn record_fine(
    pool: &PgPool,
    player_id: Uuid,
    fine_type_id: Uuid,
    note: Option<String>,
    created_by: &str,
) -> AppResult<Transaction> {
    let fine = sqlx::query!(
        "SELECT amount_cents FROM fine_types WHERE id = $1 AND active = true",
        fine_type_id
    )
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| AppError::BadRequest("unknown or inactive fine type".into()))?;

    insert_and_apply(
        pool,
        player_id,
        TransactionKind::Fine,
        -fine.amount_cents,
        1,
        Some(fine.amount_cents),
        None,
        Some(fine_type_id),
        note,
        created_by,
    )
    .await
}

pub async fn record_credit(
    pool: &PgPool,
    player_id: Uuid,
    amount_cents: i64,
    note: Option<String>,
    created_by: &str,
) -> AppResult<Transaction> {
    if amount_cents <= 0 {
        return Err(AppError::BadRequest(
            "amount_cents must be positive".into(),
        ));
    }

    insert_and_apply(
        pool,
        player_id,
        TransactionKind::Credit,
        amount_cents,
        1,
        None,
        None,
        None,
        note,
        created_by,
    )
    .await
}

pub async fn record_adjustment(
    pool: &PgPool,
    player_id: Uuid,
    amount_cents: i64,
    note: String,
    created_by: &str,
) -> AppResult<Transaction> {
    insert_and_apply(
        pool,
        player_id,
        TransactionKind::ManualAdjustment,
        amount_cents,
        1,
        None,
        None,
        None,
        Some(note),
        created_by,
    )
    .await
}
