use axum::extract::FromRequestParts;
use axum::http::request::Parts;
use uuid::Uuid;

use crate::auth::jwt::CurrentUser;
use crate::error::AppError;
use crate::state::AppState;

impl FromRequestParts<AppState> for CurrentUser {
    type Rejection = AppError;

    async fn from_request_parts(
        parts: &mut Parts,
        state: &AppState,
    ) -> Result<Self, Self::Rejection> {
        let header = parts
            .headers
            .get(axum::http::header::AUTHORIZATION)
            .and_then(|v| v.to_str().ok())
            .ok_or(AppError::Unauthorized)?;

        let token = header
            .strip_prefix("Bearer ")
            .ok_or(AppError::Unauthorized)?;
        state.jwt.validate(token).await
    }
}

/// A `CurrentUser` known to belong to an *approved* organization. Every
/// domain route (players, transactions, ...) requires this rather than bare
/// `CurrentUser`, so an account whose space hasn't been validated yet can
/// still log in (to see the pending-approval screen) but can't touch any
/// real data.
pub struct OrgUser {
    pub user: CurrentUser,
    pub org_id: Uuid,
}

impl FromRequestParts<AppState> for OrgUser {
    type Rejection = AppError;

    async fn from_request_parts(
        parts: &mut Parts,
        state: &AppState,
    ) -> Result<Self, Self::Rejection> {
        let user = CurrentUser::from_request_parts(parts, state).await?;
        let org_id = user.org_id.ok_or(AppError::NoOrganization)?;

        let approved =
            sqlx::query_scalar!("SELECT approved FROM organizations WHERE id = $1", org_id)
                .fetch_optional(&state.pool)
                .await?
                .ok_or(AppError::NoOrganization)?;

        if !approved {
            return Err(AppError::OrgPending);
        }

        Ok(OrgUser { user, org_id })
    }
}

/// Wraps `OrgUser`, additionally requiring the org role `admin` or `member`
/// — everyone except the read-only `player` role.
pub struct WriterUser(pub OrgUser);

impl FromRequestParts<AppState> for WriterUser {
    type Rejection = AppError;

    async fn from_request_parts(
        parts: &mut Parts,
        state: &AppState,
    ) -> Result<Self, Self::Rejection> {
        let org_user = OrgUser::from_request_parts(parts, state).await?;
        if org_user.user.can_write() {
            Ok(WriterUser(org_user))
        } else {
            Err(AppError::Forbidden)
        }
    }
}

/// Wraps `OrgUser`, additionally requiring the org role `admin`.
pub struct AdminUser(pub OrgUser);

impl FromRequestParts<AppState> for AdminUser {
    type Rejection = AppError;

    async fn from_request_parts(
        parts: &mut Parts,
        state: &AppState,
    ) -> Result<Self, Self::Rejection> {
        let org_user = OrgUser::from_request_parts(parts, state).await?;
        if org_user.user.is_org_admin() {
            Ok(AdminUser(org_user))
        } else {
            Err(AppError::Forbidden)
        }
    }
}

/// Wraps `CurrentUser`, requiring the realm-wide `superadmin` role. Not tied
/// to any single organization — this is the account (the app's operator)
/// that validates newly created spaces.
#[allow(dead_code)] // the wrapped user isn't needed yet — the extractor is the auth gate
pub struct SuperAdminUser(pub CurrentUser);

impl FromRequestParts<AppState> for SuperAdminUser {
    type Rejection = AppError;

    async fn from_request_parts(
        parts: &mut Parts,
        state: &AppState,
    ) -> Result<Self, Self::Rejection> {
        let user = CurrentUser::from_request_parts(parts, state).await?;
        if user.is_superadmin() {
            Ok(SuperAdminUser(user))
        } else {
            Err(AppError::Forbidden)
        }
    }
}
