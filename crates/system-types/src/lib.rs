use serde::{Deserialize, Serialize};
use std::path::PathBuf;

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

pub const INSTALLER_SOCKET: &str = "/run/dead-rose-installer/backend.sock";

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct InstallDisk {
    pub device: PathBuf,
    pub stable_id: PathBuf,
    pub model: String,
    pub size_bytes: u64,
    pub removable: bool,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(tag = "operation", rename_all = "snake_case")]
pub enum InstallerRequest {
    EnumerateDisks,
    Install {
        stable_id: PathBuf,
        hostname: String,
        username: String,
        password: String,
        confirmation: String,
    },
    Restart,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(tag = "status", rename_all = "snake_case")]
pub enum InstallerResponse {
    Disks { disks: Vec<InstallDisk> },
    Progress { phase: String, message: String },
    Complete,
    Restarting,
    Error { code: String, message: String },
}
