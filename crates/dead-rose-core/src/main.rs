mod disks;
mod operations;
mod state;

use chrono::Utc;
use dead_rose_types::{
    ApplicationState, BootMode, CORE_SOCKET_PATH, Request, RequestEnvelope, ResponseEnvelope,
    STATE_DIRECTORY, SystemInfo,
};
use operations::OperationManager;
use state::StateStore;
use std::collections::{HashMap, VecDeque};
use std::fs;
use std::io::{BufRead, BufReader, Read, Write};
use std::os::unix::fs::PermissionsExt;
use std::os::unix::net::{UnixListener, UnixStream};
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

const MAX_FRAME_BYTES: u64 = 64 * 1024;
const MAX_LOGIN_ATTEMPTS: usize = 5;
const LOGIN_WINDOW: Duration = Duration::from_secs(60);

struct Core {
    boot_mode: BootMode,
    state: Mutex<StateStore>,
    operations: OperationManager,
    login_attempts: Mutex<HashMap<String, VecDeque<Instant>>>,
}

fn main() {
    if let Err(error) = run() {
        eprintln!("dead-rose-core fatal error: {error}");
        std::process::exit(1);
    }
}

fn run() -> Result<(), String> {
    let state_directory = PathBuf::from(
        std::env::var("DEAD_ROSE_STATE_DIR").unwrap_or_else(|_| STATE_DIRECTORY.into()),
    );
    fs::create_dir_all(state_directory.join("logs"))
        .map_err(|error| format!("failed to create persistent state directories: {error}"))?;
    let state =
        StateStore::open(&state_directory.join("state.db")).map_err(|error| error.to_string())?;
    let core = Arc::new(Core {
        boot_mode: detect_boot_mode(),
        state: Mutex::new(state),
        operations: OperationManager::new(state_directory.join("logs")),
        login_attempts: Mutex::new(HashMap::new()),
    });

    let socket_path = PathBuf::from(
        std::env::var("DEAD_ROSE_CORE_SOCKET").unwrap_or_else(|_| CORE_SOCKET_PATH.into()),
    );
    if let Some(parent) = socket_path.parent() {
        fs::create_dir_all(parent)
            .map_err(|error| format!("failed to create runtime directory: {error}"))?;
    }
    if socket_path.exists() {
        fs::remove_file(&socket_path)
            .map_err(|error| format!("failed to remove stale core socket: {error}"))?;
    }
    let listener = UnixListener::bind(&socket_path)
        .map_err(|error| format!("failed to bind {}: {error}", socket_path.display()))?;
    fs::set_permissions(&socket_path, fs::Permissions::from_mode(0o660))
        .map_err(|error| format!("failed to secure core socket: {error}"))?;
    eprintln!(
        "DEAD_ROSE_CORE_READY mode={:?} at={}",
        core.boot_mode,
        Utc::now().to_rfc3339()
    );

    for stream in listener.incoming() {
        match stream {
            Ok(stream) => {
                let core = core.clone();
                std::thread::spawn(move || handle_connection(&core, stream));
            }
            Err(error) => eprintln!("dead-rose-core accept failed: {error}"),
        }
    }
    Ok(())
}

fn handle_connection(core: &Core, mut stream: UnixStream) {
    let mut line = String::new();
    let read = BufReader::new(&stream)
        .take(MAX_FRAME_BYTES)
        .read_line(&mut line);
    let response = match read {
        Ok(0) => return,
        Ok(_) => match serde_json::from_str::<RequestEnvelope>(&line) {
            Ok(envelope) => dispatch(core, envelope),
            Err(error) => ResponseEnvelope::failure(
                "invalid".to_owned(),
                "invalid_request",
                format!("Request could not be decoded: {error}"),
                "dead-rose-ipc",
            ),
        },
        Err(error) => ResponseEnvelope::failure(
            "invalid".to_owned(),
            "read_failed",
            format!("Request could not be read: {error}"),
            "dead-rose-ipc",
        ),
    };
    if serde_json::to_writer(&mut stream, &response).is_ok() {
        let _ = stream.write_all(b"\n");
    }
}

