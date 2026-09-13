use std::sync::Arc;

use sqlx::PgPool;

use crate::auth::JwtValidator;
use crate::services::keycloak_admin::KeycloakAdmin;
use crate::services::mail::Mailer;

#[derive(Clone)]
pub struct AppState {
    pub pool: PgPool,
    pub jwt: Arc<JwtValidator>,
    pub keycloak_admin: Arc<KeycloakAdmin>,
    pub mailer: Arc<Mailer>,
}
