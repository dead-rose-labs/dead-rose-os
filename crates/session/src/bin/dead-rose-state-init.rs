use nix::unistd::{Gid, Group, Uid, User, chown};
use std::{fs, path::Path, process::Command};

fn main() {
    repair_state_ownership();
    let source = Path::new("/var/lib/dead-rose/hostname");
    if !source.exists() {
        eprintln!("dead-rose-state-init: no persistent hostname configured");
        return;
    }
    let hostname = fs::read_to_string(source)
        .unwrap_or_else(|error| fail(&format!("cannot read persistent hostname: {error}")));
    let hostname = hostname.trim();
    if !valid_hostname(hostname) {
        fail("persistent hostname is invalid");
    }
    fs::write("/etc/hostname", format!("{hostname}\n"))
        .unwrap_or_else(|error| fail(&format!("cannot update /etc/hostname: {error}")));
    let status = Command::new("/usr/bin/hostnamectl")
        .args(["hostname", hostname])
        .status()
        .unwrap_or_else(|error| fail(&format!("hostnamectl could not start: {error}")));
    if !status.success() {
        fail(&format!("hostnamectl exited with {status}"));
    }
}

fn repair_state_ownership() {
    let user = User::from_name("deadrose-core")
        .unwrap_or_else(|error| fail(&format!("cannot resolve deadrose-core: {error}")))
        .unwrap_or_else(|| fail("deadrose-core user does not exist"));
    let group = Group::from_name("deadrose-core")
        .unwrap_or_else(|error| fail(&format!("cannot resolve deadrose-core group: {error}")))
        .unwrap_or_else(|| fail("deadrose-core group does not exist"));
    let uid = Uid::from_raw(user.uid.as_raw());
    let gid = Gid::from_raw(group.gid.as_raw());
    for path in [
        Path::new("/var/lib/dead-rose/auth"),
        Path::new("/var/lib/dead-rose/auth/accounts.json"),
    ] {
        if path.exists() {
            chown(path, Some(uid), Some(gid)).unwrap_or_else(|error| {
                fail(&format!("cannot secure {}: {error}", path.display()))
            });
        }
    }
}

fn valid_hostname(value: &str) -> bool {
    !value.is_empty()
        && value.len() <= 63
        && !value.starts_with('-')
        && !value.ends_with('-')
        && value
            .bytes()
            .all(|byte| byte.is_ascii_lowercase() || byte.is_ascii_digit() || byte == b'-')
}

fn fail(message: &str) -> ! {
    eprintln!("dead-rose-state-init: {message}");
    std::process::exit(1)
}

#[cfg(test)]
mod tests {
    use super::valid_hostname;

    #[test]
    fn validates_persistent_hostnames() {
        assert!(valid_hostname("dead-rose-01"));
        assert!(!valid_hostname("DeadRose"));
        assert!(!valid_hostname("-deadrose"));
        assert!(!valid_hostname("dead_rose"));
    }
}
