use std::sync::Arc;

use sqlx::PgPool;

use crate::auth::JwtValidator;

#[derive(Clone)]
pub struct AppState {
    pub pool: PgPool,
    pub jwt: Arc<JwtValidator>,
}
