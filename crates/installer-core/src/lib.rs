use dead_rose_auth::{AuthError, CredentialStore};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::{
    fs::{File, OpenOptions},
    io::{self, BufReader, BufWriter, Read, Write},
    path::{Path, PathBuf},
};
use thiserror::Error;

pub const MINIMUM_DISK_BYTES: u64 = 32 * 1024 * 1024 * 1024;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct Disk {
    pub device: PathBuf,
    pub model: String,
    pub size_bytes: u64,
    pub removable: bool,
}

#[derive(Debug, Error)]
pub enum InstallerError {
    #[error("disk is too small; at least 32 GiB is required")]
    DiskTooSmall,
    #[error("installer media cannot be selected as a target")]
    InstallerMedia,
    #[error("payload digest does not match the release manifest")]
    InvalidPayload,
    #[error("target is not a whole block device")]
    InvalidTarget,
    #[error("I/O error: {0}")]
    Io(#[from] io::Error),
    #[error("administrator creation failed: {0}")]
    Auth(#[from] AuthError),
}

pub fn validate_disk(disk: &Disk, installer_media: &Path) -> Result<(), InstallerError> {
    if disk.device == installer_media {
        return Err(InstallerError::InstallerMedia);
    }
    if disk.size_bytes < MINIMUM_DISK_BYTES {
        return Err(InstallerError::DiskTooSmall);
    }
    Ok(())
}

pub fn verify_payload(path: &Path, expected_sha256: &str) -> Result<(), InstallerError> {
    let mut reader = BufReader::new(File::open(path)?);
    let mut digest = Sha256::new();
    let mut buffer = [0u8; 1024 * 1024];
    loop {
        let count = reader.read(&mut buffer)?;
        if count == 0 {
            break;
        }
        digest.update(&buffer[..count]);
    }
    if format!("{:x}", digest.finalize()).eq_ignore_ascii_case(expected_sha256.trim()) {
        Ok(())
    } else {
        Err(InstallerError::InvalidPayload)
    }
}

pub fn write_image(payload: &Path, target: &Path) -> Result<(), InstallerError> {
    let mut source = BufReader::new(File::open(payload)?);
    let target_file = OpenOptions::new().write(true).open(target)?;
    let mut destination = BufWriter::new(target_file);
    io::copy(&mut source, &mut destination)?;
    destination.flush()?;
    destination.get_ref().sync_all()?;
    Ok(())
}

pub fn create_administrator(
    state_root: &Path,
    username: &str,
    password: &[u8],
) -> Result<(), InstallerError> {
    let mut store = CredentialStore::load(state_root.join("auth/accounts.json"))?;
    store.upsert(username, password)?;
    Ok(())
}

#[cfg(target_os = "linux")]
pub fn enumerate_disks() -> Result<Vec<Disk>, InstallerError> {
    let mut disks = Vec::new();
    for entry in std::fs::read_dir("/sys/block")? {
        let entry = entry?;
        let name = entry.file_name();
        let name = name.to_string_lossy();
        if name.starts_with("loop") || name.starts_with("ram") || name.starts_with("sr") {
            continue;
        }
        let root = entry.path();
        let sectors: u64 = std::fs::read_to_string(root.join("size"))?
            .trim()
            .parse()
            .map_err(|_| InstallerError::InvalidTarget)?;
        let model = std::fs::read_to_string(root.join("device/model"))
            .unwrap_or_else(|_| "Unknown disk".into())
            .trim()
            .to_owned();
        let removable = std::fs::read_to_string(root.join("removable"))
            .unwrap_or_default()
            .trim()
            == "1";
        disks.push(Disk {
            device: PathBuf::from("/dev").join(name.as_ref()),
            model,
            size_bytes: sectors.saturating_mul(512),
            removable,
        });
    }
    Ok(disks)
}

#[cfg(not(target_os = "linux"))]
pub fn enumerate_disks() -> Result<Vec<Disk>, InstallerError> {
    Ok(Vec::new())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    #[test]
    fn rejects_small_disk_and_installer_media() {
        let disk = Disk {
            device: "/dev/test".into(),
            model: "Disposable".into(),
            size_bytes: MINIMUM_DISK_BYTES - 1,
            removable: false,
        };
        assert!(matches!(
            validate_disk(&disk, Path::new("/dev/iso")),
            Err(InstallerError::DiskTooSmall)
        ));
        let disk = Disk {
            size_bytes: MINIMUM_DISK_BYTES,
            ..disk
        };
        assert!(matches!(
            validate_disk(&disk, Path::new("/dev/test")),
            Err(InstallerError::InstallerMedia)
        ));
    }
    #[test]
    fn accepts_valid_payload_and_rejects_tampering() {
        let dir = tempfile::tempdir().unwrap();
        let payload = dir.path().join("os.raw");
        fs::write(&payload, b"dead rose").unwrap();
        let digest = format!("{:x}", Sha256::digest(b"dead rose"));
        assert!(verify_payload(&payload, &digest).is_ok());
        assert!(matches!(
            verify_payload(&payload, &"0".repeat(64)),
            Err(InstallerError::InvalidPayload)
        ));
    }
    #[test]
    fn creates_administrator_credentials() {
        let dir = tempfile::tempdir().unwrap();
        create_administrator(dir.path(), "admin", b"a-long-test-password").unwrap();
        let store = CredentialStore::load(dir.path().join("auth/accounts.json")).unwrap();
        assert!(store.authenticate("admin", b"a-long-test-password").is_ok());
    }
}
