use axum::{
    Json,
    extract::{Path, State},
    http::StatusCode,
};
use uuid::Uuid;

use crate::auth::{AdminUser, CurrentUser, SuperAdminUser};
use crate::db::models::Organization;
use crate::dto::{CreateOrganization, PatchOrganization};
use crate::error::{AppError, AppResult};
use crate::state::AppState;

/// Turns a space's display name into a URL/group-safe slug
/// ("Les Handballeurs Fous !" -> "les-handballeurs-fous").
fn slugify(name: &str) -> String {
    let mut slug = String::new();
    let mut last_was_dash = true; // swallow a would-be leading dash
    for c in name.to_lowercase().chars() {
        if c.is_ascii_alphanumeric() {
            slug.push(c);
            last_was_dash = false;
        } else if !last_was_dash {
            slug.push('-');
            last_was_dash = true;
        }
    }
    let trimmed = slug.trim_end_matches('-');
    if trimmed.is_empty() {
        "espace".to_string()
    } else {
        trimmed.to_string()
    }
}

/// Self-service space creation: any authenticated Keycloak account with no
/// existing org can create one. The new space starts `approved = false`
/// (see `0003_organizations.sql`) — a super-admin must validate it before
/// anyone in it can touch real data (`OrgUser` extractor enforces that).
pub async fn create_organization(
    State(state): State<AppState>,
    user: CurrentUser,
    Json(body): Json<CreateOrganization>,
) -> AppResult<Json<Organization>> {
    if user.org_id.is_some() {
        return Err(AppError::BadRequest(
            "account already belongs to an organization".into(),
        ));
    }
    let name = body.name.trim();
    let contact_email = body.contact_email.trim();
    if name.is_empty() || contact_email.is_empty() {
        return Err(AppError::BadRequest(
            "name and contact_email are required".into(),
        ));
    }

    let base_slug = slugify(name);
    let mut slug = base_slug.clone();
    let mut attempt = 1;
    let org = loop {
        let result = sqlx::query_as!(
            Organization,
            "INSERT INTO organizations (name, slug, contact_email, created_by) VALUES ($1, $2, $3, $4) RETURNING *",
            name,
            slug,
            contact_email,
            user.sub,
        )
        .fetch_one(&state.pool)
        .await;

        match result {
            Ok(org) => break org,
            Err(sqlx::Error::Database(db_err))
                if db_err.constraint() == Some("organizations_slug_key") =>
            {
                attempt += 1;
                slug = format!("{base_slug}-{attempt}");
            }
            Err(err) => return Err(err.into()),
        }
    };

    let group_ids = state.keycloak_admin.create_org_groups(org.id).await?;
    state
        .keycloak_admin
        .add_user_to_group(&user.sub, &group_ids.admin_group_id)
        .await?;
    seed_default_types(&state.pool, org.id).await?;

    Ok(Json(org))
}

/// Every space needs somewhere to start: the same beer/soft prices and fine
/// list the original single-team app shipped with (`0002_seed.sql`), copied
/// per-org since there's no "create a consumable/fine type" endpoint —
/// admins only ever edit these seeded rows via Réglages.
async fn seed_default_types(pool: &sqlx::PgPool, org_id: Uuid) -> AppResult<()> {
    sqlx::query!(
        r#"
        INSERT INTO consumable_types (organization_id, code, label, price_cents) VALUES
            ($1, 'beer', 'Bière', 100),
            ($1, 'soft', 'Soft', 100)
        "#,
        org_id,
    )
    .execute(pool)
    .await?;

    sqlx::query!(
        r#"
        INSERT INTO fine_types (organization_id, code, label, amount_cents) VALUES
            ($1, 'late_training', 'Retard entraînement', 200),
            ($1, 'forgot_gear', 'Oubli d''équipement', 200),
            ($1, 'red_card', 'Carton rouge', 500)
        "#,
        org_id,
    )
    .execute(pool)
    .await?;

    Ok(())
}

/// Every space, approved or not — lets the super-admin operator browse into
/// any organization's data (see `players::list_players_for_org`), not just
/// the ones still awaiting approval.
pub async fn list_organizations(
    State(state): State<AppState>,
    _super_admin: SuperAdminUser,
) -> AppResult<Json<Vec<Organization>>> {
    let orgs = sqlx::query_as!(Organization, "SELECT * FROM organizations ORDER BY name")
        .fetch_all(&state.pool)
        .await?;
    Ok(Json(orgs))
}

