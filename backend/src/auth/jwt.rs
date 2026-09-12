use jsonwebtoken::jwk::JwkSet;
use jsonwebtoken::{Algorithm, DecodingKey, Validation, decode, decode_header};
use serde::{Deserialize, Serialize};
use std::time::{Duration, Instant};
use tokio::sync::RwLock;

use crate::error::{AppError, AppResult};

const JWKS_CACHE_TTL: Duration = Duration::from_secs(600);

#[derive(Debug, Deserialize)]
struct RawClaims {
    sub: String,
    preferred_username: Option<String>,
    #[serde(default)]
    realm_access: RealmAccess,
}

#[derive(Debug, Default, Deserialize)]
struct RealmAccess {
    #[serde(default)]
    roles: Vec<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct CurrentUser {
    pub sub: String,
    pub username: Option<String>,
    pub roles: Vec<String>,
}

impl CurrentUser {
    pub fn is_admin(&self) -> bool {
        self.roles.iter().any(|r| r == "admin")
    }
}

struct CachedJwks {
    fetched_at: Instant,
    keys: JwkSet,
}

/// Validates Keycloak-issued access tokens against the realm's JWKS,
/// re-fetching the key set only once the cache goes stale rather than on
/// every request.
///
/// `jwks_base_url` and `expected_issuer` are deliberately separate: in
/// Docker Compose the API reaches Keycloak over the internal network
/// (`http://keycloak:8080/...`) but the `iss` claim in every token is
/// whatever hostname the *browser* used to talk to Keycloak (e.g.
/// `http://localhost:8080/...`, from `KC_HOSTNAME`) — those two URLs are
/// not the same host, so fetching keys and validating `iss` cannot share
/// one field once the API runs in a container.
pub struct JwtValidator {
    jwks_base_url: String,
    expected_issuer: String,
    audience: String,
    http: reqwest::Client,
    cache: RwLock<Option<CachedJwks>>,
}

impl JwtValidator {
    pub fn new(jwks_base_url: String, expected_issuer: String, audience: String) -> Self {
        Self {
            jwks_base_url,
            expected_issuer,
            audience,
            http: reqwest::Client::new(),
            cache: RwLock::new(None),
        }
    }

    async fn jwks(&self) -> AppResult<JwkSet> {
        if let Some(cached) = self.cache.read().await.as_ref()
            && cached.fetched_at.elapsed() < JWKS_CACHE_TTL
        {
            return Ok(cached.keys.clone());
        }

        let url = format!("{}/protocol/openid-connect/certs", self.jwks_base_url);
        let keys: JwkSet = self
            .http
            .get(&url)
            .send()
            .await
            .map_err(|_| AppError::Unauthorized)?
            .json()
            .await
            .map_err(|_| AppError::Unauthorized)?;

        *self.cache.write().await = Some(CachedJwks {
            fetched_at: Instant::now(),
            keys: keys.clone(),
        });
        Ok(keys)
    }

    pub async fn validate(&self, token: &str) -> AppResult<CurrentUser> {
        let header = decode_header(token).map_err(|_| AppError::Unauthorized)?;
        let kid = header.kid.ok_or(AppError::Unauthorized)?;

        let jwks = self.jwks().await?;
        let jwk = jwks.find(&kid).ok_or(AppError::Unauthorized)?;
        let decoding_key = DecodingKey::from_jwk(jwk).map_err(|_| AppError::Unauthorized)?;

        let mut validation = Validation::new(Algorithm::RS256);
        validation.set_audience(&[&self.audience]);
        validation.set_issuer(&[&self.expected_issuer]);

        let data = decode::<RawClaims>(token, &decoding_key, &validation)
            .map_err(|_| AppError::Unauthorized)?;

        Ok(CurrentUser {
            sub: data.claims.sub,
            username: data.claims.preferred_username,
            roles: data.claims.realm_access.roles,
        })
    }
}
