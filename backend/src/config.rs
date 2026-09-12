pub struct Config {
    pub database_url: String,
    pub bind_addr: String,
    pub keycloak_issuer_url: String,
    pub keycloak_jwks_url: String,
    pub keycloak_audience: String,
    pub keycloak_realm: String,
    /// Confidential client with a service account (`manage-users` +
    /// `manage-groups`) used only for Admin REST API calls (creating
    /// per-space groups, inviting player accounts). Reached over the same
    /// internal host as `keycloak_jwks_url`.
    pub keycloak_service_client_id: String,
    pub keycloak_service_client_secret: String,
}

impl Config {
    pub fn from_env() -> Self {
        let keycloak_issuer_url =
            std::env::var("KEYCLOAK_ISSUER_URL").expect("KEYCLOAK_ISSUER_URL must be set");
        // Only needs to differ from KEYCLOAK_ISSUER_URL when the API can't
        // reach Keycloak at the hostname browsers use for it — e.g. Docker
        // Compose, where KEYCLOAK_ISSUER_URL matches the `iss` claim
        // (KC_HOSTNAME) but the API must reach Keycloak via the internal
        // service name instead, for both JWKS fetches and Admin API calls.
        let keycloak_jwks_url =
            std::env::var("KEYCLOAK_JWKS_URL").unwrap_or_else(|_| keycloak_issuer_url.clone());
        Self {
            database_url: std::env::var("DATABASE_URL").expect("DATABASE_URL must be set"),
            bind_addr: std::env::var("BIND_ADDR").unwrap_or_else(|_| "0.0.0.0:8000".to_string()),
            keycloak_issuer_url,
            keycloak_jwks_url,
            keycloak_audience: std::env::var("KEYCLOAK_AUDIENCE")
                .unwrap_or_else(|_| "moelan-api".to_string()),
            keycloak_realm: std::env::var("KEYCLOAK_REALM")
                .unwrap_or_else(|_| "moelan".to_string()),
            keycloak_service_client_id: std::env::var("KEYCLOAK_SERVICE_CLIENT_ID")
                .unwrap_or_else(|_| "moelan-api-service".to_string()),
            keycloak_service_client_secret: std::env::var("KEYCLOAK_SERVICE_CLIENT_SECRET")
                .unwrap_or_default(),
        }
    }
}
