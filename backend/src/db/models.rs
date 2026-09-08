use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, sqlx::Type, Serialize, Deserialize, PartialEq, Eq)]
#[sqlx(type_name = "transaction_kind", rename_all = "snake_case")]
#[serde(rename_all = "snake_case")]
pub enum TransactionKind {
    Beer,
    Soft,
    Fine,
    Credit,
    ManualAdjustment,
}

#[derive(Debug, Clone, sqlx::FromRow, Serialize)]
pub struct Player {
    pub id: Uuid,
    pub first_name: String,
    pub last_name: String,
    pub balance_cents: i64,
    pub active: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, sqlx::FromRow, Serialize)]
pub struct ConsumableType {
    pub id: Uuid,
    pub code: String,
    pub label: String,
    pub price_cents: i64,
    pub active: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, sqlx::FromRow, Serialize)]
pub struct FineType {
    pub id: Uuid,
    pub code: String,
    pub label: String,
    pub amount_cents: i64,
    pub active: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, sqlx::FromRow, Serialize)]
pub struct Transaction {
    pub id: Uuid,
    pub player_id: Uuid,
    pub kind: TransactionKind,
    pub amount_cents: i64,
    pub quantity: i32,
    pub unit_price_cents: Option<i64>,
    pub consumable_type_id: Option<Uuid>,
    pub fine_type_id: Option<Uuid>,
    pub note: Option<String>,
    pub created_by: String,
    pub created_at: DateTime<Utc>,
}
