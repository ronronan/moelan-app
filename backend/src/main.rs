mod auth;
mod config;
mod db;
mod dto;
mod error;
mod routes;
mod services;
mod state;

use std::sync::Arc;

use auth::JwtValidator;
use config::Config;
use state::AppState;

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
        config.keycloak_issuer_url.clone(),
        config.keycloak_audience.clone(),
    ));

    let state = AppState { pool, jwt };
    let app = routes::build_router(state);

    let listener = tokio::net::TcpListener::bind(&config.bind_addr)
        .await
        .expect("failed to bind listener");
    tracing::info!("listening on {}", config.bind_addr);
    axum::serve(listener, app).await.expect("server error");
}
