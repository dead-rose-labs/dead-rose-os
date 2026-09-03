use dead_rose_types::{CORE_SOCKET_PATH, Request, ResponseEnvelope};

#[tauri::command]
async fn core_request(request: serde_json::Value) -> Result<ResponseEnvelope, String> {
    let request: Request = serde_json::from_value(request)
        .map_err(|error| format!("Invalid typed core request: {error}"))?;
    let announces_state = matches!(request, Request::GetApplicationState { .. });
    let response = tauri::async_runtime::spawn_blocking(move || {
        dead_rose_ipc::call(CORE_SOCKET_PATH, request).map_err(|error| error.to_string())
    })
    .await
    .map_err(|error| format!("Core request task failed: {error}"))??;
    if announces_state
        && response.ok
        && let Some(mode) = response.result.as_ref().and_then(serde_json::Value::as_str)
    {
        eprintln!("DEAD_ROSE_UI_READY mode={mode}");
    }
    Ok(response)
}

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![core_request])
        .run(tauri::generate_context!())
        .expect("Dead Rose Shell failed to start");
}
