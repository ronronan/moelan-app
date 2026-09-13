use serde::Deserialize;
use uuid::Uuid;

#[derive(Debug, Deserialize)]
pub struct CreatePlayer {
    pub first_name: String,
    pub last_name: String,
}

#[derive(Debug, Deserialize)]
pub struct PatchPlayer {
    pub first_name: Option<String>,
    pub last_name: Option<String>,
    pub active: Option<bool>,
}

#[derive(Debug, Deserialize)]
pub struct PatchConsumableType {
    pub label: Option<String>,
    pub price_cents: Option<i64>,
    pub active: Option<bool>,
}

#[derive(Debug, Deserialize)]
pub struct CreateFineType {
    pub code: String,
    pub label: String,
    pub amount_cents: i64,
}

#[derive(Debug, Deserialize)]
pub struct PatchFineType {
    pub label: Option<String>,
    pub amount_cents: Option<i64>,
    pub active: Option<bool>,
}

#[derive(Debug, Deserialize)]
pub struct CreateConsumption {
    pub consumable_type_id: Uuid,
    #[serde(default = "default_quantity")]
    pub quantity: i32,
}

fn default_quantity() -> i32 {
    1
}

#[derive(Debug, Deserialize)]
pub struct CreateFine {
    pub fine_type_id: Uuid,
    pub note: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct CreateCredit {
    pub amount_cents: i64,
    pub note: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct CreateAdjustment {
    pub amount_cents: i64,
    pub note: String,
}

#[derive(Debug, Deserialize)]
pub struct CreateOrganization {
    pub name: String,
    pub contact_email: String,
}

#[derive(Debug, Deserialize)]
pub struct InvitePlayer {
    pub email: String,
}

#[derive(Debug, Deserialize)]
pub struct PatchOrganization {
    /// The frontend always sends both fields with their full desired state
    /// (a value, or `null` to clear it) rather than omitting them — so a
    /// plain `Option` is enough for each; there's no third "leave
    /// untouched" case to represent (which `Option<Option<_>>` cannot
    /// distinguish from "clear" through serde_json's JSON `null` handling
    /// anyway).
    pub target_cents: Option<i64>,
    /// Negative or zero (enforced by the `organizations` CHECK constraint):
    /// a debt alert fires once a player's balance drops below this.
    pub debt_alert_threshold_cents: Option<i64>,
}

#[derive(Debug, Deserialize)]
pub struct TransactionQuery {
    pub player_id: Option<Uuid>,
    pub kind: Option<String>,
    pub from: Option<chrono::DateTime<chrono::Utc>>,
    pub to: Option<chrono::DateTime<chrono::Utc>>,
    pub page: Option<i64>,
    pub page_size: Option<i64>,
}
