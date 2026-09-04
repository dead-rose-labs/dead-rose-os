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
    if announces_state && response.ok {
        let readiness = tauri::async_runtime::spawn_blocking(move || {
            dead_rose_ipc::call(CORE_SOCKET_PATH, Request::ReportUiReady)
                .map_err(|error| error.to_string())
        })
        .await
        .map_err(|error| format!("UI readiness task failed: {error}"))??;
        if !readiness.ok {
            return Err("Core rejected the typed UI readiness acknowledgement".into());
        }
    }
    Ok(response)
}

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![core_request])
        .run(tauri::generate_context!())
        .expect("Dead Rose Shell failed to start");
}
