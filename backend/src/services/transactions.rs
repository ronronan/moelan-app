use sqlx::PgPool;
use uuid::Uuid;

use crate::db::models::{Transaction, TransactionKind};
use crate::error::{AppError, AppResult};
use crate::services::fcm::FcmSender;
use crate::services::mail::Mailer;

/// The two "tell someone outside the app" side effects every ledger write
/// can trigger — bundled so adding a third one later doesn't mean growing
/// every `record_*` function's argument list again.
pub struct Notifiers<'a> {
    pub mailer: &'a Mailer,
    pub fcm: &'a FcmSender,
}

/// Single choke point for every balance-affecting write: inserts the ledger
/// row and updates the cached `players.balance_cents` atomically, so the
/// cache can never drift from the ledger that is the actual source of truth.
#[allow(clippy::too_many_arguments)]
async fn insert_and_apply(
    pool: &PgPool,
    notifiers: &Notifiers<'_>,
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
    // player_id from another space, this can't touch it. Locked and read
    // together so we know the balance this write is about to move away
    // from, for the debt-alert crossing check below.
    let player = sqlx::query!(
        "SELECT id, first_name, last_name, balance_cents FROM players WHERE id = $1 AND organization_id = $2 AND active = true FOR UPDATE",
        player_id,
        org_id,
    )
    .fetch_optional(&mut *tx)
    .await?;
    let Some(player) = player else {
        return Err(AppError::NotFound);
    };
    let old_balance = player.balance_cents;
    let new_balance = old_balance + amount_cents;

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
        kind.clone() as TransactionKind,
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

    maybe_send_debt_alert(
        pool,
        notifiers.mailer,
        org_id,
        old_balance,
        new_balance,
        &player.first_name,
        &player.last_name,
    )
    .await;

    let (push_title, push_body) = push_notification_text(kind, amount_cents, new_balance);
    notifiers
        .fcm
        .notify_player(pool, org_id, player_id, &push_title, &push_body)
        .await;

    Ok(transaction)
}

/// M16 scaffolding: the message shown on a player's own device the moment
/// an action lands on their account (`FcmSender::notify_player` no-ops
/// until Firebase is actually configured, so this always runs but rarely
/// sends anything today).
fn push_notification_text(
    kind: TransactionKind,
    amount_cents: i64,
    new_balance: i64,
) -> (String, String) {
    let title = match kind {
        TransactionKind::Beer => "Bière",
        TransactionKind::Soft => "Soft",
        TransactionKind::Fine => "Amende",
        TransactionKind::Credit => "Crédit",
        TransactionKind::ManualAdjustment => "Ajustement",
    };
    let body = format!(
        "{:+.2} € — nouveau solde : {:.2} €",
        amount_cents as f64 / 100.0,
        new_balance as f64 / 100.0,
    );
    (title.to_string(), body)
}

/// Fires at most once per crossing: only when this write moves the balance
/// from at-or-above the org's threshold to below it. A player already deep
/// in debt doesn't get re-alerted on every subsequent beer — only when they
/// first cross the line (or cross it again after recovering above it).
/// Never fails the caller; a mail problem shouldn't roll back the write
/// that triggered it (see `Mailer::send`).
async fn maybe_send_debt_alert(
    pool: &PgPool,
    mailer: &Mailer,
    org_id: Uuid,
    old_balance: i64,
    new_balance: i64,
    first_name: &str,
    last_name: &str,
) {
    let org = sqlx::query!(
        "SELECT name, contact_email, debt_alert_threshold_cents FROM organizations WHERE id = $1",
        org_id,
    )
    .fetch_optional(pool)
    .await;
    let Ok(Some(org)) = org else {
        return;
    };
    let Some(threshold) = org.debt_alert_threshold_cents else {
        return;
    };
    if !crosses_threshold(old_balance, new_balance, threshold) {
        return;
    }

    let subject = format!("[{}] Seuil de dette dépassé", org.name);
    let body = format!(
        "{first_name} {last_name} est passé sous le seuil d'alerte ({:.2} €).\n\
         Nouveau solde : {:.2} €.",
        threshold as f64 / 100.0,
        new_balance as f64 / 100.0,
    );
    mailer.send(&org.contact_email, &subject, body).await;
}

/// True only the moment a balance moves from at-or-above the threshold to
/// strictly below it — never while already below (no repeat alerts per
/// beer) and never on the way back up.
fn crosses_threshold(old_balance: i64, new_balance: i64, threshold: i64) -> bool {
    old_balance >= threshold && new_balance < threshold
}

pub async fn record_consumption(
    pool: &PgPool,
    notifiers: &Notifiers<'_>,
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
        notifiers,
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
    notifiers: &Notifiers<'_>,
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
        notifiers,
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
    notifiers: &Notifiers<'_>,
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
        notifiers,
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
    notifiers: &Notifiers<'_>,
    org_id: Uuid,
    player_id: Uuid,
    amount_cents: i64,
    note: String,
    created_by: &str,
) -> AppResult<Transaction> {
    insert_and_apply(
        pool,
        notifiers,
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

        let notifiers = Notifiers {
            mailer: &Mailer::disabled(),
            fcm: &FcmSender::disabled(),
        };
        record_credit(&pool, &notifiers, org_id, player_id, 2000, None, "test")
            .await
            .expect("credit should succeed");
        record_consumption(&pool, &notifiers, org_id, player_id, beer_id, 2, "test")
            .await
            .expect("consumption should succeed");
        record_fine(&pool, &notifiers, org_id, player_id, fine_id, None, "test")
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
        let result = record_credit(
            &pool,
            &Notifiers {
                mailer: &Mailer::disabled(),
                fcm: &FcmSender::disabled(),
            },
            org_id,
            Uuid::new_v4(),
            100,
            None,
            "test",
        )
        .await;
        assert!(matches!(result, Err(AppError::NotFound)));
    }

    #[tokio::test]
    async fn negative_credit_amount_is_rejected() {
        let pool = test_pool().await;
        let org_id = moelan_org_id(&pool).await;
        let player_id = create_test_player(&pool, org_id, "negative-credit-check").await;
        let result = record_credit(
            &pool,
            &Notifiers {
                mailer: &Mailer::disabled(),
                fcm: &FcmSender::disabled(),
            },
            org_id,
            player_id,
            -100,
            None,
            "test",
        )
        .await;
        assert!(matches!(result, Err(AppError::BadRequest(_))));
    }

    #[test]
    fn crosses_threshold_fires_only_on_the_moment_of_crossing() {
        // Threshold -3000 (-30€): dropping from -2000 to -3500 crosses it.
        assert!(crosses_threshold(-2000, -3500, -3000));
        // Already below: no repeat alert on the next debit.
        assert!(!crosses_threshold(-3500, -4000, -3000));
        // Recovering back above, then dropping below again: fires again.
        assert!(crosses_threshold(-2500, -3500, -3000));
        // Landing exactly on the threshold doesn't count as "below" it.
        assert!(!crosses_threshold(0, -3000, -3000));
        // Moving up never fires, even while below the threshold.
        assert!(!crosses_threshold(-4000, -3500, -3000));
    }
}
