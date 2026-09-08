use axum::Json;

use crate::auth::CurrentUser;

pub async fn me(user: CurrentUser) -> Json<CurrentUser> {
    Json(user)
}
