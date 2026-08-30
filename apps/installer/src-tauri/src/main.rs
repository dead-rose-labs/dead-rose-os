use dead_rose_system_types::{INSTALLER_SOCKET, InstallDisk, InstallerRequest, InstallerResponse};
use serde::{Deserialize, Serialize};
use std::{env, path::PathBuf};
use tokio::{
    io::{AsyncBufReadExt, AsyncWrite, AsyncWriteExt, BufReader},
    net::UnixStream,
};

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct InstallRequest {
    stable_id: PathBuf,
    hostname: String,
    username: String,
    password: String,
    confirmation: String,
}

#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct InstallEvent {
    phase: String,
    message: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct CommandError {
    code: String,
    message: String,
}

#[tauri::command]
async fn enumerate_disks() -> Result<Vec<InstallDisk>, CommandError> {
    match request_once(InstallerRequest::EnumerateDisks).await? {
        InstallerResponse::Disks { disks } => Ok(disks),
        InstallerResponse::Error { code, message } => Err(CommandError { code, message }),
        _ => Err(protocol_error()),
    }
}

#[tauri::command]
async fn install(
    request: InstallRequest,
    progress: tauri::ipc::Channel<InstallEvent>,
) -> Result<(), CommandError> {
    let stream = connect().await?;
    let (read, mut write) = stream.into_split();
    write_request(
        &mut write,
        &InstallerRequest::Install {
            stable_id: request.stable_id,
            hostname: request.hostname,
            username: request.username,
            password: request.password,
            confirmation: request.confirmation,
        },
    )
    .await?;
    let mut lines = BufReader::new(read).lines();
    while let Some(line) = lines.next_line().await.map_err(transport_error)? {
        match serde_json::from_str::<InstallerResponse>(&line).map_err(protocol_transport_error)? {
            InstallerResponse::Progress { phase, message } => progress
                .send(InstallEvent { phase, message })
                .map_err(|error| CommandError {
                    code: "progress_channel_failed".into(),
                    message: error.to_string(),
                })?,
            InstallerResponse::Complete => return Ok(()),
            InstallerResponse::Error { code, message } => {
                return Err(CommandError { code, message });
            }
            _ => return Err(protocol_error()),
        }
    }
    Err(CommandError {
        code: "backend_disconnected".into(),
        message: "The privileged installer backend disconnected.".into(),
    })
}

#[tauri::command]
async fn restart() -> Result<(), CommandError> {
    match request_once(InstallerRequest::Restart).await? {
        InstallerResponse::Restarting => Ok(()),
        InstallerResponse::Error { code, message } => Err(CommandError { code, message }),
        _ => Err(protocol_error()),
    }
}

async fn request_once(request: InstallerRequest) -> Result<InstallerResponse, CommandError> {
    let mut stream = connect().await?;
    write_request(&mut stream, &request).await?;
    let mut line = String::new();
    BufReader::new(stream)
        .read_line(&mut line)
        .await
        .map_err(transport_error)?;
    serde_json::from_str(&line).map_err(protocol_transport_error)
}

async fn connect() -> Result<UnixStream, CommandError> {
    let socket =
        env::var("DEAD_ROSE_INSTALLER_SOCKET").unwrap_or_else(|_| INSTALLER_SOCKET.to_owned());
    UnixStream::connect(socket).await.map_err(transport_error)
}

async fn write_request(
    write: &mut (impl AsyncWrite + Unpin),
    request: &InstallerRequest,
) -> Result<(), CommandError> {
    write
        .write_all(&serde_json::to_vec(request).map_err(protocol_transport_error)?)
        .await
        .map_err(transport_error)?;
    write.write_all(b"\n").await.map_err(transport_error)
}

fn transport_error(error: std::io::Error) -> CommandError {
    CommandError {
        code: "backend_unavailable".into(),
        message: error.to_string(),
    }
}

fn protocol_transport_error(error: serde_json::Error) -> CommandError {
    CommandError {
        code: "backend_protocol_error".into(),
        message: error.to_string(),
    }
}

fn protocol_error() -> CommandError {
    CommandError {
        code: "backend_protocol_error".into(),
        message: "The installer backend returned an unexpected response.".into(),
    }
}

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![enumerate_disks, install, restart])
        .run(tauri::generate_context!())
        .expect("Dead Rose installer failed to start");
}
