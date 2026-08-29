use serde::{Deserialize, Serialize};

pub const PRODUCT_NAME: &str = "Dead Rose OS";
pub const VERSION: &str = env!("CARGO_PKG_VERSION");

#[derive(Debug, Serialize, Deserialize)]
#[serde(tag = "operation", rename_all = "snake_case")]
pub enum CoreRequest {
    Readiness,
    ProductInfo,
    Authenticate { username: String, password: String },
    ValidateSession { session_id: String },
    Logout { session_id: String },
}

#[derive(Debug, Serialize, Deserialize, PartialEq)]
#[serde(tag = "status", rename_all = "snake_case")]
pub enum CoreResponse {
    Ready,
    ProductInfo {
        name: String,
        version: String,
    },
    Authenticated {
        session_id: String,
        expires_in_seconds: u64,
    },
    ValidSession,
    LoggedOut,
    Error {
        code: ErrorCode,
        message: String,
        retry_after_seconds: Option<u64>,
    },
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum ErrorCode {
    InvalidCredentials,
    RateLimited,
    InvalidSession,
    MalformedRequest,
    Internal,
}
