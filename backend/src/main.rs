use std::sync::Arc;

use moelan_api::auth::JwtValidator;
use moelan_api::config::Config;
use moelan_api::state::AppState;
use moelan_api::{db, routes, services};

#[tokio::main]
async fn main() {
    dotenvy::dotenv().ok();
    tracing_subscriber::fmt()
        .with_env_filter(tracing_subscriber::EnvFilter::from_default_env())
        .init();

    let config = Config::from_env();

    let pool = db::connect(&config.database_url)
        .await
        .expect("failed to connect to database");

    sqlx::migrate!("./migrations")
        .run(&pool)
        .await
        .expect("failed to run migrations");

    let jwt = Arc::new(JwtValidator::new(
        config.keycloak_jwks_url.clone(),
        config.keycloak_issuer_url.clone(),
        config.keycloak_audience.clone(),
    ));
    let keycloak_admin = Arc::new(services::keycloak_admin::KeycloakAdmin::new(&config));
    let mailer = Arc::new(services::mail::Mailer::new(&config));
    let fcm = Arc::new(services::fcm::FcmSender::new(&config));

    let state = AppState {
        pool,
        jwt,
        keycloak_admin,
        mailer,
        fcm,
    };
    let app = routes::build_router(state);

    let listener = tokio::net::TcpListener::bind(&config.bind_addr)
        .await
        .expect("failed to bind listener");
    tracing::info!("listening on {}", config.bind_addr);
    axum::serve(listener, app).await.expect("server error");
}
