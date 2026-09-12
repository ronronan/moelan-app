pub struct Config {
    pub database_url: String,
    pub bind_addr: String,
    pub keycloak_issuer_url: String,
    pub keycloak_jwks_url: String,
    pub keycloak_audience: String,
}

impl Config {
    pub fn from_env() -> Self {
        let keycloak_issuer_url =
            std::env::var("KEYCLOAK_ISSUER_URL").expect("KEYCLOAK_ISSUER_URL must be set");
        Self {
            database_url: std::env::var("DATABASE_URL").expect("DATABASE_URL must be set"),
            bind_addr: std::env::var("BIND_ADDR").unwrap_or_else(|_| "0.0.0.0:8000".to_string()),
            // Only needs to differ from KEYCLOAK_ISSUER_URL when the API
            // can't reach Keycloak at the hostname browsers use for it —
            // e.g. Docker Compose, where KEYCLOAK_ISSUER_URL matches the
            // `iss` claim (KC_HOSTNAME) but the API must fetch keys via
            // the internal service name instead.
            keycloak_jwks_url: std::env::var("KEYCLOAK_JWKS_URL")
                .unwrap_or_else(|_| keycloak_issuer_url.clone()),
            keycloak_issuer_url,
            keycloak_audience: std::env::var("KEYCLOAK_AUDIENCE")
                .unwrap_or_else(|_| "moelan-api".to_string()),
        }
    }
}