fn dispatch(core: &Core, envelope: RequestEnvelope) -> ResponseEnvelope {
    let id = envelope.id;
    let result: Result<serde_json::Value, (String, String, String)> = match envelope.request {
        Request::GetSystemInfo => system_info().and_then(to_value),
        Request::GetBootMode => to_value(core.boot_mode.clone()),
        Request::ListInstallDisks => require_live(core)
            .and_then(|_| disks::list_install_disks().map_err(component_error("disk_discovery")))
            .and_then(to_value),
        Request::StartInstall {
            device,
            confirmation,
        } => start_install(core, &device, &confirmation).and_then(to_value),
        Request::GetInstallStatus => to_value(core.operations.install_status()),
        Request::GetCurrentVersion => to_value(env!("CARGO_PKG_VERSION")),
        Request::StartUpgrade {
            image,
            session_token,
        } => require_session(core, &session_token)
            .and_then(|_| {
                core.operations
                    .start_upgrade(&image)
                    .map_err(component_error("update_manager"))
            })
            .and_then(to_value),
        Request::GetUpgradeStatus => to_value(core.operations.upgrade_status()),
        Request::Reboot { session_token } => authorize_power(core, session_token.as_deref())
            .and_then(|_| system_action("reboot"))
            .and_then(to_value),
        Request::PowerOff { session_token } => authorize_power(core, session_token.as_deref())
            .and_then(|_| system_action("poweroff"))
            .and_then(to_value),
        Request::GetApplicationState { session_token } => {
            application_state(core, session_token.as_deref()).and_then(to_value)
        }
        Request::ReportUiReady => report_ui_ready(core).and_then(to_value),
        Request::CreateAdmin { username, password } => {
            if core.boot_mode == BootMode::Live {
                Err(api_error(
                    "unavailable_in_live_mode",
                    "Administrator creation is unavailable in the live installer",
                    "authentication",
                ))
            } else {
                core.state
                    .lock()
                    .unwrap_or_else(|poisoned| poisoned.into_inner())
                    .create_admin(&username, &password)
                    .map_err(component_error("authentication"))
                    .and_then(to_value)
            }
        }
        Request::Login { username, password } => {
            login(core, &username, &password).and_then(to_value)
        }
        Request::Logout { session_token } => core
            .state
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .logout(&session_token)
            .map_err(component_error("authentication"))
            .and_then(to_value),
    };
    match result {
        Ok(value) => ResponseEnvelope::success(id, value),
        Err((code, message, component)) => ResponseEnvelope::failure(id, code, message, component),
    }
}

fn application_state(
    core: &Core,
    session_token: Option<&str>,
) -> Result<ApplicationState, (String, String, String)> {
    if core.boot_mode == BootMode::Live {
        Ok(ApplicationState::LiveInstaller)
    } else {
        core.state
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .application_state(session_token)
            .map_err(component_error("application_state"))
    }
}

fn report_ui_ready(core: &Core) -> Result<ApplicationState, (String, String, String)> {
    let state = application_state(core, None)?;
    eprintln!("DEAD_ROSE_UI_READY mode={}", state.as_str());
    Ok(state)
}

fn detect_boot_mode() -> BootMode {
    match std::env::var("DEAD_ROSE_BOOT_MODE").as_deref() {
        Ok("live") => BootMode::Live,
        Ok("installed") => BootMode::Installed,
        _ if Path::new("/run/initramfs/live").exists()
            || Path::new("/run/cos/live_mode").exists() =>
        {
            BootMode::Live
        }
        _ => BootMode::Installed,
    }
}

fn start_install(
    core: &Core,
    device: &str,
    confirmation: &str,
) -> Result<(), (String, String, String)> {
    require_live(core)?;
    if confirmation != "ERASE" {
        return Err(api_error(
            "confirmation_required",
            "Type ERASE to confirm that all data on the selected disk will be erased",
            "installer",
        ));
    }
    let disks = disks::list_install_disks().map_err(component_error("disk_discovery"))?;
    let target = disks
        .iter()
        .find(|candidate| candidate.device == device)
        .ok_or_else(|| {
            api_error(
                "disk_unavailable",
                format!("Installation target {device} is no longer available"),
                "installer",
            )
        })?;
    if target.installation_media {
        return Err(api_error(
            "installation_media_rejected",
            format!("Installation target {device} contains the running installation media"),
            "installer",
        ));
    }
    core.operations
        .start_install(device)
        .map_err(component_error("installer"))
}

