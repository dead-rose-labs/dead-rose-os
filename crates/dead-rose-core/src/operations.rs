use dead_rose_types::{OperationPhase, OperationStatus};
use std::fs::OpenOptions;
use std::io::{BufRead, BufReader, Write};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::{Arc, Mutex, mpsc};
use std::thread;
use thiserror::Error;

const APPROVED_UPDATE_REPOSITORY: &str = "ghcr.io/dead-rose-labs/dead-rose-os";

#[derive(Debug, Error)]
pub enum OperationError {
    #[error("another {0} operation is already running")]
    Busy(&'static str),
    #[error("update image must be a pinned tag from ghcr.io/dead-rose-labs/dead-rose-os")]
    InvalidImage,
    #[error("failed to create operation log: {0}")]
    Log(#[source] std::io::Error),
}

#[derive(Clone)]
pub struct OperationManager {
    install: Arc<Mutex<OperationStatus>>,
    upgrade: Arc<Mutex<OperationStatus>>,
    log_directory: PathBuf,
}

impl OperationManager {
    pub fn new(log_directory: impl Into<PathBuf>) -> Self {
        Self {
            install: Arc::new(Mutex::new(OperationStatus::default())),
            upgrade: Arc::new(Mutex::new(OperationStatus::default())),
            log_directory: log_directory.into(),
        }
    }

    pub fn install_status(&self) -> OperationStatus {
        self.install
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .clone()
    }

    pub fn upgrade_status(&self) -> OperationStatus {
        self.upgrade
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .clone()
    }

    pub fn start_install(&self, device: &str) -> Result<(), OperationError> {
        ensure_available(&self.install, "installation")?;
        std::fs::create_dir_all(&self.log_directory).map_err(OperationError::Log)?;
        let log = self.log_directory.join("installer.log");
        let binary = std::env::var("DEAD_ROSE_KAIROS_AGENT")
            .unwrap_or_else(|_| "/usr/bin/kairos-agent".into());
        let args = vec![
            "manual-install".to_owned(),
            "--device".to_owned(),
            device.to_owned(),
            "/etc/dead-rose/install.yaml".to_owned(),
        ];
        spawn_operation(self.install.clone(), binary, args, log, true)
    }

    pub fn start_upgrade(&self, image: &str) -> Result<(), OperationError> {
        if !valid_update_image(image) {
            return Err(OperationError::InvalidImage);
        }
        ensure_available(&self.upgrade, "upgrade")?;
        std::fs::create_dir_all(&self.log_directory).map_err(OperationError::Log)?;
        let log = self.log_directory.join("upgrade.log");
        let binary = std::env::var("DEAD_ROSE_KAIROS_AGENT")
            .unwrap_or_else(|_| "/usr/bin/kairos-agent".into());
        let args = vec![
            "upgrade".to_owned(),
            "--source".to_owned(),
            format!("oci:{image}"),
        ];
        spawn_operation(self.upgrade.clone(), binary, args, log, false)
    }
}

fn ensure_available(
    status: &Arc<Mutex<OperationStatus>>,
    name: &'static str,
) -> Result<(), OperationError> {
    let current = status
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner());
    if matches!(
        current.phase,
        OperationPhase::Preparing
            | OperationPhase::InstallingSystem
            | OperationPhase::ConfiguringBoot
            | OperationPhase::Finalizing
    ) {
        return Err(OperationError::Busy(name));
    }
    Ok(())
}

fn spawn_operation(
    status: Arc<Mutex<OperationStatus>>,
    binary: String,
    args: Vec<String>,
    log_path: PathBuf,
    detect_boot_stage: bool,
) -> Result<(), OperationError> {
    OpenOptions::new()
        .create(true)
        .append(true)
        .open(&log_path)
        .map_err(OperationError::Log)?;
    set_status(
        &status,
        OperationPhase::Preparing,
        "Preparing operation",
        None,
    );
    thread::spawn(move || {
        let result = run_command(&status, &binary, &args, &log_path, detect_boot_stage);
        match result {
            Ok(()) => set_status(
                &status,
                OperationPhase::Completed,
                "Operation completed",
                None,
            ),
            Err(message) => set_status(
                &status,
                OperationPhase::Failed,
                "Operation failed",
                Some(message),
            ),
        }
    });
    Ok(())
}

fn run_command(
    status: &Arc<Mutex<OperationStatus>>,
    binary: &str,
    args: &[String],
    log_path: &Path,
    detect_boot_stage: bool,
) -> Result<(), String> {
    let mut child = Command::new(binary)
        .args(args)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|error| format!("Failed to start {binary}: {error}"))?;
    set_status(
        status,
        OperationPhase::InstallingSystem,
        "Installing system",
        None,
    );

    let (sender, receiver) = mpsc::channel();
    if let Some(stream) = child.stdout.take() {
        let sender = sender.clone();
        thread::spawn(move || {
            for line in BufReader::new(stream).lines().map_while(Result::ok) {
                let _ = sender.send(line);
            }
        });
    }
    if let Some(stream) = child.stderr.take() {
        let sender = sender.clone();
        thread::spawn(move || {
            for line in BufReader::new(stream).lines().map_while(Result::ok) {
                let _ = sender.send(line);
            }
        });
    }
    drop(sender);
    let mut log = OpenOptions::new()
        .create(true)
        .append(true)
        .open(log_path)
        .map_err(|error| format!("Failed to open {}: {error}", log_path.display()))?;
    for line in receiver {
        writeln!(log, "{line}")
            .map_err(|error| format!("Failed to write {}: {error}", log_path.display()))?;
        let normalized = line.to_ascii_lowercase();
        if detect_boot_stage
            && (normalized.contains("bootloader")
                || normalized.contains("grub")
                || normalized.contains("efi"))
        {
            set_status(
                status,
                OperationPhase::ConfiguringBoot,
                "Configuring boot",
                None,
            );
        } else if normalized.contains("finaliz") || normalized.contains("sync") {
            set_status(status, OperationPhase::Finalizing, "Finalizing", None);
        }
    }
    let exit = child
        .wait()
        .map_err(|error| format!("Failed while waiting for {binary}: {error}"))?;
    if exit.success() {
        Ok(())
    } else {
        Err(format!(
            "{binary} exited with status {exit}; see {}",
            log_path.display()
        ))
    }
}

fn set_status(
    status: &Arc<Mutex<OperationStatus>>,
    phase: OperationPhase,
    detail: &str,
    error: Option<String>,
) {
    *status
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner()) = OperationStatus {
        phase,
        detail: detail.to_owned(),
        error,
    };
}

pub fn valid_update_image(image: &str) -> bool {
    let Some(tag) = image.strip_prefix(&format!("{APPROVED_UPDATE_REPOSITORY}:")) else {
        return false;
    };
    !tag.is_empty()
        && tag != "latest"
        && tag != "edge"
        && tag.len() <= 128
        && tag
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'.' | b'_' | b'-'))
}

#[cfg(test)]
mod tests {
    use super::valid_update_image;

    #[test]
    fn update_source_is_restricted_and_pinned() {
        assert!(valid_update_image(
            "ghcr.io/dead-rose-labs/dead-rose-os:0.1.1"
        ));
        assert!(!valid_update_image(
            "ghcr.io/dead-rose-labs/dead-rose-os:latest"
        ));
        assert!(!valid_update_image("docker.io/attacker/image:1"));
        assert!(!valid_update_image(
            "ghcr.io/dead-rose-labs/dead-rose-os:0.1.1;reboot"
        ));
    }
}
