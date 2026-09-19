//! Library face of the API: everything `main.rs` wires together, exposed so
//! integration tests (`tests/cucumber.rs`) can build the very same router
//! in-process instead of re-implementing it.
pub mod auth;
pub mod config;
pub mod db;
pub mod dto;
pub mod error;
pub mod routes;
pub mod services;
pub mod state;
