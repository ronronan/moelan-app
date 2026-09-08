use axum::extract::FromRequestParts;
use axum::http::request::Parts;

use crate::auth::jwt::CurrentUser;
use crate::error::AppError;
use crate::state::AppState;

impl FromRequestParts<AppState> for CurrentUser {
    type Rejection = AppError;

    async fn from_request_parts(parts: &mut Parts, state: &AppState) -> Result<Self, Self::Rejection> {
        let header = parts
            .headers
            .get(axum::http::header::AUTHORIZATION)
            .and_then(|v| v.to_str().ok())
            .ok_or(AppError::Unauthorized)?;

        let token = header.strip_prefix("Bearer ").ok_or(AppError::Unauthorized)?;
        state.jwt.validate(token).await
    }
}

/// Wraps `CurrentUser`, additionally requiring the realm `admin` role.
pub struct AdminUser(pub CurrentUser);

impl FromRequestParts<AppState> for AdminUser {
    type Rejection = AppError;

    async fn from_request_parts(parts: &mut Parts, state: &AppState) -> Result<Self, Self::Rejection> {
        let user = CurrentUser::from_request_parts(parts, state).await?;
        if user.is_admin() {
            Ok(AdminUser(user))
        } else {
            Err(AppError::Forbidden)
        }
    }
}
