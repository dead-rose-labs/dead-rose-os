use dead_rose_installer_core::{
    InstallerError, create_administrator, enumerate_disks, validate_disk, verify_payload,
};
use dead_rose_system_types::{INSTALLER_SOCKET, InstallDisk, InstallerRequest, InstallerResponse};
use std::{
    env, fs, io,
    os::unix::fs::FileTypeExt,
    path::{Path, PathBuf},
    process::{Command, Stdio},
    sync::Arc,
    time::Duration,
};
use tokio::{
    io::{AsyncBufReadExt, AsyncReadExt, AsyncWriteExt, BufReader, WriteHalf},
    net::{UnixListener, UnixStream},
    sync::Mutex,
};
use tracing::{error, info, warn};

const MAX_REQUEST_BYTES: u64 = 64 * 1024;
const REQUEST_TIMEOUT: Duration = Duration::from_secs(10);
const EFI_PARTITION_BYTES: u64 = 512 * 1024 * 1024;
const GPT_ALIGNMENT_RESERVE_BYTES: u64 = 2 * 1024 * 1024;

#[tokio::main]
async fn main() -> io::Result<()> {
    init_logging();
    let socket =
        env::var("DEAD_ROSE_INSTALLER_SOCKET").unwrap_or_else(|_| INSTALLER_SOCKET.to_owned());
    if let Some(parent) = Path::new(&socket).parent() {
        fs::create_dir_all(parent)?;
    }
    if Path::new(&socket).exists() {
        fs::remove_file(&socket)?;
    }
    let listener = UnixListener::bind(&socket)?;
    let install_lock = Arc::new(Mutex::new(()));
    info!(socket, "Dead Rose installer backend ready");
    loop {
        let (stream, _) = listener.accept().await?;
        let install_lock = install_lock.clone();
        tokio::spawn(async move {
            if let Err(error) = serve(stream, install_lock).await {
                error!(%error, "installer IPC request failed");
            }
        });
    }
}

fn init_logging() {
    if let Ok(layer) = tracing_journald::layer() {
        use tracing_subscriber::prelude::*;
        let _ = tracing_subscriber::registry().with(layer).try_init();
    } else {
        let _ = tracing_subscriber::fmt().with_target(false).try_init();
    }
}

async fn serve(stream: UnixStream, install_lock: Arc<Mutex<()>>) -> io::Result<()> {
    let (read, mut write) = tokio::io::split(stream);
    let mut line = String::new();
    let read_result = tokio::time::timeout(
        REQUEST_TIMEOUT,
        BufReader::new(read)
            .take(MAX_REQUEST_BYTES)
            .read_line(&mut line),
    )
    .await;
    match read_result {
        Ok(Ok(_)) if line.ends_with('\n') => {}
        Ok(Ok(_)) => {
            return send_error(
                &mut write,
                "malformed_request",
                "The installer request is incomplete or too large.",
            )
            .await;
        }
        Ok(Err(error)) => return Err(error),
        Err(_) => {
            return send_error(
                &mut write,
                "request_timeout",
                "The installer request timed out.",
            )
            .await;
        }
    }
    let request = match serde_json::from_str::<InstallerRequest>(&line) {
        Ok(request) => request,
        Err(_) => {
            return send_error(
                &mut write,
                "malformed_request",
                "The installer request is malformed.",
            )
            .await;
        }
    };
    match request {
        InstallerRequest::EnumerateDisks => {
            let Some(installer_media) = installer_media_disk() else {
                return send_error(
                    &mut write,
                    "installer_media_unavailable",
                    "The installer boot media identity is unavailable.",
                )
                .await;
            };
            match enumerate_disks() {
                Ok(mut disks) => {
                    disks.retain(|disk| disk.device != installer_media);
                    send(&mut write, &InstallerResponse::Disks { disks }).await
                }
                Err(error) => {
                    send_error(&mut write, "disk_enumeration_failed", &error.to_string()).await
                }
            }
        }
        InstallerRequest::Install {
            stable_id,
            hostname,
            username,
            password,
            confirmation,
        } => {
            let Ok(_guard) = install_lock.try_lock() else {
                return send_error(
                    &mut write,
                    "installation_in_progress",
                    "Another installation is already in progress.",
                )
                .await;
            };
            let result = install(
                &mut write,
                stable_id,
                hostname,
                username,
                password,
                confirmation,
            )
            .await;
            if let Err((code, message)) = result {
                send_error(&mut write, code, &message).await
            } else {
                send(&mut write, &InstallerResponse::Complete).await
            }
        }
        InstallerRequest::Restart => {
            send(&mut write, &InstallerResponse::Restarting).await?;
            write.shutdown().await?;
            restart_system().map_err(io::Error::other)
        }
    }
}

