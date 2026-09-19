//! Executable specification: runs every `.feature` file under `spec/features`
//! against the real router, the real extractors and a real Postgres, with only
//! Keycloak faked (see `support::KeycloakStub`).
//!
//! ```bash
//! DATABASE_URL=postgres://moelan:changeme@localhost:5432/app cargo test --test cucumber
//! ```
//!
//! Scenarios run one at a time: they share the Keycloak stub's in-memory realm,
//! which each scenario resets so its "given" accounts are the only ones the
//! user-listing sees.

mod support;

use std::collections::HashMap;

use axum::body::Body;
use axum::http::{Request, StatusCode, header};
use cucumber::{World, given, then, when};
use http_body_util::BodyExt;
use serde_json::{Value, json};
use sqlx::PgPool;
use tokio::sync::OnceCell;
use tower::ServiceExt;
use uuid::Uuid;

use moelan_api::config::Config;
use moelan_api::routes;
use moelan_api::services::fcm::FcmSender;
use moelan_api::services::keycloak_admin::KeycloakAdmin;
use moelan_api::services::mail::Mailer;
use moelan_api::services::transactions::{self as tx_service, Notifiers};
use moelan_api::state::AppState;

use support::{Actor, KeycloakStub, mint_forged_token, mint_token};

// ---------------------------------------------------------------------------
// Shared infrastructure (one Postgres pool + one Keycloak stub for the run)
// ---------------------------------------------------------------------------

struct Infra {
    state: AppState,
    stub: KeycloakStub,
    issuer: String,
}

static INFRA: OnceCell<Infra> = OnceCell::const_new();

async fn infra() -> &'static Infra {
    INFRA
        .get_or_init(|| async {
            let database_url = std::env::var("DATABASE_URL")
                .expect("DATABASE_URL must point at a migrated Postgres to run the Cucumber suite");
            let pool = PgPool::connect(&database_url)
                .await
                .expect("failed to connect to the test database");

            let stub = KeycloakStub::start().await;
            let issuer = stub.realm_url();

            // The only fake here: Keycloak's address. Everything else — JWT
            // validation, audience/issuer checks, the group→role mapping — is
            // the production code path.
            let config = Config {
                database_url: database_url.clone(),
                bind_addr: "127.0.0.1:0".into(),
                keycloak_issuer_url: issuer.clone(),
                keycloak_jwks_url: issuer.clone(),
                keycloak_audience: support::AUDIENCE.into(),
                keycloak_realm: support::REALM.into(),
                keycloak_service_client_id: "moelan-api-service".into(),
                keycloak_service_client_secret: "test-secret".into(),
                smtp_host: None,
                smtp_port: 587,
                smtp_username: String::new(),
                smtp_password: String::new(),
                smtp_from: String::new(),
                firebase_project_id: None,
                firebase_service_account_json: None,
            };

            let state = AppState {
                pool,
                jwt: std::sync::Arc::new(moelan_api::auth::JwtValidator::new(
                    issuer.clone(),
                    issuer.clone(),
                    support::AUDIENCE.into(),
                )),
                keycloak_admin: std::sync::Arc::new(KeycloakAdmin::new(&config)),
                mailer: std::sync::Arc::new(Mailer::disabled()),
                fcm: std::sync::Arc::new(FcmSender::disabled()),
            };

            Infra {
                state,
                stub,
                issuer,
            }
        })
        .await
}

/// Wipes everything previous scenarios created, so assertions on *global*
/// listings (the pending-space queue, the user roster) see this scenario's
/// data and nothing else. Only touches rows stamped `created_by = 'cucumber'`
/// by `seed_org`, so a developer's own data in the same database survives.
async fn purge_test_data(pool: &PgPool) {
    sqlx::query!(
        r#"
        WITH test_orgs AS (SELECT id FROM organizations WHERE created_by = 'cucumber'),
             a AS (DELETE FROM device_tokens WHERE organization_id IN (SELECT id FROM test_orgs)),
             b AS (DELETE FROM transactions WHERE organization_id IN (SELECT id FROM test_orgs)),
             c AS (DELETE FROM players WHERE organization_id IN (SELECT id FROM test_orgs)),
             d AS (DELETE FROM consumable_types WHERE organization_id IN (SELECT id FROM test_orgs)),
             e AS (DELETE FROM fine_types WHERE organization_id IN (SELECT id FROM test_orgs))
        DELETE FROM organizations WHERE id IN (SELECT id FROM test_orgs)
        "#
    )
    .execute(pool)
    .await
    .expect("failed to purge the previous scenario's data");
}

// ---------------------------------------------------------------------------
// World
// ---------------------------------------------------------------------------

