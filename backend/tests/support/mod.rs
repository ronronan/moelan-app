//! Test harness shared by the Cucumber steps.
//!
//! Two things stand between the Gherkin scenarios and the real API: Keycloak
//! (which issues the tokens and owns the groups/users) and Postgres. Only the
//! first is faked. `KeycloakStub` is an in-process HTTP server that speaks the
//! handful of Keycloak endpoints this app calls — its JWKS endpoint and the
//! slice of the Admin REST API `services::keycloak_admin` uses — so scenarios
//! can mint a token for any role without a container, while the router, the
//! JWT validation, the extractors, the SQL and the ledger invariants all run
//! for real against a real database.

use std::collections::HashMap;
use std::sync::{Arc, Mutex};

use axum::Router;
use axum::extract::{Path, State};
use axum::http::StatusCode;
use axum::response::IntoResponse;
use axum::routing::{delete, get, post, put};
use jsonwebtoken::{Algorithm, EncodingKey, Header, encode};
use serde::Serialize;
use serde_json::{Value, json};
use uuid::Uuid;

/// Matches the `kid` of `fixtures/test-jwks.json`, which the stub serves —
/// `JwtValidator` looks a token's `kid` up in that key set.
const TEST_KID: &str = "moelan-test-key";
pub const REALM: &str = "moelan";
pub const AUDIENCE: &str = "moelan-api";

// ---------------------------------------------------------------------------
// Keycloak stub
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Serialize)]
pub struct StubUser {
    pub id: String,
    pub username: String,
    pub email: Option<String>,
    #[serde(rename = "firstName")]
    pub first_name: Option<String>,
    #[serde(rename = "lastName")]
    pub last_name: Option<String>,
    pub enabled: bool,
    /// Group *paths* (`/org-<uuid>/admin`), the same shape Keycloak reports.
    #[serde(skip)]
    pub groups: Vec<String>,
    #[serde(skip)]
    pub realm_roles: Vec<String>,
}

#[derive(Default)]
pub struct StubState {
    /// group id -> full path (`/org-<uuid>/admin`)
    groups: HashMap<String, String>,
    users: Vec<StubUser>,
    /// Emails passed to `execute-actions-email`, i.e. invites actually sent.
    pub invite_emails: Vec<String>,
}

impl StubState {
    fn group_id_for_path(&self, path: &str) -> Option<String> {
        let wanted = format!("/{}", path.trim_start_matches('/'));
        self.groups
            .iter()
            .find(|(_, p)| **p == wanted)
            .map(|(id, _)| id.clone())
    }
}

#[derive(Clone)]
pub struct KeycloakStub {
    pub base_url: String,
    pub state: Arc<Mutex<StubState>>,
}

impl KeycloakStub {
    /// Binds on an ephemeral port and serves until the process exits — one
    /// stub for the whole run, reset between scenarios by `reset()`.
    pub async fn start() -> Self {
        let state = Arc::new(Mutex::new(StubState::default()));
        let app = stub_router(state.clone());
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0")
            .await
            .expect("failed to bind the Keycloak stub");
        let addr = listener.local_addr().unwrap();
        tokio::spawn(async move {
            axum::serve(listener, app).await.expect("stub server error");
        });
        KeycloakStub {
            base_url: format!("http://{addr}"),
            state,
        }
    }

    /// The realm base URL, which is what both `JwtValidator` (JWKS) and
    /// `KeycloakAdmin` (which derives the admin base from it) are given.
    pub fn realm_url(&self) -> String {
        format!("{}/realms/{REALM}", self.base_url)
    }

    pub fn reset(&self) {
        let mut state = self.state.lock().unwrap();
        state.groups.clear();
        state.users.clear();
        state.invite_emails.clear();
    }

    /// Registers an account the way Keycloak's own registration would —
    /// scenarios use this for the people who already exist before the story
    /// starts (a super-admin, a club's admin, an invited player).
    pub fn add_user(&self, user: StubUser) {
        self.state.lock().unwrap().users.push(user);
    }

    pub fn group_exists(&self, path: &str) -> bool {
        self.state.lock().unwrap().group_id_for_path(path).is_some()
    }

    pub fn invite_emails(&self) -> Vec<String> {
        self.state.lock().unwrap().invite_emails.clone()
    }
}

