use dead_rose_types::{CORE_SOCKET_PATH, Request, ResponseEnvelope};

#[tauri::command]
async fn core_request(request: serde_json::Value) -> Result<ResponseEnvelope, String> {
    let method = request
        .get("method")
        .and_then(serde_json::Value::as_str)
        .unwrap_or("unknown")
        .to_owned();
    let request: Request = serde_json::from_value(request)
        .map_err(|error| format!("Invalid typed core request: {error}"))?;
    let announces_state = matches!(request, Request::GetApplicationState { .. });
    eprintln!("DEAD_ROSE_TAURI_REQUEST method={method}");
    let response = match tauri::async_runtime::spawn_blocking(move || {
        dead_rose_ipc::call(CORE_SOCKET_PATH, request).map_err(|error| error.to_string())
    })
    .await
    {
        Ok(Ok(response)) => response,
        Ok(Err(error)) => {
            eprintln!("DEAD_ROSE_TAURI_RESPONSE method={method} ok=false");
            return Err(error);
        }
        Err(error) => {
            eprintln!("DEAD_ROSE_TAURI_RESPONSE method={method} ok=false");
            return Err(format!("Core request task failed: {error}"));
        }
    };
    eprintln!(
        "DEAD_ROSE_TAURI_RESPONSE method={method} ok={}",
        response.ok
    );
    if announces_state && response.ok {
        eprintln!("DEAD_ROSE_TAURI_UI_ACK_BEGIN");
        let readiness = match tauri::async_runtime::spawn_blocking(move || {
            dead_rose_ipc::call(CORE_SOCKET_PATH, Request::ReportUiReady)
                .map_err(|error| error.to_string())
        })
        .await
        {
            Ok(Ok(readiness)) => readiness,
            Ok(Err(error)) => {
                eprintln!("DEAD_ROSE_TAURI_UI_ACK_ERROR error={error}");
                return Err(error);
            }
            Err(error) => {
                let error = format!("UI readiness task failed: {error}");
                eprintln!("DEAD_ROSE_TAURI_UI_ACK_ERROR error={error}");
                return Err(error);
            }
        };
        if !readiness.ok {
            if let Some(error) = &readiness.error {
                eprintln!(
                    "DEAD_ROSE_TAURI_UI_ACK_ERROR code={} component={} message={}",
                    error.code, error.component, error.message
                );
            } else {
                eprintln!("DEAD_ROSE_TAURI_UI_ACK_ERROR error=core_rejected_acknowledgement");
            }
            return Err("Core rejected the typed UI readiness acknowledgement".into());
        }
        eprintln!("DEAD_ROSE_TAURI_UI_ACK_OK");
    }
    Ok(response)
}

fn main() {
    tauri::Builder::default()
        .on_page_load(|_, _| eprintln!("DEAD_ROSE_PAGE_LOADED"))
        .invoke_handler(tauri::generate_handler![core_request])
        .run(tauri::generate_context!())
        .expect("Dead Rose Shell failed to start");
}