async fn install(
    write: &mut WriteHalf<UnixStream>,
    stable_id: PathBuf,
    hostname: String,
    username: String,
    password: String,
    confirmation: String,
) -> Result<(), (&'static str, String)> {
    if confirmation != "ERASE" {
        return Err((
            "confirmation_required",
            "Explicit erase confirmation is required.".into(),
        ));
    }
    if !is_valid_hostname(&hostname)
        || !is_valid_username(&username)
        || !(12..=1024).contains(&password.len())
    {
        return Err((
            "invalid_configuration",
            "Hostname or administrator details are invalid.".into(),
        ));
    }
    progress(write, "target_validation", "Validating the selected disk…").await?;
    let disks =
        enumerate_disks().map_err(|error| ("disk_enumeration_failed", error.to_string()))?;
    let disk = disks
        .into_iter()
        .find(|disk| disk.stable_id == stable_id)
        .ok_or_else(|| {
            (
                "target_not_found",
                "The selected disk is no longer available.".into(),
            )
        })?;
    let media = installer_media_disk().ok_or_else(|| {
        (
            "installer_media_unavailable",
            "The installer boot media identity is unavailable.".into(),
        )
    })?;
    validate_disk(&disk, &media).map_err(map_validation_error)?;
    validate_stable_id(&disk)?;

    let payload = PathBuf::from(
        env::var("DEAD_ROSE_PAYLOAD")
            .unwrap_or_else(|_| "/usr/lib/dead-rose-installer/dead-rose-os.rootfs.tar.gz".into()),
    );
    let digest_path = checksum_path(&payload);
    progress(
        write,
        "payload_verification",
        "Verifying the operating-system payload…",
    )
    .await?;
    let expected = fs::read_to_string(&digest_path)
        .map_err(|error| ("manifest_unavailable", error.to_string()))?
        .split_whitespace()
        .next()
        .ok_or_else(|| ("invalid_manifest", "The release manifest is empty.".into()))?
        .to_owned();
    verify_payload(&payload, &expected)
        .map_err(|error| ("payload_verification_failed", error.to_string()))?;

    progress(
        write,
        "system_installation",
        "Creating the Ubuntu filesystem and installing Dead Rose OS…",
    )
    .await?;
    run_curtin(&disk, &payload)
        .map_err(|error| ("installation_engine_failed", error.to_string()))?;
    refresh_partition_table(&disk)
        .map_err(|error| ("partition_table_refresh_failed", error.to_string()))?;

    progress(
        write,
        "state_initialization",
        "Initializing persistent system state…",
    )
    .await?;
    let root_device = wait_for_partition(&disk.device, "ROOT").ok_or_else(|| {
        (
            "root_partition_missing",
            "The installed ROOT partition was not found.".into(),
        )
    })?;
    let target_root = PathBuf::from(
        env::var("DEAD_ROSE_TARGET_MOUNT")
            .unwrap_or_else(|_| "/run/dead-rose-installer/target".into()),
    );
    fs::create_dir_all(&target_root)
        .map_err(|error| ("state_initialization_failed", error.to_string()))?;
    mount_root(&root_device, &target_root)
        .map_err(|error| ("state_initialization_failed", error))?;

    let state_root = target_root.join("var/lib/dead-rose");
    let state_result = match fs::create_dir_all(&state_root) {
        Ok(()) => initialize_state(write, &state_root, &hostname, &username, &password).await,
        Err(error) => Err(("state_initialization_failed", error.to_string())),
    };
    let unmount_result = unmount_root(&target_root);
    state_result?;
    unmount_result.map_err(|error| ("state_sync_failed", error))?;
    Ok(())
}