fn stub_router(state: Arc<Mutex<StubState>>) -> Router {
    let realm = format!("/realms/{REALM}");
    let admin = format!("/admin/realms/{REALM}");
    Router::new()
        .route(
            &format!("{realm}/protocol/openid-connect/certs"),
            get(certs),
        )
        .route(
            &format!("{realm}/protocol/openid-connect/token"),
            post(token),
        )
        .route(&format!("{admin}/roles/{{name}}"), get(realm_role))
        .route(&format!("{admin}/groups"), post(create_group))
        .route(&format!("{admin}/groups/{{id}}"), delete(delete_group))
        .route(
            &format!("{admin}/groups/{{id}}/children"),
            post(create_child),
        )
        .route(
            &format!("{admin}/groups/{{id}}/role-mappings/realm"),
            post(no_content),
        )
        .route(
            &format!("{admin}/group-by-path/{{*path}}"),
            get(group_by_path),
        )
        .route(&format!("{admin}/users"), post(create_user).get(list_users))
        .route(
            &format!("{admin}/users/{{id}}/groups/{{group_id}}"),
            put(add_to_group),
        )
        .route(&format!("{admin}/users/{{id}}/groups"), get(user_groups))
        .route(
            &format!("{admin}/users/{{id}}/role-mappings/realm/composite"),
            get(user_roles),
        )
        .route(
            &format!("{admin}/users/{{id}}/execute-actions-email"),
            put(execute_actions_email),
        )
        .with_state(state)
}

async fn certs() -> impl IntoResponse {
    (
        [(axum::http::header::CONTENT_TYPE, "application/json")],
        include_str!("../fixtures/test-jwks.json"),
    )
}

async fn token() -> impl IntoResponse {
    axum::Json(json!({ "access_token": "stub-admin-token", "expires_in": 60 }))
}

async fn realm_role(Path(name): Path<String>) -> impl IntoResponse {
    // The realm export defines exactly these three; anything else is a bug in
    // the code under test, so the stub 404s rather than inventing a role.
    if ["admin", "member", "player"].contains(&name.as_str()) {
        axum::Json(json!({ "id": Uuid::new_v4().to_string(), "name": name })).into_response()
    } else {
        StatusCode::NOT_FOUND.into_response()
    }
}

fn created_at(location: String) -> axum::response::Response {
    (StatusCode::CREATED, [("location", location)]).into_response()
}

async fn create_group(
    State(state): State<Arc<Mutex<StubState>>>,
    axum::Json(body): axum::Json<Value>,
) -> impl IntoResponse {
    let name = body["name"].as_str().unwrap_or_default().to_string();
    let id = Uuid::new_v4().to_string();
    state
        .lock()
        .unwrap()
        .groups
        .insert(id.clone(), format!("/{name}"));
    created_at(format!("/admin/realms/{REALM}/groups/{id}"))
}

async fn create_child(
    State(state): State<Arc<Mutex<StubState>>>,
    Path(parent_id): Path<String>,
    axum::Json(body): axum::Json<Value>,
) -> impl IntoResponse {
    let name = body["name"].as_str().unwrap_or_default().to_string();
    let mut guard = state.lock().unwrap();
    let Some(parent_path) = guard.groups.get(&parent_id).cloned() else {
        return StatusCode::NOT_FOUND.into_response();
    };
    let id = Uuid::new_v4().to_string();
    guard
        .groups
        .insert(id.clone(), format!("{parent_path}/{name}"));
    created_at(format!("/admin/realms/{REALM}/groups/{id}"))
}

/// Deleting a group takes its subgroups with it, exactly as Keycloak does —
/// which is the whole reason `delete_org_groups` only deletes the parent.
async fn delete_group(
    State(state): State<Arc<Mutex<StubState>>>,
    Path(id): Path<String>,
) -> impl IntoResponse {
    let mut guard = state.lock().unwrap();
    let Some(path) = guard.groups.get(&id).cloned() else {
        return StatusCode::NOT_FOUND;
    };
    let prefix = format!("{path}/");
    guard
        .groups
        .retain(|_, p| *p != path && !p.starts_with(&prefix));
    for user in &mut guard.users {
        user.groups
            .retain(|g| *g != path && !g.starts_with(&prefix));
    }
    StatusCode::NO_CONTENT
}

async fn group_by_path(
    State(state): State<Arc<Mutex<StubState>>>,
    Path(path): Path<String>,
) -> impl IntoResponse {
    match state.lock().unwrap().group_id_for_path(&path) {
        Some(id) => axum::Json(json!({ "id": id, "path": format!("/{path}") })).into_response(),
        None => StatusCode::NOT_FOUND.into_response(),
    }
}

async fn no_content() -> StatusCode {
    StatusCode::NO_CONTENT
}

async fn create_user(
    State(state): State<Arc<Mutex<StubState>>>,
    axum::Json(body): axum::Json<Value>,
) -> impl IntoResponse {
    let id = Uuid::new_v4().to_string();
    state.lock().unwrap().users.push(StubUser {
        id: id.clone(),
        username: body["username"].as_str().unwrap_or_default().to_string(),
        email: body["email"].as_str().map(str::to_string),
        first_name: body["firstName"].as_str().map(str::to_string),
        last_name: body["lastName"].as_str().map(str::to_string),
        enabled: body["enabled"].as_bool().unwrap_or(true),
        groups: Vec::new(),
        realm_roles: Vec::new(),
    });
    created_at(format!("/admin/realms/{REALM}/users/{id}"))
}

