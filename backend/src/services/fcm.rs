use std::time::{Duration, Instant};

use jsonwebtoken::{Algorithm, EncodingKey, Header, encode};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use tokio::sync::RwLock;
use uuid::Uuid;

use crate::config::Config;

/// M16 scaffolding (see the plan): FCM HTTP v1 push, sent to a player's own
/// device on every ledger action. Like `Mailer`, entirely optional —
/// `FIREBASE_PROJECT_ID`/`FIREBASE_SERVICE_ACCOUNT_JSON` unset means
/// "don't send push" rather than an error, since a Firebase project has to
/// be created by hand before any of this can actually work (see README).
pub struct FcmSender {
    http: reqwest::Client,
    project_id: Option<String>,
    service_account: Option<ServiceAccount>,
    cached_token: RwLock<Option<(String, Instant)>>,
}

#[derive(Debug, Deserialize)]
struct ServiceAccount {
    client_email: String,
    private_key: String,
    #[serde(default = "default_token_uri")]
    token_uri: String,
}

fn default_token_uri() -> String {
    "https://oauth2.googleapis.com/token".to_string()
}

#[derive(Serialize)]
struct AssertionClaims {
    iss: String,
    scope: String,
    aud: String,
    iat: i64,
    exp: i64,
}

#[derive(Deserialize)]
struct TokenResponse {
    access_token: String,
    expires_in: i64,
}

impl FcmSender {
    pub fn new(config: &Config) -> Self {
        // A malformed FIREBASE_SERVICE_ACCOUNT_JSON is treated the same as
        // "not configured" — the app still boots, push just stays disabled
        // (and every send attempt logs why).
        let service_account = config
            .firebase_service_account_json
            .as_ref()
            .and_then(|json| serde_json::from_str::<ServiceAccount>(json).ok());
        Self {
            http: reqwest::Client::new(),
            project_id: config.firebase_project_id.clone(),
            service_account,
            cached_token: RwLock::new(None),
        }
    }

    #[cfg(test)]
    pub fn disabled() -> Self {
        Self {
            http: reqwest::Client::new(),
            project_id: None,
            service_account: None,
            cached_token: RwLock::new(None),
        }
    }

    fn configured(&self) -> bool {
        self.project_id.is_some() && self.service_account.is_some()
    }

    /// Exchanges the service-account key for a short-lived OAuth2 access
    /// token via the JWT-bearer flow, caching it until shortly before
    /// expiry — the same shape as `KeycloakAdmin`'s token fetch, just
    /// cached since pushes fire far more often than space/invite actions.
    async fn access_token(&self) -> Option<String> {
        {
            let cached = self.cached_token.read().await;
            if let Some((token, expiry)) = cached.as_ref()
                && *expiry > Instant::now()
            {
                return Some(token.clone());
            }
        }

        let sa = self.service_account.as_ref()?;
        let now = chrono::Utc::now().timestamp();
        let claims = AssertionClaims {
            iss: sa.client_email.clone(),
            scope: "https://www.googleapis.com/auth/firebase.messaging".to_string(),
            aud: sa.token_uri.clone(),
            iat: now,
            exp: now + 3600,
        };
        let key = EncodingKey::from_rsa_pem(sa.private_key.as_bytes()).ok()?;
        let assertion = encode(&Header::new(Algorithm::RS256), &claims, &key).ok()?;

        let params = [
            ("grant_type", "urn:ietf:params:oauth:grant-type:jwt-bearer"),
            ("assertion", assertion.as_str()),
        ];
        let response = self
            .http
            .post(&sa.token_uri)
            .form(&params)
            .send()
            .await
            .ok()?;
        let token_response: TokenResponse = response.json().await.ok()?;

        let ttl = Duration::from_secs(token_response.expires_in.saturating_sub(60).max(0) as u64);
        *self.cached_token.write().await =
            Some((token_response.access_token.clone(), Instant::now() + ttl));
        Some(token_response.access_token)
    }

    /// Sends `title`/`body` to every device registered by the account that
    /// matches this player's email (an invited player, signed into their
    /// own read-only login — see `routes::device_tokens`). No-op, not an
    /// error, when Firebase isn't configured, the token exchange fails, or
    /// (the common case today) the player has no linked device.
    pub async fn notify_player(
        &self,
        pool: &PgPool,
        org_id: Uuid,
        player_id: Uuid,
        title: &str,
        body: &str,
    ) {
        if !self.configured() {
            return;
        }
        let Some(access_token) = self.access_token().await else {
            tracing::warn!("failed to obtain Firebase access token, push not sent");
            return;
        };
        let project_id = self
            .project_id
            .as_ref()
            .expect("configured() guarantees project_id is set");

        let tokens = sqlx::query_scalar!(
            r#"
            SELECT dt.token
            FROM device_tokens dt
            JOIN players p ON p.email = dt.email
            WHERE dt.organization_id = $1 AND p.id = $2
            "#,
            org_id,
            player_id,
        )
        .fetch_all(pool)
        .await
        .unwrap_or_default();

        let url = format!("https://fcm.googleapis.com/v1/projects/{project_id}/messages:send");
        for token in tokens {
            let payload = serde_json::json!({
                "message": {
                    "token": token,
                    "notification": { "title": title, "body": body },
                }
            });
            if let Err(err) = self
                .http
                .post(&url)
                .bearer_auth(&access_token)
                .json(&payload)
                .send()
                .await
            {
                tracing::warn!(%err, "failed to send push notification");
            }
        }
    }
}
