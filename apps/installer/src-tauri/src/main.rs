use dead_rose_installer_core::{
    Disk, InstallerError, create_administrator, enumerate_disks as list_disks, validate_disk,
    verify_payload, write_image,
};
use serde::{Deserialize, Serialize};
use std::{
    env,
    path::{Path, PathBuf},
    process::Command,
    thread,
    time::Duration,
};

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct InstallRequest {
    device: PathBuf,
    hostname: String,
    username: String,
    password: String,
    confirmation: String,
}

#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct InstallEvent {
    phase: &'static str,
    message: &'static str,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct CommandError {
    code: &'static str,
    message: String,
}

fn failure(code: &'static str, message: impl Into<String>) -> CommandError {
    CommandError {
        code,
        message: message.into(),
    }
}

#[tauri::command]
fn enumerate_disks() -> Result<Vec<Disk>, CommandError> {
    list_disks().map_err(|error| failure("disk_enumeration_failed", error.to_string()))
}

#[tauri::command]
fn install(
    request: InstallRequest,
    progress: tauri::ipc::Channel<InstallEvent>,
) -> Result<(), CommandError> {
    if request.confirmation != "ERASE" {
        return Err(failure(
            "confirmation_required",
            "Explicit erase confirmation is required.",
        ));
    }
    if !is_valid_hostname(&request.hostname)
        || request.username.len() < 2
        || request.password.len() < 12
    {
        return Err(failure(
            "invalid_configuration",
            "Hostname or administrator details are invalid.",
        ));
    }
    let installer_media = PathBuf::from(
        env::var("DEAD_ROSE_INSTALLER_MEDIA")
            .unwrap_or_else(|_| "/dev/disk/by-label/DEAD_ROSE_INSTALLER".into()),
    );
    progress
        .send(InstallEvent {
            phase: "target_validation",
            message: "Validating the selected disk…",
        })
        .map_err(|error| failure("progress_channel_failed", error.to_string()))?;
    let disk = list_disks()
        .map_err(|error| failure("disk_enumeration_failed", error.to_string()))?
        .into_iter()
        .find(|disk| disk.device == request.device)
        .ok_or_else(|| {
            failure(
                "target_not_found",
                "The selected disk is no longer available.",
            )
        })?;
    validate_disk(&disk, &installer_media).map_err(|error| match error {
        InstallerError::DiskTooSmall => failure("disk_too_small", error.to_string()),
        InstallerError::InstallerMedia => failure("installer_media_selected", error.to_string()),
        _ => failure("target_validation_failed", error.to_string()),
    })?;
    let payload = PathBuf::from(
        env::var("DEAD_ROSE_PAYLOAD")
            .unwrap_or_else(|_| "/usr/lib/dead-rose-installer/dead-rose-os.raw".into()),
    );
    let digest_path = payload.with_extension("raw.sha256");
    progress
        .send(InstallEvent {
            phase: "payload_verification",
            message: "Verifying the operating-system payload…",
        })
        .map_err(|error| failure("progress_channel_failed", error.to_string()))?;
    let expected = std::fs::read_to_string(digest_path)
        .map_err(|error| failure("manifest_unavailable", error.to_string()))?
        .split_whitespace()
        .next()
        .ok_or_else(|| failure("invalid_manifest", "The release manifest is empty."))?
        .to_owned();
    verify_payload(&payload, &expected)
        .map_err(|error| failure("payload_verification_failed", error.to_string()))?;
    progress
        .send(InstallEvent {
            phase: "image_write",
            message: "Writing and synchronizing Dead Rose OS…",
        })
        .map_err(|error| failure("progress_channel_failed", error.to_string()))?;
    write_image(&payload, &request.device)
        .map_err(|error| failure("image_write_failed", error.to_string()))?;
    let state_root = PathBuf::from(
        env::var("DEAD_ROSE_STATE_MOUNT")
            .unwrap_or_else(|_| "/run/dead-rose-installer/state".into()),
    );
    let _ = Command::new("partprobe").arg(&request.device).status();
    let state_device = Path::new("/dev/disk/by-partlabel/STATE");
    for _ in 0..50 {
        if state_device.exists() {
            break;
        }
        thread::sleep(Duration::from_millis(100));
    }
    progress
        .send(InstallEvent {
            phase: "state_initialization",
            message: "Initializing persistent system state…",
        })
        .map_err(|error| failure("progress_channel_failed", error.to_string()))?;
    std::fs::create_dir_all(&state_root)
        .map_err(|error| failure("state_initialization_failed", error.to_string()))?;
    mount_state(state_device, &state_root)
        .map_err(|error| failure("state_initialization_failed", error))?;
    progress
        .send(InstallEvent {
            phase: "administrator_creation",
            message: "Creating the Dead Rose administrator…",
        })
        .map_err(|error| failure("progress_channel_failed", error.to_string()))?;
    create_administrator(&state_root, &request.username, request.password.as_bytes())
        .map_err(|error| failure("administrator_creation_failed", error.to_string()))?;
    progress
        .send(InstallEvent {
            phase: "system_identity",
            message: "Applying the system identity…",
        })
        .map_err(|error| failure("progress_channel_failed", error.to_string()))?;
    std::fs::write(
        state_root.join("hostname"),
        format!("{}\n", request.hostname),
    )
    .map_err(|error| failure("hostname_configuration_failed", error.to_string()))?;
    unmount_state(&state_root).map_err(|error| failure("state_sync_failed", error))?;
    progress
        .send(InstallEvent {
            phase: "complete",
            message: "Installation complete.",
        })
        .map_err(|error| failure("progress_channel_failed", error.to_string()))?;
    Ok(())
}

fn is_valid_hostname(value: &str) -> bool {
    !value.is_empty()
        && value.len() <= 63
        && !value.starts_with('-')
        && !value.ends_with('-')
        && value
            .bytes()
            .all(|byte| byte.is_ascii_lowercase() || byte.is_ascii_digit() || byte == b'-')
}

#[tauri::command]
fn restart() -> Result<(), CommandError> {
    restart_system().map_err(|error| failure("restart_failed", error))
}

#[cfg(target_os = "linux")]
fn mount_state(source: &Path, target: &Path) -> Result<(), String> {
    use nix::mount::{MsFlags, mount};
    mount(
        Some(source),
        target,
        Some("ext4"),
        MsFlags::MS_NODEV | MsFlags::MS_NOSUID,
        None::<&str>,
    )
    .map_err(|error| error.to_string())
}

#[cfg(not(target_os = "linux"))]
fn mount_state(_: &Path, _: &Path) -> Result<(), String> {
    Err("installer_requires_linux".into())
}

#[cfg(target_os = "linux")]
fn unmount_state(target: &Path) -> Result<(), String> {
    nix::mount::umount(target).map_err(|error| error.to_string())
}

#[cfg(not(target_os = "linux"))]
fn unmount_state(_: &Path) -> Result<(), String> {
    Err("installer_requires_linux".into())
}

#[cfg(target_os = "linux")]
fn restart_system() -> Result<(), String> {
    use nix::sys::reboot::{RebootMode, reboot};
    reboot(RebootMode::RB_AUTOBOOT)
        .map(|_| ())
        .map_err(|error| error.to_string())
}

#[cfg(not(target_os = "linux"))]
fn restart_system() -> Result<(), String> {
    Err("restart_requires_linux".into())
}

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![enumerate_disks, install, restart])
        .run(tauri::generate_context!())
        .expect("Dead Rose installer failed to start");
}