pub async fn list_pending_organizations(
    State(state): State<AppState>,
    _super_admin: SuperAdminUser,
) -> AppResult<Json<Vec<Organization>>> {
    let orgs = sqlx::query_as!(
        Organization,
        "SELECT * FROM organizations WHERE approved = false ORDER BY created_at"
    )
    .fetch_all(&state.pool)
    .await?;
    Ok(Json(orgs))
}

/// Lets an org admin set (or clear) the treasury's fill objective, shown as
/// a progress bar on the dashboard against the current balance.
pub async fn patch_my_organization(
    State(state): State<AppState>,
    admin: AdminUser,
    Json(body): Json<PatchOrganization>,
) -> AppResult<Json<Organization>> {
    let org = sqlx::query_as!(
        Organization,
        r#"
        UPDATE organizations SET
            target_cents = $1,
            debt_alert_threshold_cents = $2,
            updated_at = now()
        WHERE id = $3
        RETURNING *
        "#,
        body.target_cents,
        body.debt_alert_threshold_cents,
        admin.0.org_id,
    )
    .fetch_one(&state.pool)
    .await?;
    Ok(Json(org))
}

pub async fn approve_organization(
    State(state): State<AppState>,
    _super_admin: SuperAdminUser,
    Path(id): Path<Uuid>,
) -> AppResult<Json<Organization>> {
    let org = sqlx::query_as!(
        Organization,
        "UPDATE organizations SET approved = true, updated_at = now() WHERE id = $1 RETURNING *",
        id
    )
    .fetch_optional(&state.pool)
    .await?
    .ok_or(AppError::NotFound)?;
    Ok(Json(org))
}

/// The other half of the super-admin's moderation job: refusing a space
/// creation request instead of approving it. Deliberately limited to
/// *pending* spaces — an approved space holds a real caisse noire (players,
/// ledger, history) whose destruction isn't a moderation decision, so the
/// route refuses it rather than cascading through live data.
///
/// A pending space has never been usable (`OrgUser` rejects everyone in it
/// with `OrgPending`), so the only rows it can own are the beer/soft/fine
/// types seeded at creation — deleted here alongside the org itself, in
/// foreign-key order, within one transaction. The Keycloak groups go last
/// and on a best-effort basis: leaving a group behind whose org row is gone
/// is recoverable from the console, whereas failing the whole request after
/// the rows are gone would leave the operator staring at a space that's
/// half-deleted and no longer listed.
pub async fn delete_organization(
    State(state): State<AppState>,
    _super_admin: SuperAdminUser,
    Path(id): Path<Uuid>,
) -> AppResult<StatusCode> {
    let approved = sqlx::query_scalar!("SELECT approved FROM organizations WHERE id = $1", id)
        .fetch_optional(&state.pool)
        .await?
        .ok_or(AppError::NotFound)?;
    if approved {
        return Err(AppError::BadRequest(
            "cannot delete an approved organization".into(),
        ));
    }

    let mut tx = state.pool.begin().await?;
    sqlx::query!("DELETE FROM device_tokens WHERE organization_id = $1", id)
        .execute(&mut *tx)
        .await?;
    sqlx::query!("DELETE FROM transactions WHERE organization_id = $1", id)
        .execute(&mut *tx)
        .await?;
    sqlx::query!("DELETE FROM players WHERE organization_id = $1", id)
        .execute(&mut *tx)
        .await?;
    sqlx::query!(
        "DELETE FROM consumable_types WHERE organization_id = $1",
        id
    )
    .execute(&mut *tx)
    .await?;
    sqlx::query!("DELETE FROM fine_types WHERE organization_id = $1", id)
        .execute(&mut *tx)
        .await?;
    sqlx::query!("DELETE FROM organizations WHERE id = $1", id)
        .execute(&mut *tx)
        .await?;
    tx.commit().await?;

    if let Err(err) = state.keycloak_admin.delete_org_groups(id).await {
        tracing::warn!(%err, %id, "organization deleted but its Keycloak groups could not be removed");
    }

    Ok(StatusCode::NO_CONTENT)
}