#[derive(World)]
#[world(init = Self::new)]
struct MoelanWorld {
    state: AppState,
    stub: KeycloakStub,
    issuer: String,
    /// The signed-in account, or `None` for an anonymous caller.
    actor: Option<Actor>,
    /// Set when a scenario deliberately sends a broken token.
    token_override: Option<String>,
    /// Space name (as written in the feature) -> its row id.
    orgs: HashMap<String, Uuid>,
    /// "Prénom Nom" -> player row id.
    players: HashMap<String, Uuid>,
    status: Option<StatusCode>,
    body: Option<Value>,
}

impl std::fmt::Debug for MoelanWorld {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("MoelanWorld")
            .field("actor", &self.actor)
            .field("orgs", &self.orgs)
            .field("players", &self.players)
            .field("status", &self.status)
            .field("body", &self.body)
            .finish()
    }
}

impl MoelanWorld {
    async fn new() -> Result<Self, std::convert::Infallible> {
        let infra = infra().await;
        infra.stub.reset();
        purge_test_data(&infra.state.pool).await;
        Ok(MoelanWorld {
            state: infra.state.clone(),
            stub: infra.stub.clone(),
            issuer: infra.issuer.clone(),
            actor: None,
            token_override: None,
            orgs: HashMap::new(),
            players: HashMap::new(),
            status: None,
            body: None,
        })
    }

    fn pool(&self) -> &PgPool {
        &self.state.pool
    }

    /// The space the current request will be filtered by: the signed-in
    /// account's, when there is one. Falls back to "the only space around"
    /// for the steps a scenario runs before logging in.
    fn acting_org(&self) -> Uuid {
        if let Some(actor) = &self.actor {
            for group in &actor.groups {
                if let Some(rest) = group.trim_start_matches('/').strip_prefix("org-")
                    && let Some((id, _)) = rest.split_once('/')
                    && let Ok(id) = Uuid::parse_str(id)
                {
                    return id;
                }
            }
        }
        self.only_org()
    }

    fn org_id(&self, name: &str) -> Uuid {
        *self
            .orgs
            .get(name)
            .unwrap_or_else(|| panic!("no space named « {name} » in this scenario"))
    }

    fn player_id(&self, name: &str) -> Uuid {
        *self
            .players
            .get(name)
            .unwrap_or_else(|| panic!("no player named « {name} » in this scenario"))
    }

    /// The single space a scenario works in — most features only ever have
    /// one, so steps that don't name it use this.
    fn only_org(&self) -> Uuid {
        assert_eq!(
            self.orgs.len(),
            1,
            "this step needs exactly one space in the scenario; name it explicitly instead"
        );
        *self.orgs.values().next().unwrap()
    }

    fn bearer(&self) -> Option<String> {
        if let Some(token) = &self.token_override {
            return Some(token.clone());
        }
        self.actor
            .as_ref()
            .map(|actor| mint_token(actor, &self.issuer))
    }

    async fn call(&mut self, method: &str, path: &str, body: Option<Value>) {
        let mut builder = Request::builder().method(method).uri(path);
        if let Some(token) = self.bearer() {
            builder = builder.header(header::AUTHORIZATION, format!("Bearer {token}"));
        }
        let request = match body {
            Some(body) => builder
                .header(header::CONTENT_TYPE, "application/json")
                .body(Body::from(body.to_string())),
            None => builder.body(Body::empty()),
        }
        .expect("failed to build the test request");

        let response = routes::build_router(self.state.clone())
            .oneshot(request)
            .await
            .expect("router call failed");
        self.status = Some(response.status());
        let bytes = response
            .into_body()
            .collect()
            .await
            .expect("failed to read the response body")
            .to_bytes();
        self.body = serde_json::from_slice(&bytes).ok();
    }

    fn body(&self) -> &Value {
        self.body
            .as_ref()
            .expect("the last response had no JSON body")
    }

    fn list(&self) -> &Vec<Value> {
        self.body()
            .as_array()
            .expect("the last response was not a JSON list")
    }

    /// Creates a space the way `POST /api/organizations` does — row, seeded
    /// prices/fines and Keycloak groups — without going through the route, so
    /// scenarios can start from an existing space.
    async fn seed_org(&mut self, name: &str, approved: bool) {
        let slug = format!("test-{}", Uuid::new_v4());
        let org_id: Uuid = sqlx::query_scalar!(
            "INSERT INTO organizations (name, slug, contact_email, approved, created_by)
             VALUES ($1, $2, $3, $4, 'cucumber') RETURNING id",
            name,
            slug,
            format!("{slug}@example.test"),
            approved,
        )
        .fetch_one(self.pool())
        .await
        .expect("failed to insert the test organization");

        sqlx::query!(
            "INSERT INTO consumable_types (organization_id, code, label, price_cents) VALUES
                ($1, 'beer', 'Bière', 100), ($1, 'soft', 'Soft', 100)",
            org_id
        )
        .execute(self.pool())
        .await
        .expect("failed to seed consumable types");
        sqlx::query!(
            "INSERT INTO fine_types (organization_id, code, label, amount_cents) VALUES
                ($1, 'late_training', 'Retard entraînement', 200),
                ($1, 'red_card', 'Carton rouge', 500)",
            org_id
        )
        .execute(self.pool())
        .await
        .expect("failed to seed fine types");

        self.state
            .keycloak_admin
            .create_org_groups(org_id)
            .await
            .expect("the Keycloak stub should accept the group creation");

        self.orgs.insert(name.to_string(), org_id);
    }