async fn list_users(State(state): State<Arc<Mutex<StubState>>>) -> impl IntoResponse {
    axum::Json(state.lock().unwrap().users.clone())
}

async fn add_to_group(
    State(state): State<Arc<Mutex<StubState>>>,
    Path((id, group_id)): Path<(String, String)>,
) -> impl IntoResponse {
    let mut guard = state.lock().unwrap();
    let Some(path) = guard.groups.get(&group_id).cloned() else {
        return StatusCode::NOT_FOUND;
    };
    // A group carries a realm role in the real realm (see
    // `create_org_groups`); the stub mirrors that so the listing's role
    // column is exercised, not just its group column.
    let role = path.rsplit('/').next().unwrap_or_default().to_string();
    match guard.users.iter_mut().find(|u| u.id == id) {
        Some(user) => {
            user.groups.push(path);
            if !user.realm_roles.contains(&role) {
                user.realm_roles.push(role);
            }
            StatusCode::NO_CONTENT
        }
        None => StatusCode::NOT_FOUND,
    }
}

async fn user_groups(
    State(state): State<Arc<Mutex<StubState>>>,
    Path(id): Path<String>,
) -> impl IntoResponse {
    let guard = state.lock().unwrap();
    let paths: Vec<Value> = guard
        .users
        .iter()
        .find(|u| u.id == id)
        .map(|u| u.groups.iter().map(|p| json!({ "path": p })).collect())
        .unwrap_or_default();
    axum::Json(paths)
}

async fn user_roles(
    State(state): State<Arc<Mutex<StubState>>>,
    Path(id): Path<String>,
) -> impl IntoResponse {
    let guard = state.lock().unwrap();
    let roles: Vec<Value> = guard
        .users
        .iter()
        .find(|u| u.id == id)
        .map(|u| {
            u.realm_roles
                .iter()
                .map(|r| json!({ "id": Uuid::new_v4().to_string(), "name": r }))
                .collect()
        })
        .unwrap_or_default();
    axum::Json(roles)
}

async fn execute_actions_email(
    State(state): State<Arc<Mutex<StubState>>>,
    Path(id): Path<String>,
) -> impl IntoResponse {
    let mut guard = state.lock().unwrap();
    if let Some(email) = guard
        .users
        .iter()
        .find(|u| u.id == id)
        .and_then(|u| u.email.clone())
    {
        guard.invite_emails.push(email);
    }
    StatusCode::NO_CONTENT
}

// ---------------------------------------------------------------------------
// Token minting
// ---------------------------------------------------------------------------

/// The signed-in account a scenario acts as. Mirrors exactly what Keycloak
/// puts in an access token: realm roles on one side, `/org-<uuid>/<role>`
/// group membership on the other.
#[derive(Debug, Clone)]
pub struct Actor {
    pub sub: String,
    pub username: String,
    pub realm_roles: Vec<String>,
    pub groups: Vec<String>,
}

#[derive(Serialize)]
struct TestClaims {
    sub: String,
    preferred_username: String,
    iss: String,
    aud: String,
    exp: i64,
    iat: i64,
    realm_access: RealmAccess,
    groups: Vec<String>,
}

#[derive(Serialize)]
struct RealmAccess {
    roles: Vec<String>,
}

/// Signs a token with the fixture key the stub publishes — valid for real as
/// far as `JwtValidator` is concerned (right issuer, audience, signature and
/// `kid`), so nothing in the auth path is bypassed by the tests.
pub fn mint_token(actor: &Actor, issuer: &str) -> String {
    let now = chrono::Utc::now().timestamp();
    let claims = TestClaims {
        sub: actor.sub.clone(),
        preferred_username: actor.username.clone(),
        iss: issuer.to_string(),
        aud: AUDIENCE.to_string(),
        iat: now,
        exp: now + 3600,
        realm_access: RealmAccess {
            roles: actor.realm_roles.clone(),
        },
        groups: actor.groups.clone(),
    };
    let mut header = Header::new(Algorithm::RS256);
    header.kid = Some(TEST_KID.to_string());
    let key = EncodingKey::from_rsa_pem(include_bytes!("../fixtures/test-jwt-key.pem"))
        .expect("the test RSA key fixture must be a valid PEM");
    encode(&header, &claims, &key).expect("failed to sign the test token")
}

/// A token that is well-formed but signed with the wrong key — used by the
/// scenarios that assert an invalid token is rejected.
pub fn mint_forged_token(actor: &Actor, issuer: &str) -> String {
    let token = mint_token(actor, issuer);
    let (rest, signature) = token.rsplit_once('.').unwrap();
    // Flip the signature, keeping it base64url-shaped.
    let tampered: String = signature
        .chars()
        .map(|c| if c == 'a' { 'b' } else { 'a' })
        .collect();
    format!("{rest}.{tampered}")
}
