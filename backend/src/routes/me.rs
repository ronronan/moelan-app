use axum::{Json, extract::State};
use serde::Serialize;

use crate::auth::CurrentUser;
use crate::db::models::Organization;
use crate::error::AppResult;
use crate::state::AppState;

/// Everything the frontend needs to route a freshly logged-in user: which
/// realm roles/org group it has (`CurrentUser`, whose `org_id`/`org_role`
/// come straight from the JWT) plus the org row itself (whose `approved`
/// flag can't be known from the token). Deliberately reachable without an
/// approved org — it's how the create-space / pending-approval screens
/// figure out which one to show.
#[derive(Serialize)]
pub struct MeStatus {
    #[serde(flatten)]
    pub user: CurrentUser,
    pub organization: Option<Organization>,
}

pub async fn me(State(state): State<AppState>, user: CurrentUser) -> AppResult<Json<MeStatus>> {
    let organization = match user.org_id {
        Some(org_id) => {
            sqlx::query_as!(
                Organization,
                "SELECT * FROM organizations WHERE id = $1",
                org_id
            )
            .fetch_optional(&state.pool)
            .await?
        }
        None => None,
    };
    Ok(Json(MeStatus { user, organization }))
}