    async fn consumable_id(&self, org_id: Uuid, code: &str) -> Uuid {
        sqlx::query_scalar!(
            "SELECT id FROM consumable_types WHERE organization_id = $1 AND code = $2",
            org_id,
            code
        )
        .fetch_one(self.pool())
        .await
        .unwrap_or_else(|_| panic!("no '{code}' consumable in this space"))
    }

    async fn fine_id(&self, org_id: Uuid, code: &str) -> Uuid {
        sqlx::query_scalar!(
            "SELECT id FROM fine_types WHERE organization_id = $1 AND code = $2",
            org_id,
            code
        )
        .fetch_one(self.pool())
        .await
        .unwrap_or_else(|_| panic!("no '{code}' fine type in this space"))
    }
}

/// `admin` / `membre` / `joueur` as written in the features -> the role name
/// Keycloak and the JWT use.
fn role_slug(role: &str) -> &'static str {
    match role {
        "admin" => "admin",
        "membre" | "member" => "member",
        "joueur" | "player" => "player",
        other => panic!("unknown role « {other} » (expected admin, membre or joueur)"),
    }
}

// ---------------------------------------------------------------------------
// Given
// ---------------------------------------------------------------------------

#[given(expr = "un espace validé nommé {string}")]
async fn given_approved_org(world: &mut MoelanWorld, name: String) {
    world.seed_org(&name, true).await;
}

#[given(expr = "un espace en attente de validation nommé {string}")]
async fn given_pending_org(world: &mut MoelanWorld, name: String) {
    world.seed_org(&name, false).await;
}

#[given(expr = "le joueur {string} dans l'espace {string}")]
async fn given_player_in_org(world: &mut MoelanWorld, player: String, org: String) {
    let org_id = world.org_id(&org);
    let (first, last) = player.split_once(' ').unwrap_or((player.as_str(), ""));
    let id: Uuid = sqlx::query_scalar!(
        "INSERT INTO players (organization_id, first_name, last_name) VALUES ($1, $2, $3) RETURNING id",
        org_id,
        first,
        last,
    )
    .fetch_one(world.pool())
    .await
    .expect("failed to insert the test player");
    world.players.insert(player, id);
}

#[given(expr = "le joueur {string}")]
async fn given_player(world: &mut MoelanWorld, player: String) {
    let org_id = world.only_org();
    let org_name = world
        .orgs
        .iter()
        .find(|(_, id)| **id == org_id)
        .map(|(name, _)| name.clone())
        .unwrap();
    given_player_in_org(world, player, org_name).await;
}

/// Goes through the ledger rather than writing `balance_cents` directly, so a
/// scenario's starting balance obeys the same invariant as everything else.
#[given(expr = "le joueur {string} a un solde de {int} centimes")]
async fn given_player_balance(world: &mut MoelanWorld, player: String, cents: i64) {
    let org_id = world.acting_org();
    let player_id = world.player_id(&player);
    tx_service::record_adjustment(
        world.pool(),
        &Notifiers {
            mailer: &world.state.mailer,
            fcm: &world.state.fcm,
        },
        org_id,
        player_id,
        cents,
        "solde initial du scénario".into(),
        "cucumber",
    )
    .await
    .expect("failed to set the starting balance");
}

#[given(expr = "je suis connecté comme {word} de l'espace {string}")]
async fn given_logged_in_as(world: &mut MoelanWorld, role: String, org: String) {
    let org_id = world.org_id(&org);
    let role = role_slug(&role);
    let sub = Uuid::new_v4().to_string();
    let username = format!("{role}@{org}.test");
    world.stub.add_user(support::StubUser {
        id: sub.clone(),
        username: username.clone(),
        email: Some(username.clone()),
        first_name: Some(role.to_string()),
        last_name: Some(org.clone()),
        enabled: true,
        groups: vec![format!("/org-{org_id}/{role}")],
        realm_roles: vec![role.to_string()],
    });
    world.actor = Some(Actor {
        sub,
        username,
        realm_roles: vec![role.to_string()],
        groups: vec![format!("/org-{org_id}/{role}")],
    });
}

