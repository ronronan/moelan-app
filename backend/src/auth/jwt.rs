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
pub struct JwtValidator {
    issuer: String,
    audience: String,
    http: reqwest::Client,
    cache: RwLock<Option<CachedJwks>>,
}

impl JwtValidator {
    pub fn new(issuer: String, audience: String) -> Self {
        Self {
            issuer,
            audience,
            http: reqwest::Client::new(),
            cache: RwLock::new(None),
        }
    }

    async fn jwks(&self) -> AppResult<JwkSet> {
        if let Some(cached) = self.cache.read().await.as_ref() {
            if cached.fetched_at.elapsed() < JWKS_CACHE_TTL {
                return Ok(cached.keys.clone());
            }
        }

        let url = format!("{}/protocol/openid-connect/certs", self.issuer);
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
        validation.set_issuer(&[&self.issuer]);

        let data = decode::<RawClaims>(token, &decoding_key, &validation)
            .map_err(|_| AppError::Unauthorized)?;

        Ok(CurrentUser {
            sub: data.claims.sub,
            username: data.claims.preferred_username,
            roles: data.claims.realm_access.roles,
        })
    }
}
