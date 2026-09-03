use dead_rose_types::InstallDisk;
use serde::Deserialize;
use serde_json::Value;
use std::process::Command;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum DiskError {
    #[error("failed to run lsblk: {0}")]
    Launch(#[source] std::io::Error),
    #[error("lsblk failed with status {0}")]
    Command(String),
    #[error("failed to parse lsblk output: {0}")]
    Parse(#[from] serde_json::Error),
}

#[derive(Debug, Deserialize)]
struct Listing {
    blockdevices: Vec<BlockDevice>,
}

#[derive(Debug, Deserialize)]
struct BlockDevice {
    path: Option<String>,
    #[serde(rename = "type")]
    device_type: Option<String>,
    size: Option<Value>,
    model: Option<String>,
    rm: Option<Value>,
    ro: Option<Value>,
    tran: Option<String>,
    mountpoints: Option<Vec<Option<String>>>,
}

pub fn list_install_disks() -> Result<Vec<InstallDisk>, DiskError> {
    let output = Command::new("lsblk")
        .args([
            "--json",
            "--bytes",
            "--output",
            "PATH,TYPE,SIZE,MODEL,RM,RO,TRAN,MOUNTPOINTS",
        ])
        .output()
        .map_err(DiskError::Launch)?;
    if !output.status.success() {
        return Err(DiskError::Command(
            String::from_utf8_lossy(&output.stderr).trim().to_owned(),
        ));
    }
    parse_lsblk(&output.stdout)
}

fn parse_lsblk(bytes: &[u8]) -> Result<Vec<InstallDisk>, DiskError> {
    let listing: Listing = serde_json::from_slice(bytes)?;
    let mut disks = listing
        .blockdevices
        .into_iter()
        .filter_map(|device| {
            if device.device_type.as_deref() != Some("disk") || truthy(device.ro.as_ref()) {
                return None;
            }
            let path = device.path?;
            if !path.starts_with("/dev/") {
                return None;
            }
            let mountpoints = device.mountpoints.unwrap_or_default();
            let installation_media = mountpoints.iter().flatten().any(|mount| {
                mount.starts_with("/run/initramfs/live")
                    || mount.starts_with("/run/cos")
                    || mount == "/"
            });
            Some(InstallDisk {
                model: device
                    .model
                    .unwrap_or_else(|| "Unknown storage device".into())
                    .trim()
                    .to_owned(),
                device: path,
                size_bytes: number(device.size.as_ref()),
                kind: device
                    .tran
                    .filter(|value| !value.is_empty())
                    .unwrap_or_else(|| "internal".into()),
                removable: truthy(device.rm.as_ref()),
                installation_media,
            })
        })
        .collect::<Vec<_>>();
    disks.sort_by(|left, right| left.device.cmp(&right.device));
    Ok(disks)
}

fn truthy(value: Option<&Value>) -> bool {
    match value {
        Some(Value::Bool(value)) => *value,
        Some(Value::Number(value)) => value.as_u64().unwrap_or(0) != 0,
        Some(Value::String(value)) => value == "1" || value.eq_ignore_ascii_case("true"),
        _ => false,
    }
}

fn number(value: Option<&Value>) -> u64 {
    match value {
        Some(Value::Number(value)) => value.as_u64().unwrap_or(0),
        Some(Value::String(value)) => value.parse().unwrap_or(0),
        _ => 0,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn filters_non_disks_and_marks_live_media() {
        let input = br#"{"blockdevices":[
          {"path":"/dev/loop0","type":"loop","size":10,"model":null,"rm":false,"ro":true,"tran":null,"mountpoints":[null]},
          {"path":"/dev/sda","type":"disk","size":"1000","model":"System SSD ","rm":0,"ro":0,"tran":"sata","mountpoints":[null]},
          {"path":"/dev/sdb","type":"disk","size":2000,"model":"USB","rm":1,"ro":0,"tran":"usb","mountpoints":["/run/initramfs/live"]}
        ]}"#;
        let result = parse_lsblk(input).unwrap();
        assert_eq!(result.len(), 2);
        assert_eq!(result[0].model, "System SSD");
        assert!(result[1].installation_media);
    }
}
