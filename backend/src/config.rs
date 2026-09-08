pub struct Config {
    pub database_url: String,
    pub bind_addr: String,
    pub keycloak_issuer_url: String,
    pub keycloak_audience: String,
}

impl Config {
    pub fn from_env() -> Self {
        Self {
            database_url: std::env::var("DATABASE_URL").expect("DATABASE_URL must be set"),
            bind_addr: std::env::var("BIND_ADDR").unwrap_or_else(|_| "0.0.0.0:8000".to_string()),
            keycloak_issuer_url: std::env::var("KEYCLOAK_ISSUER_URL")
                .expect("KEYCLOAK_ISSUER_URL must be set"),
            keycloak_audience: std::env::var("KEYCLOAK_AUDIENCE")
                .unwrap_or_else(|_| "moelan-api".to_string()),
        }
    }
}