async fn initialize_state(
    write: &mut WriteHalf<UnixStream>,
    state_root: &Path,
    hostname: &str,
    username: &str,
    password: &str,
) -> Result<(), (&'static str, String)> {
    progress(
        write,
        "administrator_creation",
        "Creating the Dead Rose administrator…",
    )
    .await?;
    create_administrator(state_root, username, password.as_bytes())
        .map_err(|error| ("administrator_creation_failed", error.to_string()))?;
    progress(write, "system_identity", "Applying the system identity…").await?;
    fs::write(state_root.join("hostname"), format!("{hostname}\n"))
        .map_err(|error| ("hostname_configuration_failed", error.to_string()))?;
    Ok(())
}

fn run_curtin(disk: &InstallDisk, payload: &Path) -> io::Result<()> {
    let runtime = Path::new("/run/dead-rose-installer");
    fs::create_dir_all(runtime)?;
    let config = runtime.join("curtin.yaml");
    fs::write(&config, curtin_config(disk, payload)?)?;
    fs::create_dir_all("/var/log/dead-rose-installer")?;
    let status = Command::new("/usr/bin/curtin")
        .args(["-v", "install", "--config"])
        .arg(&config)
        .stdin(Stdio::null())
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit())
        .status()?;
    if status.success() {
        Ok(())
    } else {
        Err(io::Error::other(format!("curtin exited with {status}")))
    }
}

fn refresh_partition_table(disk: &InstallDisk) -> io::Result<()> {
    let partprobe = Command::new("/usr/sbin/partprobe")
        .arg(&disk.stable_id)
        .stdin(Stdio::null())
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit())
        .status()?;
    if !partprobe.success() {
        return Err(io::Error::other(format!(
            "partprobe exited with {partprobe}"
        )));
    }

    let settle = Command::new("/usr/bin/udevadm")
        .args(["settle", "--timeout=30"])
        .stdin(Stdio::null())
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit())
        .status()?;
    if settle.success() {
        Ok(())
    } else {
        Err(io::Error::other(format!(
            "udevadm settle exited with {settle}"
        )))
    }
}

fn curtin_config(disk: &InstallDisk, payload: &Path) -> io::Result<String> {
    let disk_yaml = serde_json::to_string(&disk.stable_id)?;
    let payload_uri = format!("file://{}", payload.display());
    let payload_yaml = serde_json::to_string(&payload_uri)?;
    let root_size = disk
        .size_bytes
        .checked_sub(EFI_PARTITION_BYTES + GPT_ALIGNMENT_RESERVE_BYTES)
        .ok_or_else(|| io::Error::other("target disk cannot contain EFI and ROOT"))?;
    Ok(format!(
        "storage:\n  version: 2\n  config:\n    - id: dead_rose_disk\n      type: disk\n      path: {disk_yaml}\n      ptable: gpt\n      wipe: superblock-recursive\n      grub_device: true\n    - id: efi_partition\n      type: partition\n      device: dead_rose_disk\n      number: 1\n      size: {EFI_PARTITION_BYTES}B\n      flag: boot\n      partition_name: EFI\n      wipe: superblock\n    - id: root_partition\n      type: partition\n      device: dead_rose_disk\n      number: 2\n      size: {root_size}B\n      partition_name: ROOT\n      wipe: superblock\n    - id: efi_format\n      type: format\n      volume: efi_partition\n      fstype: fat32\n      label: EFI\n    - id: root_format\n      type: format\n      volume: root_partition\n      fstype: ext4\n      label: ROOT\n    - id: root_mount\n      type: mount\n      device: root_format\n      path: /\n    - id: efi_mount\n      type: mount\n      device: efi_format\n      path: /boot/efi\nsources:\n  dead_rose_rootfs:\n    type: tgz\n    uri: {payload_yaml}\ninstall:\n  log_file: /var/log/dead-rose-installer/curtin.log\n  error_tarfile: /var/log/dead-rose-installer/curtin-error.tar\n"
    ))
}

