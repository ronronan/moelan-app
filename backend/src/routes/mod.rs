pub mod consumable_types;
pub mod fine_types;
pub mod health;
pub mod me;
pub mod players;
pub mod transactions;

use axum::{
    Router,
    routing::{get, patch, post},
};

use crate::state::AppState;

pub fn build_router(state: AppState) -> Router {
    Router::new()
        .route("/health", get(health::health))
        .route("/api/me", get(me::me))
        .route(
            "/api/players",
            get(players::list_players).post(players::create_player),
        )
        .route(
            "/api/players/{id}",
            get(players::get_player).patch(players::patch_player),
        )
        .route(
            "/api/players/{id}/consumptions",
            post(transactions::create_consumption),
        )
        .route("/api/players/{id}/fines", post(transactions::create_fine))
        .route(
            "/api/players/{id}/credits",
            post(transactions::create_credit),
        )
        .route(
            "/api/players/{id}/adjustments",
            post(transactions::create_adjustment),
        )
        .route(
            "/api/players/{id}/transactions",
            get(transactions::list_player_transactions),
        )
        .route("/api/transactions", get(transactions::list_transactions))
        .route(
            "/api/consumable-types",
            get(consumable_types::list_consumable_types),
        )
        .route(
            "/api/consumable-types/{id}",
            patch(consumable_types::patch_consumable_type),
        )
        .route(
            "/api/fine-types",
            get(fine_types::list_fine_types).post(fine_types::create_fine_type),
        )
        .route(
            "/api/fine-types/{id}",
            patch(fine_types::patch_fine_type),
        )
        .with_state(state)
}
