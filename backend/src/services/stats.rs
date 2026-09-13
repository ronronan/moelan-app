use chrono::{DateTime, Utc};
use serde::Serialize;
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::AppResult;

#[derive(Debug, Serialize)]
pub struct MonthlyStat {
    pub month: DateTime<Utc>,
    pub beer_count: i64,
    pub soft_count: i64,
    pub fine_total_cents: i64,
    pub credit_total_cents: i64,
    pub net_cents: i64,
    /// Cumulative cagnotte balance at the end of this month — computed over
    /// the org's whole history, not just the requested year, so a January
    /// row correctly reflects everything banked in prior years too.
    pub balance_cents: i64,
}

pub async fn monthly(pool: &PgPool, org_id: Uuid, year: i32) -> AppResult<Vec<MonthlyStat>> {
    let rows = sqlx::query!(
        r#"
        WITH monthly AS (
            SELECT
                date_trunc('month', created_at) AS month,
                SUM(amount_cents)::bigint AS net_cents,
                SUM(CASE WHEN kind = 'beer' THEN quantity ELSE 0 END)::bigint AS beer_count,
                SUM(CASE WHEN kind = 'soft' THEN quantity ELSE 0 END)::bigint AS soft_count,
                SUM(CASE WHEN kind = 'fine' THEN -amount_cents ELSE 0 END)::bigint AS fine_total_cents,
                SUM(CASE WHEN kind = 'credit' THEN amount_cents ELSE 0 END)::bigint AS credit_total_cents
            FROM transactions
            WHERE organization_id = $1
            GROUP BY month
        ),
        cumulative AS (
            SELECT
                month,
                net_cents,
                beer_count,
                soft_count,
                fine_total_cents,
                credit_total_cents,
                SUM(net_cents) OVER (ORDER BY month)::bigint AS balance_cents
            FROM monthly
        )
        SELECT
            month AS "month!: DateTime<Utc>",
            beer_count AS "beer_count!",
            soft_count AS "soft_count!",
            fine_total_cents AS "fine_total_cents!",
            credit_total_cents AS "credit_total_cents!",
            net_cents AS "net_cents!",
            balance_cents AS "balance_cents!"
        FROM cumulative
        WHERE date_part('year', month) = $2::double precision
        ORDER BY month
        "#,
        org_id,
        year as f64,
    )
    .fetch_all(pool)
    .await?;

    Ok(rows
        .into_iter()
        .map(|r| MonthlyStat {
            month: r.month,
            beer_count: r.beer_count,
            soft_count: r.soft_count,
            fine_total_cents: r.fine_total_cents,
            credit_total_cents: r.credit_total_cents,
            net_cents: r.net_cents,
            balance_cents: r.balance_cents,
        })
        .collect())
}
