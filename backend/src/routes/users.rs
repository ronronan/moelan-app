use std::collections::HashMap;

use axum::{Json, extract::State};
use serde::Serialize;
use uuid::Uuid;

use crate::auth::{OrgRole, SuperAdminUser};
use crate::error::AppResult;
use crate::state::AppState;

/// One row of the super-admin's cross-space user listing: who the account
/// is, what it can do, and where. Keycloak owns the identity and the roles;
/// Postgres owns the space's name — neither side alone can answer "who uses
/// this app", which is why this route joins them.
#[derive(Debug, Serialize)]
pub struct UserSummary {
    /// Keycloak user id — the same value as the JWT `sub` every ledger row
    /// records in `created_by`.
    pub id: String,
    pub username: String,
    pub email: Option<String>,
    pub first_name: Option<String>,
    pub last_name: Option<String>,
    pub enabled: bool,
    pub superadmin: bool,
    /// `admin` / `member` / `player`, or `None` for an account that hasn't
    /// created or been invited into a space yet.
    pub org_role: Option<OrgRole>,
    pub organization_id: Option<Uuid>,
    pub organization_name: Option<String>,
    /// `false` for a space still awaiting super-admin validation — the
    /// account exists and has a role, but can't use it yet.
    pub organization_approved: Option<bool>,
}

/// Same parsing rule as the JWT's `groups` claim (`auth::jwt`), applied
/// here to the group paths the Admin API returns instead: one
/// `/org-<uuid>/<role>` membership per account.
fn parse_group_path(path: &str) -> Option<(Uuid, OrgRole)> {
    let trimmed = path.trim_start_matches('/');
    let (org_part, role_part) = trimmed.split_once('/')?;
    let org_id = Uuid::parse_str(org_part.strip_prefix("org-")?).ok()?;
    let role = match role_part {
        "admin" => OrgRole::Admin,
        "member" => OrgRole::Member,
        "player" => OrgRole::Player,
        _ => return None,
    };
    Some((org_id, role))
}

pub async fn list_users(
    State(state): State<AppState>,
    _super_admin: SuperAdminUser,
) -> AppResult<Json<Vec<UserSummary>>> {
    let users = state.keycloak_admin.list_users().await?;

    let orgs = sqlx::query!("SELECT id, name, approved FROM organizations")
        .fetch_all(&state.pool)
        .await?;
    let orgs: HashMap<Uuid, (String, bool)> = orgs
        .into_iter()
        .map(|row| (row.id, (row.name, row.approved)))
        .collect();

    let mut summaries: Vec<UserSummary> = users
        .into_iter()
        .map(|user| {
            let membership = user.groups.iter().find_map(|path| parse_group_path(path));
            let org = membership.and_then(|(org_id, _)| orgs.get(&org_id));
            UserSummary {
                id: user.id,
                username: user.username,
                email: user.email,
                first_name: user.first_name,
                last_name: user.last_name,
                enabled: user.enabled,
                superadmin: user.realm_roles.iter().any(|r| r == "superadmin"),
                org_role: membership.map(|(_, role)| role),
                organization_id: membership.map(|(org_id, _)| org_id),
                organization_name: org.map(|(name, _)| name.clone()),
                organization_approved: org.map(|(_, approved)| *approved),
            }
        })
        .collect();

    // Grouped by space (accounts without one last), then alphabetically —
    // the listing is read as "who is in which space", not as a flat roster.
    summaries.sort_by(|a, b| {
        a.organization_name
            .is_none()
            .cmp(&b.organization_name.is_none())
            .then_with(|| a.organization_name.cmp(&b.organization_name))
            .then_with(|| a.username.cmp(&b.username))
    });
    Ok(Json(summaries))
}
