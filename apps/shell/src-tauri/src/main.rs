use dead_rose_ipc::{DEFAULT_SOCKET, request};
use dead_rose_system_types::{CoreRequest, CoreResponse, ErrorCode};
use serde::Serialize;

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
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![authenticate, logout])
        .run(tauri::generate_context!())
        .expect("Dead Rose shell failed to start");
}
