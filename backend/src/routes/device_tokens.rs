use axum::{Json, extract::State, http::StatusCode};

use crate::auth::OrgUser;
use crate::dto::RegisterDeviceToken;
use crate::error::AppResult;
use crate::state::AppState;

/// Registers (or re-registers, on token refresh) this device for push
/// notifications. `email` is captured from the account's own username —
/// the realm has `registrationEmailAsUsername` on, so it doubles as the
/// email — and is how `services::fcm` later finds "this player's" tokens
/// without the client needing to know its own player id.
pub async fn register_device_token(
    State(state): State<AppState>,
    org: OrgUser,
    Json(body): Json<RegisterDeviceToken>,
) -> AppResult<StatusCode> {
    sqlx::query!(
        r#"
        INSERT INTO device_tokens (organization_id, user_sub, email, token, platform)
        VALUES ($1, $2, $3, $4, $5)
        ON CONFLICT (token) DO UPDATE SET
            organization_id = EXCLUDED.organization_id,
            user_sub = EXCLUDED.user_sub,
            email = EXCLUDED.email,
            platform = EXCLUDED.platform
        "#,
        org.org_id,
        org.user.sub,
        org.user.username,
        body.token,
        body.platform,
    )
    .execute(&state.pool)
    .await?;
    Ok(StatusCode::NO_CONTENT)
}