#[given(expr = "je suis connecté comme super-admin")]
async fn given_logged_in_superadmin(world: &mut MoelanWorld) {
    let sub = Uuid::new_v4().to_string();
    world.stub.add_user(support::StubUser {
        id: sub.clone(),
        username: "operateur".into(),
        email: Some("operateur@moelan.test".into()),
        first_name: Some("Olivier".into()),
        last_name: Some("Opérateur".into()),
        enabled: true,
        groups: vec![],
        realm_roles: vec!["superadmin".into()],
    });
    world.actor = Some(Actor {
        sub,
        username: "operateur".into(),
        realm_roles: vec!["superadmin".into()],
        groups: vec![],
    });
}

#[given(expr = "je suis connecté avec un compte sans espace")]
async fn given_logged_in_without_org(world: &mut MoelanWorld) {
    let sub = Uuid::new_v4().to_string();
    world.stub.add_user(support::StubUser {
        id: sub.clone(),
        username: "nouveau".into(),
        email: Some("nouveau@moelan.test".into()),
        first_name: Some("Nina".into()),
        last_name: Some("Nouvelle".into()),
        enabled: true,
        groups: vec![],
        realm_roles: vec![],
    });
    world.actor = Some(Actor {
        sub,
        username: "nouveau".into(),
        realm_roles: vec![],
        groups: vec![],
    });
}

#[given(expr = "je ne suis pas connecté")]
async fn given_anonymous(world: &mut MoelanWorld) {
    world.actor = None;
    world.token_override = None;
}

#[given(expr = "mon jeton d'accès est falsifié")]
async fn given_forged_token(world: &mut MoelanWorld) {
    let actor = world
        .actor
        .clone()
        .expect("this step needs a signed-in account to forge a token for");
    world.token_override = Some(mint_forged_token(&actor, &world.issuer));
}

#[given(expr = "le compte {string} est {word} de l'espace {string}")]
async fn given_account_in_org(
    world: &mut MoelanWorld,
    username: String,
    role: String,
    org: String,
) {
    let org_id = world.org_id(&org);
    let role = role_slug(&role);
    world.stub.add_user(support::StubUser {
        id: Uuid::new_v4().to_string(),
        username: username.clone(),
        email: Some(username.clone()),
        first_name: None,
        last_name: None,
        enabled: true,
        groups: vec![format!("/org-{org_id}/{role}")],
        realm_roles: vec![role.to_string()],
    });
}

#[given(expr = "le compte {string} n'appartient à aucun espace")]
async fn given_account_without_org(world: &mut MoelanWorld, username: String) {
    world.stub.add_user(support::StubUser {
        id: Uuid::new_v4().to_string(),
        username: username.clone(),
        email: Some(username.clone()),
        first_name: None,
        last_name: None,
        enabled: true,
        groups: vec![],
        realm_roles: vec![],
    });
}

// ---------------------------------------------------------------------------
// When
// ---------------------------------------------------------------------------

#[when(expr = "j'appelle {word} {string}")]
async fn when_call(world: &mut MoelanWorld, method: String, path: String) {
    let path = resolve_path(world, &path);
    world.call(&method, &path, None).await;
}

#[when(expr = "j'appelle {word} {string} avec le corps:")]
async fn when_call_with_body(
    world: &mut MoelanWorld,
    method: String,
    path: String,
    step: &cucumber::gherkin::Step,
) {
    let path = resolve_path(world, &path);
    let raw = step
        .docstring
        .as_ref()
        .expect("this step needs a JSON docstring body");
    let body: Value = serde_json::from_str(raw.trim()).expect("the body must be valid JSON");
    world.call(&method, &path, Some(body)).await;
}

/// Lets features write real routes with readable placeholders:
/// `/api/organizations/<Les Loups>/approve`, `/api/players/<Paul Durand>`.
fn resolve_path(world: &MoelanWorld, path: &str) -> String {
    let mut out = path.to_string();
    for (name, id) in world.orgs.iter().chain(world.players.iter()) {
        out = out.replace(&format!("<{name}>"), &id.to_string());
    }
    out
}

#[when(expr = "j'enregistre une {word} pour le joueur {string}")]
async fn when_record_consumption(world: &mut MoelanWorld, drink: String, player: String) {
    let code = match drink.as_str() {
        "bière" => "beer",
        "soft" => "soft",
        other => panic!("unknown consumable « {other} »"),
    };
    let org_id = world.acting_org();
    let consumable_id = world.consumable_id(org_id, code).await;
    let player_id = world.player_id(&player);
    world
        .call(
            "POST",
            &format!("/api/players/{player_id}/consumptions"),
            Some(json!({ "consumable_type_id": consumable_id })),
        )
        .await;
}

#[when(expr = "j'enregistre {int} bières pour le joueur {string}")]
async fn when_record_consumptions(world: &mut MoelanWorld, quantity: i32, player: String) {
    let org_id = world.acting_org();
    let consumable_id = world.consumable_id(org_id, "beer").await;
    let player_id = world.player_id(&player);
    world
        .call(
            "POST",
            &format!("/api/players/{player_id}/consumptions"),
            Some(json!({ "consumable_type_id": consumable_id, "quantity": quantity })),
        )
        .await;
}

