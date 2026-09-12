use sqlx::PgPool;
use uuid::Uuid;

use crate::db::models::{Transaction, TransactionKind};
use crate::error::{AppError, AppResult};

/// Single choke point for every balance-affecting write: inserts the ledger
/// row and updates the cached `players.balance_cents` atomically, so the
/// cache can never drift from the ledger that is the actual source of truth.
#[allow(clippy::too_many_arguments)]
async fn insert_and_apply(
    pool: &PgPool,
    org_id: Uuid,
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

    // Scoped by organization_id too: even if a caller somehow got hold of a
    // player_id from another space, this can't touch it.
    let player_exists = sqlx::query_scalar!(
        "SELECT id FROM players WHERE id = $1 AND organization_id = $2 AND active = true FOR UPDATE",
        player_id,
        org_id,
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
            (organization_id, player_id, kind, amount_cents, quantity, unit_price_cents, consumable_type_id, fine_type_id, note, created_by)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
        RETURNING id, organization_id, player_id, kind AS "kind: TransactionKind", amount_cents, quantity,
                  unit_price_cents, consumable_type_id, fine_type_id, note, created_by, created_at
        "#,
        org_id,
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
    org_id: Uuid,
    player_id: Uuid,
    consumable_type_id: Uuid,
    quantity: i32,
    created_by: &str,
) -> AppResult<Transaction> {
    if quantity < 1 {
        return Err(AppError::BadRequest("quantity must be at least 1".into()));
    }

    let consumable = sqlx::query!(
        "SELECT code, price_cents FROM consumable_types WHERE id = $1 AND organization_id = $2 AND active = true",
        consumable_type_id,
        org_id,
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
        org_id,
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
    org_id: Uuid,
    player_id: Uuid,
    fine_type_id: Uuid,
    note: Option<String>,
    created_by: &str,
) -> AppResult<Transaction> {
    let fine = sqlx::query!(
        "SELECT amount_cents FROM fine_types WHERE id = $1 AND organization_id = $2 AND active = true",
        fine_type_id,
        org_id,
    )
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| AppError::BadRequest("unknown or inactive fine type".into()))?;

    insert_and_apply(
        pool,
        org_id,
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
    org_id: Uuid,
    player_id: Uuid,
    amount_cents: i64,
    note: Option<String>,
    created_by: &str,
) -> AppResult<Transaction> {
    if amount_cents <= 0 {
        return Err(AppError::BadRequest("amount_cents must be positive".into()));
    }

    insert_and_apply(
        pool,
        org_id,
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
    org_id: Uuid,
    player_id: Uuid,
    amount_cents: i64,
    note: String,
    created_by: &str,
) -> AppResult<Transaction> {
    insert_and_apply(
        pool,
        org_id,
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

#[cfg(test)]
mod tests {
    use super::*;

    async fn test_pool() -> PgPool {
        let url = std::env::var("DATABASE_URL")
            .expect("DATABASE_URL must be set to run these tests (needs a real Postgres)");
        PgPool::connect(&url)
            .await
            .expect("failed to connect to test database")
    }

    async fn moelan_org_id(pool: &PgPool) -> Uuid {
        sqlx::query_scalar!("SELECT id FROM organizations WHERE slug = 'moelan'")
            .fetch_one(pool)
            .await
            .expect("seed data must contain the default 'moelan' organization")
    }

    async fn create_test_player(pool: &PgPool, org_id: Uuid, label: &str) -> Uuid {
        sqlx::query_scalar!(
            "INSERT INTO players (organization_id, first_name, last_name) VALUES ($1, $2, 'Test') RETURNING id",
            org_id,
            label
        )
        .fetch_one(pool)
        .await
        .expect("failed to create test player")
    }

    /// The one invariant the whole ledger design exists to guarantee:
    /// `players.balance_cents` always equals the sum of that player's
    /// `transactions` rows, no matter which mix of actions produced it.
    #[tokio::test]
    async fn balance_matches_sum_of_ledger_after_mixed_actions() {
        let pool = test_pool().await;
        let org_id = moelan_org_id(&pool).await;
        let player_id = create_test_player(&pool, org_id, "balance-sum-check").await;

        let beer_id: Uuid = sqlx::query_scalar!(
            "SELECT id FROM consumable_types WHERE organization_id = $1 AND code = 'beer'",
            org_id
        )
        .fetch_one(&pool)
        .await
        .expect("seed data must contain a 'beer' consumable type");
        let fine_id: Uuid = sqlx::query_scalar!(
            "SELECT id FROM fine_types WHERE organization_id = $1 AND code = 'red_card'",
            org_id
        )
        .fetch_one(&pool)
        .await
        .expect("seed data must contain a 'red_card' fine type");

        record_credit(&pool, org_id, player_id, 2000, None, "test")
            .await
            .expect("credit should succeed");
        record_consumption(&pool, org_id, player_id, beer_id, 2, "test")
            .await
            .expect("consumption should succeed");
        record_fine(&pool, org_id, player_id, fine_id, None, "test")
            .await
            .expect("fine should succeed");

        let balance: i64 =
            sqlx::query_scalar!("SELECT balance_cents FROM players WHERE id = $1", player_id)
                .fetch_one(&pool)
                .await
                .unwrap();
        let ledger_sum: i64 = sqlx::query_scalar!(
            "SELECT COALESCE(SUM(amount_cents), 0)::bigint FROM transactions WHERE player_id = $1",
            player_id
        )
        .fetch_one(&pool)
        .await
        .unwrap()
        .unwrap();

        assert_eq!(
            ledger_sum, balance,
            "cached balance must equal the ledger sum"
        );
        assert_eq!(
            balance,
            2000 - 200 - 500,
            "2000 credit - 2 beers (1€) - red_card (5€)"
        );
    }

    #[tokio::test]
    async fn action_on_unknown_player_returns_not_found() {
        let pool = test_pool().await;
        let org_id = moelan_org_id(&pool).await;
        let result = record_credit(&pool, org_id, Uuid::new_v4(), 100, None, "test").await;
        assert!(matches!(result, Err(AppError::NotFound)));
    }

    #[tokio::test]
    async fn negative_credit_amount_is_rejected() {
        let pool = test_pool().await;
        let org_id = moelan_org_id(&pool).await;
        let player_id = create_test_player(&pool, org_id, "negative-credit-check").await;
        let result = record_credit(&pool, org_id, player_id, -100, None, "test").await;
        assert!(matches!(result, Err(AppError::BadRequest(_))));
    }
}
