use dead_rose_types::InstallerLog;
use std::collections::VecDeque;
use std::fs::OpenOptions;
use std::io::{BufRead, BufReader, Read};
use std::os::unix::fs::OpenOptionsExt;
use std::path::Path;

const MAX_SOURCE_BYTES: u64 = 8 * 1024 * 1024;
const MAX_LINES: usize = 200;
// Even worst-case JSON escaping fits the existing 64 KiB IPC frame.
const MAX_TEXT_BYTES: usize = 8 * 1024;

pub fn read(directory: &Path) -> Result<InstallerLog, String> {
    let file = OpenOptions::new()
        .read(true)
        .custom_flags(libc::O_NOFOLLOW | libc::O_NONBLOCK)
        .open(directory.join("installer.log"))
        .map_err(|_| "Installation log is not available yet".to_owned())?;
    let metadata = file
        .metadata()
        .map_err(|_| "Cannot inspect installation log")?;
    if !metadata.is_file() || metadata.len() > MAX_SOURCE_BYTES {
        return Err("Installation log exceeds the safe preview limit".into());
    }
    // Scan from the beginning to retain redaction context across the tail boundary.
    let mut source = Vec::new();
    file.take(MAX_SOURCE_BYTES + 1)
        .read_to_end(&mut source)
        .map_err(|_| "Cannot read installation log")?;
    if source.len() as u64 > MAX_SOURCE_BYTES {
        return Err("Installation log exceeds the safe preview limit".into());
    }
    Ok(sanitize(&source))
}

fn sanitize(source: &[u8]) -> InstallerLog {
    let mut lines = VecDeque::new();
    let mut bytes = 0;
    let mut truncated = false;
    let mut redacted = false;
    let mut sensitive_indent = None;
    let mut private_key = false;
    for raw in BufReader::new(source).split(b'\n').flatten() {
        let line: String = String::from_utf8_lossy(&raw)
            .chars()
            .filter(|c| !c.is_control() || *c == '\t')
            .collect();
        let lower = line.to_ascii_lowercase();
        let indent = line.len() - line.trim_start().len();
        let continuation =
            sensitive_indent.is_some_and(|level| indent > level || line.trim().is_empty());
        if !continuation {
            sensitive_indent = None;
        }
        let sensitive = [
            "password",
            "passwd",
            "passphrase",
            "token",
            "secret",
            "credential",
            "auth",
            "key",
            "config:",
            "configuration:",
            "user-data:",
            "userdata:",
            "cookie",
        ]
        .iter()
        .any(|word| lower.contains(word))
            || raw.contains(&0x1b)
            || (lower.contains("://") && (lower.contains('@') || lower.contains('?')))
            || line
                .split(|c: char| !c.is_ascii_alphanumeric() && c != '_' && c != '-' && c != '.')
                .any(|word| word.len() >= 40 && word.chars().any(|c| c.is_ascii_digit()));
        if lower.contains("-----begin") {
            private_key = true;
        }
        let hide = sensitive || continuation || private_key;
        if sensitive {
            sensitive_indent = Some(indent);
        }
        if lower.contains("-----end") {
            private_key = false;
        }
        let safe = if hide {
            redacted = true;
            "[sensitive log content redacted]".to_owned()
        } else if line.len() > MAX_TEXT_BYTES {
            truncated = true;
            "[oversized log line omitted]".to_owned()
        } else {
            line
        };
        bytes += safe.len() + 1;
        lines.push_back(safe);
        while lines.len() > MAX_LINES || bytes > MAX_TEXT_BYTES {
            bytes -= lines.pop_front().unwrap().len() + 1;
            truncated = true;
        }
    }
    InstallerLog {
        text: lines.into_iter().collect::<Vec<_>>().join("\n"),
        truncated,
        redacted,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn keeps_real_failure_and_bounds_wire_response() {
        let input = format!(
            "{}rsync: write failed: No space left on device (28)\n",
            "copying files\n".repeat(400)
        );
        let log = sanitize(input.as_bytes());
        assert!(log.text.contains("No space left on device (28)"));
        assert!(log.text.lines().count() <= MAX_LINES);
        assert!(log.truncated);
        assert!(serde_json::to_vec(&log).unwrap().len() < 60 * 1024);
    }

    #[test]
    fn redacts_secrets_and_multiline_values_before_taking_tail() {
        let input = format!(
            "password: |\n{}\ntoken=hidden-token\nhttps://user:password@example.test\n-----BEGIN PRIVATE KEY-----\nprivate-material\n-----END PRIVATE KEY-----\ninstaller exited 1",
            "  hidden-value\n".repeat(250)
        );
        let log = sanitize(input.as_bytes());
        for secret in [
            "hidden-value",
            "hidden-token",
            "private-material",
            "user:password",
        ] {
            assert!(!log.text.contains(secret));
        }
        assert!(log.redacted);
        assert!(log.text.contains("installer exited 1"));
    }

    #[test]
    fn byte_limit_handles_large_lines_and_invalid_utf8() {
        let input = [
            vec![b'x'; 20_000],
            vec![b'\n'],
            vec![0xff; 20_000],
            vec![b'\n'],
            b"installer exited 1".to_vec(),
        ]
        .concat();
        let log = sanitize(&input);
        assert!(log.truncated);
        assert!(log.text.len() <= MAX_TEXT_BYTES);
        assert!(log.text.ends_with("installer exited 1"));
    }

    #[test]
    fn fixed_file_only_and_symlinks_rejected() {
        let dir = tempfile::tempdir().unwrap();
        assert!(read(dir.path()).is_err());
        std::fs::write(dir.path().join("other"), "secret").unwrap();
        std::os::unix::fs::symlink("other", dir.path().join("installer.log")).unwrap();
        assert!(read(dir.path()).is_err());
    }
}