#[when(expr = "j'inflige l'amende {string} au joueur {string}")]
async fn when_record_fine(world: &mut MoelanWorld, code: String, player: String) {
    let org_id = world.acting_org();
    let fine_id = world.fine_id(org_id, &code).await;
    let player_id = world.player_id(&player);
    world
        .call(
            "POST",
            &format!("/api/players/{player_id}/fines"),
            Some(json!({ "fine_type_id": fine_id })),
        )
        .await;
}

#[when(expr = "je crédite le joueur {string} de {int} centimes")]
async fn when_credit(world: &mut MoelanWorld, player: String, cents: i64) {
    let player_id = world.player_id(&player);
    world
        .call(
            "POST",
            &format!("/api/players/{player_id}/credits"),
            Some(json!({ "amount_cents": cents })),
        )
        .await;
}

#[when(expr = "j'ajuste le solde du joueur {string} de {int} centimes")]
async fn when_adjust(world: &mut MoelanWorld, player: String, cents: i64) {
    let player_id = world.player_id(&player);
    world
        .call(
            "POST",
            &format!("/api/players/{player_id}/adjustments"),
            Some(json!({ "amount_cents": cents, "note": "régularisation" })),
        )
        .await;
}

#[when(expr = "je valide l'espace {string}")]
async fn when_approve_org(world: &mut MoelanWorld, org: String) {
    let org_id = world.org_id(&org);
    world
        .call(
            "PATCH",
            &format!("/api/organizations/{org_id}/approve"),
            None,
        )
        .await;
}

#[when(expr = "je refuse l'espace {string}")]
async fn when_reject_org(world: &mut MoelanWorld, org: String) {
    let org_id = world.org_id(&org);
    world
        .call("DELETE", &format!("/api/organizations/{org_id}"), None)
        .await;
}

#[when(expr = "j'invite le joueur {string} avec l'email {string}")]
async fn when_invite_player(world: &mut MoelanWorld, player: String, email: String) {
    let player_id = world.player_id(&player);
    world
        .call(
            "POST",
            &format!("/api/players/{player_id}/invite"),
            Some(json!({ "email": email })),
        )
        .await;
}

/// The self-service creation route, plus the bookkeeping that lets later
/// steps refer to the brand-new space by the name the feature gave it.
#[when(expr = "je crée un espace nommé {string} avec l'email de contact {string}")]
async fn when_create_org(world: &mut MoelanWorld, name: String, email: String) {
    world
        .call(
            "POST",
            "/api/organizations",
            Some(json!({ "name": name, "contact_email": email })),
        )
        .await;
    if let Some(id) = world
        .body
        .as_ref()
        .and_then(|b| b["id"].as_str())
        .and_then(|id| Uuid::parse_str(id).ok())
    {
        world.orgs.insert(name, id);
    }
}

#[when(expr = "je crée le joueur {string}")]
async fn when_create_player(world: &mut MoelanWorld, player: String) {
    let (first, last) = player.split_once(' ').unwrap_or((player.as_str(), ""));
    world
        .call(
            "POST",
            "/api/players",
            Some(json!({ "first_name": first, "last_name": last })),
        )
        .await;
    if let Some(id) = world
        .body
        .as_ref()
        .and_then(|b| b["id"].as_str())
        .and_then(|id| Uuid::parse_str(id).ok())
    {
        world.players.insert(player, id);
    }
}

#[when(expr = "je désactive le joueur {string}")]
async fn when_deactivate_player(world: &mut MoelanWorld, player: String) {
    let player_id = world.player_id(&player);
    world
        .call(
            "PATCH",
            &format!("/api/players/{player_id}"),
            Some(json!({ "active": false })),
        )
        .await;
}

#[when(expr = "je change le prix de la {word} à {int} centimes")]
async fn when_change_price(world: &mut MoelanWorld, drink: String, cents: i64) {
    let code = match drink.as_str() {
        "bière" => "beer",
        "soft" => "soft",
        other => panic!("unknown consumable « {other} »"),
    };
    let org_id = world.acting_org();
    let id = world.consumable_id(org_id, code).await;
    world
        .call(
            "PATCH",
            &format!("/api/consumable-types/{id}"),
            Some(json!({ "price_cents": cents })),
        )
        .await;
}

#[when(expr = "je change le montant de l'amende {string} à {int} centimes")]
async fn when_change_fine_amount(world: &mut MoelanWorld, code: String, cents: i64) {
    let org_id = world.acting_org();
    let id = world.fine_id(org_id, &code).await;
    world
        .call(
            "PATCH",
            &format!("/api/fine-types/{id}"),
            Some(json!({ "amount_cents": cents })),
        )
        .await;
}