fn checksum_path(payload: &Path) -> PathBuf {
    let mut path = payload.as_os_str().to_os_string();
    path.push(".sha256");
    path.into()
}

fn validate_stable_id(disk: &InstallDisk) -> Result<(), (&'static str, String)> {
    if !has_stable_id_shape(disk) {
        return Err((
            "stable_disk_identity_missing",
            "The selected disk has no stable /dev/disk/by-id identity.".into(),
        ));
    }
    let resolved_id = fs::canonicalize(&disk.stable_id).map_err(|_| {
        (
            "target_not_found",
            "The selected stable disk identity no longer resolves.".into(),
        )
    })?;
    let resolved_device = fs::canonicalize(&disk.device).map_err(|_| {
        (
            "target_not_found",
            "The selected disk device no longer resolves.".into(),
        )
    })?;
    if resolved_id != resolved_device
        || !fs::metadata(&resolved_device)
            .map(|metadata| metadata.file_type().is_block_device())
            .unwrap_or(false)
    {
        return Err((
            "stable_disk_identity_changed",
            "The selected disk identity changed before installation.".into(),
        ));
    }
    Ok(())
}

fn has_stable_id_shape(disk: &InstallDisk) -> bool {
    disk.stable_id.starts_with("/dev/disk/by-id") && disk.stable_id != disk.device
}

fn installer_media_disk() -> Option<PathBuf> {
    let media = env::var("DEAD_ROSE_INSTALLER_MEDIA")
        .unwrap_or_else(|_| "/dev/disk/by-label/DEAD_ROSE_INSTALLER".into());
    parent_disk(Path::new(&media))
}

fn parent_disk(path: &Path) -> Option<PathBuf> {
    let canonical = fs::canonicalize(path).ok()?;
    let name = canonical.file_name()?.to_str()?;
    let sys_path = fs::canonicalize(Path::new("/sys/class/block").join(name)).ok()?;
    if sys_path.join("partition").exists() {
        let parent = sys_path.parent()?.file_name()?.to_str()?;
        Some(PathBuf::from("/dev").join(parent))
    } else {
        Some(canonical)
    }
}

fn wait_for_partition(device: &Path, partition_name: &str) -> Option<PathBuf> {
    for _ in 0..100 {
        if let Some(path) = named_partition(device, partition_name) {
            return Some(path);
        }
        std::thread::sleep(Duration::from_millis(100));
    }
    None
}

fn named_partition(device: &Path, partition_name: &str) -> Option<PathBuf> {
    let canonical = fs::canonicalize(device).ok()?;
    let name = canonical.file_name()?.to_str()?;
    let sys_path = fs::canonicalize(Path::new("/sys/class/block").join(name)).ok()?;
    for entry in fs::read_dir(sys_path).ok()?.filter_map(Result::ok) {
        if !entry.path().join("partition").exists() {
            continue;
        }
        let Ok(uevent) = fs::read_to_string(entry.path().join("uevent")) else {
            continue;
        };
        if uevent
            .lines()
            .any(|line| line.strip_prefix("PARTNAME=") == Some(partition_name))
        {
            return Some(PathBuf::from("/dev").join(entry.file_name()));
        }
    }
    None
}

