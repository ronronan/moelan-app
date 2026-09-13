use axum::{
    Json,
    extract::{Query, State},
};
use chrono::Datelike;
use serde::Deserialize;

use crate::auth::OrgUser;
use crate::error::AppResult;
use crate::services::stats::{self, MonthlyStat};
use crate::state::AppState;

#[derive(Debug, Deserialize)]
pub struct MonthlyStatsQuery {
    pub year: Option<i32>,
}

/// Visible to every role in the space (admin/member/player) — these are
/// aggregates over data everyone can already see in the transaction
/// history, nothing more sensitive.
pub async fn monthly(
    State(state): State<AppState>,
    org: OrgUser,
    Query(query): Query<MonthlyStatsQuery>,
) -> AppResult<Json<Vec<MonthlyStat>>> {
    let year = query.year.unwrap_or_else(|| chrono::Utc::now().year());
    let rows = stats::monthly(&state.pool, org.org_id, year).await?;
    Ok(Json(rows))
}