#[when(expr = "je crée l'amende {string} intitulée {string} à {int} centimes")]
async fn when_create_fine_type(world: &mut MoelanWorld, code: String, label: String, cents: i64) {
    world
        .call(
            "POST",
            "/api/fine-types",
            Some(json!({ "code": code, "label": label, "amount_cents": cents })),
        )
        .await;
}

#[when(expr = "je fixe l'objectif de la cagnotte à {int} centimes")]
async fn when_set_target(world: &mut MoelanWorld, cents: i64) {
    world
        .call(
            "PATCH",
            "/api/organizations/me",
            Some(json!({ "target_cents": cents, "debt_alert_threshold_cents": null })),
        )
        .await;
}

#[when(expr = "je fixe le seuil d'alerte de dette à {int} centimes")]
async fn when_set_threshold(world: &mut MoelanWorld, cents: i64) {
    world
        .call(
            "PATCH",
            "/api/organizations/me",
            Some(json!({ "target_cents": null, "debt_alert_threshold_cents": cents })),
        )
        .await;
}

// ---------------------------------------------------------------------------
// Then
// ---------------------------------------------------------------------------

#[then(expr = "le statut de la réponse est {int}")]
async fn then_status(world: &mut MoelanWorld, expected: u16) {
    let status = world.status.expect("no request has been made yet");
    assert_eq!(
        status.as_u16(),
        expected,
        "unexpected status; body was {:?}",
        world.body
    );
}

#[then(expr = "le code d'erreur est {string}")]
async fn then_error_code(world: &mut MoelanWorld, expected: String) {
    let code = world.body()["code"].as_str().unwrap_or_default();
    assert_eq!(code, expected, "unexpected error code in {:?}", world.body);
}

#[then(expr = "la réponse contient {int} éléments")]
async fn then_list_len(world: &mut MoelanWorld, expected: usize) {
    assert_eq!(
        world.list().len(),
        expected,
        "unexpected list length in {:?}",
        world.body
    );
}

#[then(expr = "la réponse contient le joueur {string}")]
async fn then_list_contains_player(world: &mut MoelanWorld, player: String) {
    assert!(
        list_has_player(world.list(), &player),
        "« {player} » missing from {:?}",
        world.body
    );
}

#[then(expr = "la réponse ne contient pas le joueur {string}")]
async fn then_list_lacks_player(world: &mut MoelanWorld, player: String) {
    assert!(
        !list_has_player(world.list(), &player),
        "« {player} » should not appear in {:?}",
        world.body
    );
}

fn list_has_player(list: &[Value], player: &str) -> bool {
    let (first, last) = player.split_once(' ').unwrap_or((player, ""));
    list.iter().any(|item| {
        item["first_name"].as_str() == Some(first) && item["last_name"].as_str() == Some(last)
    })
}

#[then(expr = "la réponse contient l'espace {string}")]
async fn then_list_contains_org(world: &mut MoelanWorld, org: String) {
    assert!(
        list_has_org(world.list(), &org),
        "« {org} » missing from {:?}",
        world.body
    );
}

#[then(expr = "la réponse ne contient pas l'espace {string}")]
async fn then_list_lacks_org(world: &mut MoelanWorld, org: String) {
    assert!(
        !list_has_org(world.list(), &org),
        "« {org} » should not appear in {:?}",
        world.body
    );
}

fn list_has_org(list: &[Value], org: &str) -> bool {
    list.iter().any(|item| item["name"].as_str() == Some(org))
}

#[then(expr = "le premier élément de la réponse contient le champ {string} égal à {int}")]
async fn then_first_element_field(world: &mut MoelanWorld, field: String, expected: i64) {
    let list = world.list();
    let first = list.first().expect("the response list was empty");
    assert_eq!(
        first[&field].as_i64(),
        Some(expected),
        "unexpected « {field} » in {first:?}"
    );
}

#[then(expr = "le solde du joueur {string} est de {int} centimes")]
async fn then_player_balance(world: &mut MoelanWorld, player: String, expected: i64) {
    let player_id = world.player_id(&player);
    let balance = sqlx::query_scalar!("SELECT balance_cents FROM players WHERE id = $1", player_id)
        .fetch_one(world.pool())
        .await
        .expect("player row should exist");
    assert_eq!(balance, expected, "unexpected balance for « {player} »");
}