fn map_validation_error(error: InstallerError) -> (&'static str, String) {
    let code = match error {
        InstallerError::DiskTooSmall => "disk_too_small",
        InstallerError::InstallerMedia => "installer_media_selected",
        _ => "target_validation_failed",
    };
    (code, error.to_string())
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

fn is_valid_username(value: &str) -> bool {
    (2..=32).contains(&value.len())
        && value
            .bytes()
            .next()
            .is_some_and(|byte| byte.is_ascii_lowercase() || byte == b'_')
        && value.bytes().all(|byte| {
            byte.is_ascii_lowercase() || byte.is_ascii_digit() || byte == b'_' || byte == b'-'
        })
}

async fn progress(
    write: &mut WriteHalf<UnixStream>,
    phase: &str,
    message: &str,
) -> Result<(), (&'static str, String)> {
    send(
        write,
        &InstallerResponse::Progress {
            phase: phase.into(),
            message: message.into(),
        },
    )
    .await
    .map_err(|error| ("progress_channel_failed", error.to_string()))
}

async fn send(write: &mut WriteHalf<UnixStream>, response: &InstallerResponse) -> io::Result<()> {
    write.write_all(&serde_json::to_vec(response)?).await?;
    write.write_all(b"\n").await
}

async fn send_error(
    write: &mut WriteHalf<UnixStream>,
    code: &str,
    message: &str,
) -> io::Result<()> {
    warn!(code, "installer operation failed");
    send(
        write,
        &InstallerResponse::Error {
            code: code.into(),
            message: message.into(),
        },
    )
    .await
}

#[cfg(target_os = "linux")]
fn mount_root(source: &Path, target: &Path) -> Result<(), String> {
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
fn mount_root(_: &Path, _: &Path) -> Result<(), String> {
    Err("installer_requires_linux".into())
}

#[cfg(target_os = "linux")]
fn unmount_root(target: &Path) -> Result<(), String> {
    nix::mount::umount(target).map_err(|error| error.to_string())
}

#[cfg(not(target_os = "linux"))]
fn unmount_root(_: &Path) -> Result<(), String> {
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

#[cfg(test)]
mod tests {
    use super::{
        checksum_path, curtin_config, has_stable_id_shape, is_valid_hostname, is_valid_username,
    };
    use dead_rose_system_types::InstallDisk;
    use std::path::Path;

    #[test]
    fn accepts_only_safe_hostnames() {
        assert!(is_valid_hostname("dead-rose-01"));
        assert!(!is_valid_hostname("DeadRose"));
        assert!(!is_valid_hostname("dead_rose"));
        assert!(!is_valid_hostname("-deadrose"));
    }

    #[test]
    fn requires_a_stable_disk_identity() {
        let mut disk = InstallDisk {
            device: "/dev/vda".into(),
            stable_id: "/dev/vda".into(),
            model: "test".into(),
            size_bytes: 40 * 1024 * 1024 * 1024,
            removable: false,
        };
        assert!(!has_stable_id_shape(&disk));
        disk.stable_id = "/dev/disk/by-id/virtio-test".into();
        assert!(has_stable_id_shape(&disk));
    }

    #[test]
    fn accepts_only_safe_usernames() {
        assert!(is_valid_username("deadrose_admin"));
        assert!(!is_valid_username("Root"));
        assert!(!is_valid_username("1admin"));
        assert!(!is_valid_username("a"));
    }

    #[test]
    fn generates_standard_curtin_filesystem_config() {
        let disk = InstallDisk {
            device: "/dev/vda".into(),
            stable_id: "/dev/disk/by-id/virtio-test".into(),
            model: "test".into(),
            size_bytes: 40 * 1024 * 1024 * 1024,
            removable: false,
        };
        let config = curtin_config(&disk, Path::new("/payload/rootfs.tar.gz")).unwrap();
        assert!(config.contains("version: 2"));
        assert!(config.contains("ptable: gpt"));
        assert!(config.contains("partition_name: EFI"));
        assert!(config.contains("partition_name: ROOT"));
        assert!(config.contains("fstype: ext4"));
        assert!(config.contains("type: tgz"));
        assert!(config.contains("uri: \"file:///payload/rootfs.tar.gz\""));
        assert!(config.contains("path: \"/dev/disk/by-id/virtio-test\""));
        assert!(!config.contains("STATE"));
    }

    #[test]
    fn keeps_the_rootfs_suffix_in_the_checksum_path() {
        assert_eq!(
            checksum_path(Path::new("/payload/rootfs.tar.gz")),
            Path::new("/payload/rootfs.tar.gz.sha256")
        );
    }
}