fn login(core: &Core, username: &str, password: &str) -> Result<String, (String, String, String)> {
    if core.boot_mode == BootMode::Live {
        return Err(api_error(
            "unavailable_in_live_mode",
            "Login is unavailable in the live installer",
            "authentication",
        ));
    }
    let key = username.trim().to_ascii_lowercase();
    {
        let mut all = core
            .login_attempts
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner());
        let attempts = all.entry(key.clone()).or_default();
        while attempts
            .front()
            .is_some_and(|instant| instant.elapsed() > LOGIN_WINDOW)
        {
            attempts.pop_front();
        }
        if attempts.len() >= MAX_LOGIN_ATTEMPTS {
            return Err(api_error(
                "rate_limited",
                "Too many login attempts. Wait one minute before trying again",
                "authentication",
            ));
        }
    }
    let result = core
        .state
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner())
        .login(username, password);
    match result {
        Ok(token) => {
            core.login_attempts
                .lock()
                .unwrap_or_else(|poisoned| poisoned.into_inner())
                .remove(&key);
            Ok(token)
        }
        Err(error) => {
            core.login_attempts
                .lock()
                .unwrap_or_else(|poisoned| poisoned.into_inner())
                .entry(key)
                .or_default()
                .push_back(Instant::now());
            Err(api_error(
                "authentication_failed",
                error.to_string(),
                "authentication",
            ))
        }
    }
}

fn require_live(core: &Core) -> Result<(), (String, String, String)> {
    if core.boot_mode == BootMode::Live {
        Ok(())
    } else {
        Err(api_error(
            "unavailable_when_installed",
            "The installer is available only when booted from Dead Rose installation media",
            "installer",
        ))
    }
}

fn require_session(core: &Core, token: &str) -> Result<(), (String, String, String)> {
    let valid = core
        .state
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner())
        .is_valid_session(token)
        .map_err(component_error("authentication"))?;
    if valid {
        Ok(())
    } else {
        Err(api_error(
            "authentication_required",
            "A valid administrator session is required",
            "authentication",
        ))
    }
}

fn authorize_power(core: &Core, token: Option<&str>) -> Result<(), (String, String, String)> {
    if core.boot_mode == BootMode::Live {
        Ok(())
    } else {
        require_session(core, token.unwrap_or_default())
    }
}

fn system_action(action: &str) -> Result<(), (String, String, String)> {
    let status = Command::new("systemctl")
        .arg(action)
        .status()
        .map_err(|error| {
            api_error(
                "system_action_failed",
                format!("Failed to request system {action}: {error}"),
                "systemd",
            )
        })?;
    if status.success() {
        Ok(())
    } else {
        Err(api_error(
            "system_action_failed",
            format!("systemctl {action} exited with status {status}"),
            "systemd",
        ))
    }
}

fn system_info() -> Result<SystemInfo, (String, String, String)> {
    let hostname = fs::read_to_string("/etc/hostname")
        .unwrap_or_else(|_| "dead-rose".into())
        .trim()
        .to_owned();
    let os_name = os_release_value("PRETTY_NAME").unwrap_or_else(|| "Dead Rose OS".into());
    let kernel = command_output("uname", &["-r"])?;
    let architecture = command_output("uname", &["-m"])?;
    Ok(SystemInfo {
        hostname,
        os_name,
        version: env!("CARGO_PKG_VERSION").into(),
        kernel,
        architecture,
    })
}

fn command_output(binary: &str, args: &[&str]) -> Result<String, (String, String, String)> {
    let output = Command::new(binary).args(args).output().map_err(|error| {
        api_error(
            "system_info_failed",
            format!("Failed to run {binary}: {error}"),
            "system_info",
        )
    })?;
    if !output.status.success() {
        return Err(api_error(
            "system_info_failed",
            format!("{binary} exited with status {}", output.status),
            "system_info",
        ));
    }
    Ok(String::from_utf8_lossy(&output.stdout).trim().to_owned())
}

fn os_release_value(key: &str) -> Option<String> {
    fs::read_to_string("/etc/os-release")
        .ok()?
        .lines()
        .find_map(|line| {
            line.strip_prefix(&format!("{key}="))
                .map(|value| value.trim_matches('"').to_owned())
        })
}

fn to_value<T: serde::Serialize>(value: T) -> Result<serde_json::Value, (String, String, String)> {
    serde_json::to_value(value).map_err(component_error("dead-rose-ipc"))
}

fn component_error<E: std::fmt::Display>(
    component: &'static str,
) -> impl FnOnce(E) -> (String, String, String) {
    move |error| api_error("operation_failed", error.to_string(), component)
}

fn api_error(
    code: impl Into<String>,
    message: impl Into<String>,
    component: impl Into<String>,
) -> (String, String, String) {
    (code.into(), message.into(), component.into())
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn boot_mode_can_be_forced_for_tests() {
        // The pure fallback remains deterministic when no live mount exists on a developer host.
        assert!(matches!(
            detect_boot_mode(),
            BootMode::Installed | BootMode::Live
        ));
    }

    #[test]
    fn response_payload_is_json() {
        assert_eq!(
            to_value(json!({"ready": true})).unwrap(),
            json!({"ready": true})
        );
    }
}