/// The ledger invariant, restated as an assertion a scenario can make: the
/// cached balance is always the sum of that player's transactions.
#[then(expr = "le solde du joueur {string} est cohérent avec son historique")]
async fn then_balance_matches_ledger(world: &mut MoelanWorld, player: String) {
    let player_id = world.player_id(&player);
    let balance = sqlx::query_scalar!("SELECT balance_cents FROM players WHERE id = $1", player_id)
        .fetch_one(world.pool())
        .await
        .expect("player row should exist");
    let sum = sqlx::query_scalar!(
        "SELECT COALESCE(SUM(amount_cents), 0)::bigint FROM transactions WHERE player_id = $1",
        player_id
    )
    .fetch_one(world.pool())
    .await
    .expect("ledger query failed")
    .unwrap_or(0);
    assert_eq!(sum, balance, "cached balance drifted from the ledger");
}

#[then(expr = "le joueur {string} a {int} transactions")]
async fn then_player_transaction_count(world: &mut MoelanWorld, player: String, expected: i64) {
    let player_id = world.player_id(&player);
    let count = sqlx::query_scalar!(
        "SELECT COUNT(*)::bigint FROM transactions WHERE player_id = $1",
        player_id
    )
    .fetch_one(world.pool())
    .await
    .expect("ledger query failed")
    .unwrap_or(0);
    assert_eq!(count, expected, "unexpected transaction count");
}

#[then(expr = "l'espace {string} n'existe plus")]
async fn then_org_gone(world: &mut MoelanWorld, org: String) {
    let org_id = world.org_id(&org);
    let exists = sqlx::query_scalar!(
        "SELECT EXISTS (SELECT 1 FROM organizations WHERE id = $1)",
        org_id
    )
    .fetch_one(world.pool())
    .await
    .expect("query failed")
    .unwrap_or(false);
    assert!(!exists, "« {org} » should have been deleted");
}

#[then(expr = "l'espace {string} existe toujours")]
async fn then_org_still_there(world: &mut MoelanWorld, org: String) {
    let org_id = world.org_id(&org);
    let exists = sqlx::query_scalar!(
        "SELECT EXISTS (SELECT 1 FROM organizations WHERE id = $1)",
        org_id
    )
    .fetch_one(world.pool())
    .await
    .expect("query failed")
    .unwrap_or(false);
    assert!(exists, "« {org} » should not have been deleted");
}

#[then(expr = "l'espace {string} est validé")]
async fn then_org_approved(world: &mut MoelanWorld, org: String) {
    let org_id = world.org_id(&org);
    let approved = sqlx::query_scalar!("SELECT approved FROM organizations WHERE id = $1", org_id)
        .fetch_one(world.pool())
        .await
        .expect("the space should still exist");
    assert!(approved, "« {org} » should be approved");
}

#[then(expr = "l'espace {string} est toujours en attente")]
async fn then_org_still_pending(world: &mut MoelanWorld, org: String) {
    let org_id = world.org_id(&org);
    let approved = sqlx::query_scalar!("SELECT approved FROM organizations WHERE id = $1", org_id)
        .fetch_one(world.pool())
        .await
        .expect("the space should still exist");
    assert!(!approved, "« {org} » should still be pending");
}

#[then(expr = "les données de l'espace {string} ont été supprimées")]
async fn then_org_data_gone(world: &mut MoelanWorld, org: String) {
    let org_id = world.org_id(&org);
    let counts = sqlx::query!(
        r#"
        SELECT
            (SELECT COUNT(*) FROM consumable_types WHERE organization_id = $1) AS "consumables!",
            (SELECT COUNT(*) FROM fine_types WHERE organization_id = $1) AS "fines!",
            (SELECT COUNT(*) FROM players WHERE organization_id = $1) AS "players!",
            (SELECT COUNT(*) FROM transactions WHERE organization_id = $1) AS "transactions!"
        "#,
        org_id
    )
    .fetch_one(world.pool())
    .await
    .expect("count query failed");
    assert_eq!(
        (
            counts.consumables,
            counts.fines,
            counts.players,
            counts.transactions
        ),
        (0, 0, 0, 0),
        "rows survived the deletion of « {org} »"
    );
}

#[then(expr = "les groupes Keycloak de l'espace {string} ont été supprimés")]
async fn then_groups_gone(world: &mut MoelanWorld, org: String) {
    let org_id = world.org_id(&org);
    for role in ["", "/admin", "/member", "/player"] {
        let path = format!("org-{org_id}{role}");
        assert!(
            !world.stub.group_exists(&path),
            "Keycloak group « {path} » should have been deleted"
        );
    }
}

#[then(expr = "les groupes Keycloak de l'espace {string} existent toujours")]
async fn then_groups_still_there(world: &mut MoelanWorld, org: String) {
    let org_id = world.org_id(&org);
    assert!(
        world.stub.group_exists(&format!("org-{org_id}/admin")),
        "Keycloak groups should not have been deleted"
    );
}

