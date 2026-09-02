use dead_rose_ipc::{DEFAULT_SOCKET, request};
use dead_rose_system_types::{CoreRequest, CoreResponse, ErrorCode};
use serde::Serialize;
use std::sync::atomic::{AtomicBool, Ordering};
use tauri::webview::PageLoadEvent;
use tracing::{info, warn};

#[cfg(all(not(debug_assertions), not(feature = "custom-protocol")))]
compile_error!(
    "release builds of dead-rose-shell must enable the custom-protocol feature to bundle frontend assets"
);

static CORE_UNAVAILABLE: AtomicBool = AtomicBool::new(false);

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct AuthResult {
    ok: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    session_id: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<&'static str>,
    #[serde(skip_serializing_if = "Option::is_none")]
    retry_after_seconds: Option<u64>,
}

#[tauri::command]
async fn core_readiness() -> bool {
    match request(DEFAULT_SOCKET, &CoreRequest::Readiness).await {
        Ok(CoreResponse::Ready) => {
            if CORE_UNAVAILABLE.swap(false, Ordering::Relaxed) {
                info!(
                    stage = "core",
                    socket = DEFAULT_SOCKET,
                    "Dead Rose core connection restored"
                );
            }
            true
        }
        Ok(response) => {
            if !CORE_UNAVAILABLE.swap(true, Ordering::Relaxed) {
                warn!(
                    stage = "core",
                    ?response,
                    "Dead Rose core returned an unexpected readiness response"
                );
            }
            false
        }
        Err(error) => {
            if !CORE_UNAVAILABLE.swap(true, Ordering::Relaxed) {
                warn!(stage = "core", socket = DEFAULT_SOCKET, %error, "Dead Rose core is unavailable");
            }
            false
        }
    }
}

#[tauri::command]
async fn authenticate(username: String, password: String) -> AuthResult {
    let response = request(
        DEFAULT_SOCKET,
        &CoreRequest::Authenticate { username, password },
    )
    .await;
    match response {
        Ok(CoreResponse::Authenticated { session_id, .. }) => AuthResult {
            ok: true,
            session_id: Some(session_id),
            error: None,
            retry_after_seconds: None,
        },
        Ok(CoreResponse::Error {
            code: ErrorCode::InvalidCredentials,
            ..
        }) => AuthResult {
            ok: false,
            session_id: None,
            error: Some("invalid_credentials"),
            retry_after_seconds: None,
        },
        Ok(CoreResponse::Error {
            code: ErrorCode::RateLimited,
            retry_after_seconds,
            ..
        }) => AuthResult {
            ok: false,
            session_id: None,
            error: Some("rate_limited"),
            retry_after_seconds,
        },
        _ => AuthResult {
            ok: false,
            session_id: None,
            error: Some("internal_error"),
            retry_after_seconds: None,
        },
    }
}

#[tauri::command]
async fn logout(session_id: String) -> Result<(), String> {
    match request(DEFAULT_SOCKET, &CoreRequest::Logout { session_id }).await {
        Ok(CoreResponse::LoggedOut) => Ok(()),
        _ => Err("logout_failed".into()),
    }
}

fn main() {
    init_logging();
    info!(
        stage = "shell",
        frontend = if cfg!(feature = "custom-protocol") {
            "bundled"
        } else {
            "development-server"
        },
        "Dead Rose shell starting"
    );
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            core_readiness,
            authenticate,
            logout
        ])
        .on_page_load(|_, payload| {
            if payload.event() == PageLoadEvent::Finished {
                info!(
                    stage = "frontend",
                    url = %payload.url(),
                    "DEAD_ROSE_FRONTEND_READY url={}",
                    payload.url()
                );
            }
        })
        .run(tauri::generate_context!())
        .expect("Dead Rose shell failed to start");
}

fn init_logging() {
    if let Ok(layer) = tracing_journald::layer() {
        use tracing_subscriber::prelude::*;
        let _ = tracing_subscriber::registry().with(layer).try_init();
    } else {
        let _ = tracing_subscriber::fmt().with_target(false).try_init();
    }
}
