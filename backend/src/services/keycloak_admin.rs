use serde::Deserialize;
use serde_json::json;
use uuid::Uuid;

use crate::config::Config;
use crate::error::{AppError, AppResult};

/// Thin wrapper around the pieces of Keycloak's Admin REST API this app
/// needs: creating the three role-groups for a brand-new space and
/// attaching users to them. Every call here is a fresh client-credentials
/// grant — call volume is "once per space creation" or "once per player
/// invite", far too low to justify a token cache like `JwtValidator`'s.
pub struct KeycloakAdmin {
    http: reqwest::Client,
    token_url: String,
    admin_base_url: String,
    client_id: String,
    client_secret: String,
}

#[derive(Deserialize)]
struct TokenResponse {
    access_token: String,
}

#[derive(Deserialize)]
struct KeycloakRole {
    id: String,
    name: String,
}

#[derive(Deserialize)]
struct KeycloakGroup {
    id: String,
}

impl KeycloakAdmin {
    pub fn new(config: &Config) -> Self {
        // `keycloak_jwks_url` is already the internally-reachable realm base
        // (e.g. `http://keycloak:8080/realms/moelan`), the same host the
        // Admin API lives behind.
        let realm_base = config.keycloak_jwks_url.trim_end_matches('/').to_string();
        let host_base = realm_base
            .rsplit_once("/realms/")
            .map(|(host, _)| host.to_string())
            .unwrap_or_else(|| realm_base.clone());
        Self {
            http: reqwest::Client::new(),
            token_url: format!("{realm_base}/protocol/openid-connect/token"),
            admin_base_url: format!("{host_base}/admin/realms/{}", config.keycloak_realm),
            client_id: config.keycloak_service_client_id.clone(),
            client_secret: config.keycloak_service_client_secret.clone(),
        }
    }

    async fn admin_token(&self) -> AppResult<String> {
        let params = [
            ("grant_type", "client_credentials"),
            ("client_id", self.client_id.as_str()),
            ("client_secret", self.client_secret.as_str()),
        ];
        let resp = self
            .http
            .post(&self.token_url)
            .form(&params)
            .send()
            .await
            .map_err(|e| AppError::Internal(format!("keycloak token request failed: {e}")))?;
        if !resp.status().is_success() {
            let status = resp.status();
            let body = resp.text().await.unwrap_or_default();
            return Err(AppError::Internal(format!(
                "keycloak token request returned {status}: {body}"
            )));
        }
        let token: TokenResponse = resp
            .json()
            .await
            .map_err(|e| AppError::Internal(format!("keycloak token response: {e}")))?;
        Ok(token.access_token)
    }

    async fn realm_role(&self, token: &str, role_name: &str) -> AppResult<KeycloakRole> {
        let resp = self
            .http
            .get(format!("{}/roles/{role_name}", self.admin_base_url))
            .bearer_auth(token)
            .send()
            .await
            .map_err(|e| AppError::Internal(format!("keycloak role lookup failed: {e}")))?;
        if !resp.status().is_success() {
            return Err(AppError::Internal(format!(
                "keycloak realm role '{role_name}' not found — has the realm been set up with the org roles?"
            )));
        }
        resp.json()
            .await
            .map_err(|e| AppError::Internal(format!("keycloak role response: {e}")))
    }

    async fn create_group(
        &self,
        token: &str,
        parent_path: Option<&str>,
        name: &str,
    ) -> AppResult<String> {
        let create_url = match parent_path {
            None => format!("{}/groups", self.admin_base_url),
            Some(parent_id) => format!("{}/groups/{parent_id}/children", self.admin_base_url),
        };
        let resp = self
            .http
            .post(&create_url)
            .bearer_auth(token)
            .json(&json!({ "name": name }))
            .send()
            .await
            .map_err(|e| AppError::Internal(format!("keycloak create group failed: {e}")))?;
        if !resp.status().is_success() {
            let status = resp.status();
            let body = resp.text().await.unwrap_or_default();
            return Err(AppError::Internal(format!(
                "keycloak create group '{name}' returned {status}: {body}"
            )));
        }
        // Keycloak's group-create returns 201 with a Location header, not a
        // body — fetch the id back out of it.
        let location = resp
            .headers()
            .get("location")
            .and_then(|v| v.to_str().ok())
            .ok_or_else(|| {
                AppError::Internal("keycloak create group: no Location header".into())
            })?;
        let id = location.rsplit('/').next().ok_or_else(|| {
            AppError::Internal("keycloak create group: malformed Location".into())
        })?;
        Ok(id.to_string())
    }

    async fn map_realm_role_to_group(
        &self,
        token: &str,
        group_id: &str,
        role: &KeycloakRole,
    ) -> AppResult<()> {
        let resp = self
            .http
            .post(format!(
                "{}/groups/{group_id}/role-mappings/realm",
                self.admin_base_url
            ))
            .bearer_auth(token)
            .json(&json!([{ "id": role.id, "name": role.name }]))
            .send()
            .await
            .map_err(|e| AppError::Internal(format!("keycloak role mapping failed: {e}")))?;
        if !resp.status().is_success() {
            let status = resp.status();
            let body = resp.text().await.unwrap_or_default();
            return Err(AppError::Internal(format!(
                "keycloak role mapping returned {status}: {body}"
            )));
        }
        Ok(())
    }