#[then(
    expr = "la réponse contient l'utilisateur {string} avec le rôle {string} dans l'espace {string}"
)]
async fn then_users_contains(world: &mut MoelanWorld, username: String, role: String, org: String) {
    let expected_role = role_slug(&role);
    let found = world.list().iter().any(|user| {
        user["username"].as_str() == Some(username.as_str())
            && user["org_role"].as_str() == Some(expected_role)
            && user["organization_name"].as_str() == Some(org.as_str())
    });
    assert!(
        found,
        "« {username} » ({expected_role} @ {org}) missing from {:?}",
        world.body
    );
}

#[then(expr = "la réponse contient l'utilisateur {string} sans espace")]
async fn then_users_contains_orphan(world: &mut MoelanWorld, username: String) {
    let found = world.list().iter().any(|user| {
        user["username"].as_str() == Some(username.as_str())
            && user["organization_id"].is_null()
            && user["org_role"].is_null()
    });
    assert!(found, "« {username} » missing from {:?}", world.body);
}

#[then(expr = "la réponse contient l'utilisateur super-admin {string}")]
async fn then_users_contains_superadmin(world: &mut MoelanWorld, username: String) {
    let found = world.list().iter().any(|user| {
        user["username"].as_str() == Some(username.as_str())
            && user["superadmin"].as_bool() == Some(true)
    });
    assert!(
        found,
        "super-admin « {username} » missing from {:?}",
        world.body
    );
}

#[then(expr = "un email d'invitation a été envoyé à {string}")]
async fn then_invite_sent(world: &mut MoelanWorld, email: String) {
    let sent = world.stub.invite_emails();
    assert!(
        sent.contains(&email),
        "no invite sent to « {email} » (sent: {sent:?})"
    );
}

#[then(expr = "la réponse contient le champ {string} égal à {int}")]
async fn then_field_int(world: &mut MoelanWorld, field: String, expected: i64) {
    let actual = world.body()[&field].as_i64();
    assert_eq!(
        actual,
        Some(expected),
        "unexpected « {field} » in {:?}",
        world.body
    );
}

#[then(expr = "la réponse contient le champ {string} égal à {string}")]
async fn then_field_string(world: &mut MoelanWorld, field: String, expected: String) {
    let actual = world.body()[&field].as_str();
    assert_eq!(
        actual,
        Some(expected.as_str()),
        "unexpected « {field} » in {:?}",
        world.body
    );
}

#[then(expr = "la réponse indique que l'espace n'est pas encore validé")]
async fn then_created_org_pending(world: &mut MoelanWorld) {
    assert_eq!(
        world.body()["approved"].as_bool(),
        Some(false),
        "a freshly created space must start unapproved, got {:?}",
        world.body
    );
}

#[then(expr = "le prix de la {word} est de {int} centimes")]
async fn then_price_is(world: &mut MoelanWorld, drink: String, expected: i64) {
    let code = match drink.as_str() {
        "bière" => "beer",
        "soft" => "soft",
        other => panic!("unknown consumable « {other} »"),
    };
    let org_id = world.acting_org();
    let price = sqlx::query_scalar!(
        "SELECT price_cents FROM consumable_types WHERE organization_id = $1 AND code = $2",
        org_id,
        code
    )
    .fetch_one(world.pool())
    .await
    .expect("the consumable type should exist");
    assert_eq!(price, expected);
}

#[then(expr = "le montant de l'amende {string} est de {int} centimes")]
async fn then_fine_amount_is(world: &mut MoelanWorld, code: String, expected: i64) {
    let org_id = world.acting_org();
    let amount = sqlx::query_scalar!(
        "SELECT amount_cents FROM fine_types WHERE organization_id = $1 AND code = $2",
        org_id,
        code
    )
    .fetch_one(world.pool())
    .await
    .expect("the fine type should exist");
    assert_eq!(amount, expected);
}

#[then(expr = "l'objectif de l'espace {string} est de {int} centimes")]
async fn then_org_target(world: &mut MoelanWorld, org: String, expected: i64) {
    let org_id = world.org_id(&org);
    let target = sqlx::query_scalar!(
        "SELECT target_cents FROM organizations WHERE id = $1",
        org_id
    )
    .fetch_one(world.pool())
    .await
    .expect("the space should exist");
    assert_eq!(target, Some(expected));
}

#[then(expr = "le joueur {string} est inactif")]
async fn then_player_inactive(world: &mut MoelanWorld, player: String) {
    let player_id = world.player_id(&player);
    let active = sqlx::query_scalar!("SELECT active FROM players WHERE id = $1", player_id)
        .fetch_one(world.pool())
        .await
        .expect("the player should exist");
    assert!(!active, "« {player} » should be inactive");
}

// ---------------------------------------------------------------------------

#[tokio::main]
async fn main() {
    MoelanWorld::cucumber()
        // The Keycloak stub's realm is shared in-process state, and the
        // user-listing scenarios assert on its full content.
        .max_concurrent_scenarios(1)
        .run_and_exit("../spec/features")
        .await;
}
