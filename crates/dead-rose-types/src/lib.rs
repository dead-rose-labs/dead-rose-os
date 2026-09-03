use serde::{Deserialize, Serialize};
use serde_json::Value;

pub const CORE_SOCKET_PATH: &str = "/run/dead-rose/core.sock";
pub const STATE_DIRECTORY: &str = "/var/lib/dead-rose";

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum BootMode {
    Live,
    Installed,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum ApplicationState {
    LiveInstaller,
    FirstBoot,
    Login,
    Dashboard,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct SystemInfo {
    pub hostname: String,
    pub os_name: String,
    pub version: String,
    pub kernel: String,
    pub architecture: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct InstallDisk {
    pub model: String,
    pub device: String,
    pub size_bytes: u64,
    pub kind: String,
    pub removable: bool,
    pub installation_media: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum OperationPhase {
    Idle,
    Preparing,
    InstallingSystem,
    ConfiguringBoot,
    Finalizing,
    Completed,
    Failed,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct OperationStatus {
    pub phase: OperationPhase,
    pub detail: String,
    pub error: Option<String>,
}

impl Default for OperationStatus {
    fn default() -> Self {
        Self {
            phase: OperationPhase::Idle,
            detail: "No operation is running".into(),
            error: None,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "method", content = "params", rename_all = "snake_case")]
pub enum Request {
    GetSystemInfo,
    GetBootMode,
    ListInstallDisks,
    StartInstall {
        device: String,
        confirmation: String,
    },
    GetInstallStatus,
    GetCurrentVersion,
    StartUpgrade {
        image: String,
        session_token: String,
    },
    GetUpgradeStatus,
    Reboot {
        session_token: Option<String>,
    },
    PowerOff {
        session_token: Option<String>,
    },
    GetApplicationState {
        session_token: Option<String>,
    },
    CreateAdmin {
        username: String,
        password: String,
    },
    Login {
        username: String,
        password: String,
    },
    Logout {
        session_token: String,
    },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RequestEnvelope {
    pub id: String,
    pub request: Request,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ResponseEnvelope {
    pub id: String,
    pub ok: bool,
    pub result: Option<Value>,
    pub error: Option<ApiError>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct ApiError {
    pub code: String,
    pub message: String,
    pub component: String,
}

impl ResponseEnvelope {
    pub fn success<T: Serialize>(id: String, value: T) -> Self {
        match serde_json::to_value(value) {
            Ok(result) => Self {
                id,
                ok: true,
                result: Some(result),
                error: None,
            },
            Err(error) => Self::failure(
                id,
                "serialization_failed",
                format!("Failed to encode response: {error}"),
                "dead-rose-core",
            ),
        }
    }

    pub fn failure(
        id: String,
        code: impl Into<String>,
        message: impl Into<String>,
        component: impl Into<String>,
    ) -> Self {
        Self {
            id,
            ok: false,
            result: None,
            error: Some(ApiError {
                code: code.into(),
                message: message.into(),
                component: component.into(),
            }),
        }
    }
}