    /// Creates `/org-<id>` with `admin`/`member`/`player` subgroups, each
    /// mapped to the matching realm role. Returns the Keycloak group id of
    /// the `admin` subgroup, since the caller (space creation) immediately
    /// adds the creating user to it.
    pub async fn create_org_groups(&self, org_id: Uuid) -> AppResult<OrgGroupIds> {
        let token = self.admin_token().await?;
        let parent_id = self
            .create_group(&token, None, &format!("org-{org_id}"))
            .await?;

        let admin_role = self.realm_role(&token, "admin").await?;
        let member_role = self.realm_role(&token, "member").await?;
        let player_role = self.realm_role(&token, "player").await?;

        let admin_group = self.create_group(&token, Some(&parent_id), "admin").await?;
        self.map_realm_role_to_group(&token, &admin_group, &admin_role)
            .await?;
        let member_group = self
            .create_group(&token, Some(&parent_id), "member")
            .await?;
        self.map_realm_role_to_group(&token, &member_group, &member_role)
            .await?;
        let player_group = self
            .create_group(&token, Some(&parent_id), "player")
            .await?;
        self.map_realm_role_to_group(&token, &player_group, &player_role)
            .await?;

        Ok(OrgGroupIds {
            admin_group_id: admin_group,
        })
    }

    /// Resolves a `/org-<id>/<role>` path to its Keycloak group id, for
    /// callers (like a player invite) that only have the org's UUID, not
    /// the group ids `create_org_groups` returned at creation time.
    pub async fn find_group_id(&self, org_id: Uuid, role: &str) -> AppResult<String> {
        let token = self.admin_token().await?;
        let path = format!("org-{org_id}/{role}");
        let resp = self
            .http
            .get(format!("{}/group-by-path/{path}", self.admin_base_url))
            .bearer_auth(token)
            .send()
            .await
            .map_err(|e| AppError::Internal(format!("keycloak group-by-path failed: {e}")))?;
        if !resp.status().is_success() {
            return Err(AppError::Internal(format!(
                "keycloak group '{path}' not found"
            )));
        }
        let group: KeycloakGroup = resp
            .json()
            .await
            .map_err(|e| AppError::Internal(format!("keycloak group-by-path response: {e}")))?;
        Ok(group.id)
    }

    /// Looks up a Keycloak user by its `sub` (== Keycloak user id) and adds
    /// it to the given group.
    pub async fn add_user_to_group(&self, user_sub: &str, group_id: &str) -> AppResult<()> {
        let token = self.admin_token().await?;
        let resp = self
            .http
            .put(format!(
                "{}/users/{user_sub}/groups/{group_id}",
                self.admin_base_url
            ))
            .bearer_auth(token)
            .send()
            .await
            .map_err(|e| AppError::Internal(format!("keycloak add-to-group failed: {e}")))?;
        if !resp.status().is_success() {
            let status = resp.status();
            let body = resp.text().await.unwrap_or_default();
            return Err(AppError::Internal(format!(
                "keycloak add-to-group returned {status}: {body}"
            )));
        }
        Ok(())
    }

    /// Creates a Keycloak account for an invited player: email as username,
    /// no password set, `UPDATE_PASSWORD` required action so Keycloak's own
    /// (realm-configured SMTP) "set up account" email carries the invite.
    /// Returns the new user's Keycloak id (== JWT `sub`).
    pub async fn create_user_with_temp_password(
        &self,
        email: &str,
        first_name: &str,
        last_name: &str,
        player_group_id: &str,
    ) -> AppResult<String> {
        let token = self.admin_token().await?;
        let resp = self
            .http
            .post(format!("{}/users", self.admin_base_url))
            .bearer_auth(&token)
            .json(&json!({
                "username": email,
                "email": email,
                "firstName": first_name,
                "lastName": last_name,
                "enabled": true,
                "emailVerified": false,
                "requiredActions": ["UPDATE_PASSWORD"],
                "groups": [],
            }))
            .send()
            .await
            .map_err(|e| AppError::Internal(format!("keycloak create user failed: {e}")))?;
        if !resp.status().is_success() {
            let status = resp.status();
            let body = resp.text().await.unwrap_or_default();
            return Err(AppError::Internal(format!(
                "keycloak create user returned {status}: {body}"
            )));
        }
        let location = resp
            .headers()
            .get("location")
            .and_then(|v| v.to_str().ok())
            .ok_or_else(|| AppError::Internal("keycloak create user: no Location header".into()))?;
        let user_id = location
            .rsplit('/')
            .next()
            .ok_or_else(|| AppError::Internal("keycloak create user: malformed Location".into()))?
            .to_string();

        self.add_user_to_group(&user_id, player_group_id).await?;

        // Triggers Keycloak's own "update account" email via the realm's
        // configured SMTP settings — a no-op with a 500 from Keycloak if
        // that SMTP hasn't been configured yet, which we surface as-is
        // rather than silently swallowing (the account still exists; the
        // admin can resend from the Keycloak console).
        let resp = self
            .http
            .put(format!(
                "{}/users/{user_id}/execute-actions-email",
                self.admin_base_url
            ))
            .bearer_auth(&token)
            .json(&json!(["UPDATE_PASSWORD"]))
            .send()
            .await
            .map_err(|e| AppError::Internal(format!("keycloak invite email failed: {e}")))?;
        if !resp.status().is_success() {
            let status = resp.status();
            let body = resp.text().await.unwrap_or_default();
            tracing::warn!(
                %status,
                %body,
                "keycloak account created but invite email failed to send (realm SMTP likely unconfigured)"
            );
        }

        Ok(user_id)
    }
}

pub struct OrgGroupIds {
    pub admin_group_id: String,
}
