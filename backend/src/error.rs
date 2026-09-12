use axum::{
    Json,
    http::StatusCode,
    response::{IntoResponse, Response},
};
use serde_json::json;

#[derive(thiserror::Error, Debug)]
pub enum AppError {
    #[error("not found")]
    NotFound,
    #[error("bad request: {0}")]
    BadRequest(String),
    #[error("unauthorized")]
    Unauthorized,
    #[error("forbidden")]
    Forbidden,
    #[error("account has no organization yet")]
    NoOrganization,
    #[error("organization pending approval")]
    OrgPending,
    #[error("internal error")]
    Internal(String),
    #[error(transparent)]
    Sqlx(#[from] sqlx::Error),
}

impl AppError {
    /// Machine-readable slug for the few variants the frontend needs to
    /// branch on (routing to create-space / pending-approval screens)
    /// rather than parsing the human-readable message text.
    fn code(&self) -> Option<&'static str> {
        match self {
            AppError::NoOrganization => Some("no_organization"),
            AppError::OrgPending => Some("org_pending"),
            _ => None,
        }
    }
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, message) = match &self {
            AppError::NotFound => (StatusCode::NOT_FOUND, self.to_string()),
            AppError::BadRequest(_) => (StatusCode::BAD_REQUEST, self.to_string()),
            AppError::Unauthorized => (StatusCode::UNAUTHORIZED, self.to_string()),
            AppError::Forbidden => (StatusCode::FORBIDDEN, self.to_string()),
            AppError::NoOrganization => (StatusCode::FORBIDDEN, self.to_string()),
            AppError::OrgPending => (StatusCode::FORBIDDEN, self.to_string()),
            AppError::Internal(err) => {
                tracing::error!(%err, "internal error");
                (
                    StatusCode::INTERNAL_SERVER_ERROR,
                    "internal server error".to_string(),
                )
            }
            AppError::Sqlx(sqlx::Error::RowNotFound) => {
                (StatusCode::NOT_FOUND, "not found".to_string())
            }
            AppError::Sqlx(err) => {
                tracing::error!(?err, "database error");
                (
                    StatusCode::INTERNAL_SERVER_ERROR,
                    "internal server error".to_string(),
                )
            }
        };
        (
            status,
            Json(json!({ "error": message, "code": self.code() })),
        )
            .into_response()
    }
}

pub type AppResult<T> = Result<T, AppError>;
