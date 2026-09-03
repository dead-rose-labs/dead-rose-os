use std::{
    collections::VecDeque,
    env, fs,
    io::{BufRead, BufReader, Read},
    os::unix::fs::MetadataExt,
    path::{Path, PathBuf},
    process::{Command, ExitStatus, Stdio},
    thread,
    time::{Duration, Instant},
};
use tracing::{error, info, warn};

const ALLOWED_APPLICATIONS: [&str; 2] = [
    "/usr/lib/dead-rose/dead-rose-shell",
    "/usr/lib/dead-rose/dead-rose-installer",
];
const CRASH_WINDOW: Duration = Duration::from_secs(60);
const NORMAL_RESTART_DELAY: Duration = Duration::from_secs(2);
const RATE_LIMIT_DELAY: Duration = Duration::from_secs(30);
const CRASH_LIMIT: usize = 5;

fn main() {
    init_logging();

    let mut arguments = env::args_os().skip(1);
    let first = arguments.next().unwrap_or_else(|| {
        fail("usage: dead-rose-session APPLICATION");
    });
    if first == "--run-application" {
        let application = arguments.next().map(PathBuf::from).unwrap_or_else(|| {
            fail("usage: dead-rose-session --run-application APPLICATION");
        });
        validate_application(&application).unwrap_or_else(|message| fail(&message));
        run_application(&application);
    }
    let application = PathBuf::from(first);
    validate_application(&application).unwrap_or_else(|message| fail(&message));

    let force_software_rendering = safe_graphics_requested();
    let mut failures = VecDeque::new();
    loop {
        let started = Instant::now();
        let software_rendering = force_software_rendering || !failures.is_empty();
        let status = start_cage(&application, software_rendering).unwrap_or_else(|error| {
            error!(%error, "Cage failed to start");
            synthetic_failure()
        });
        let now = Instant::now();
        if started.elapsed() >= CRASH_WINDOW {
            failures.clear();
        }
        failures.push_back(now);
        while failures
            .front()
            .is_some_and(|instant| now.duration_since(*instant) >= CRASH_WINDOW)
        {
            failures.pop_front();
        }

        log_exit_status("cage", status);
        warn!(recent_failures = failures.len(), "Cage session exited");
        let delay = if failures.len() >= CRASH_LIMIT {
            warn!(
                delay_seconds = RATE_LIMIT_DELAY.as_secs(),
                "Cage crash rate limit reached"
            );
            failures.clear();
            RATE_LIMIT_DELAY
        } else {
            NORMAL_RESTART_DELAY
        };
        thread::sleep(delay);
    }
}

fn safe_graphics_requested() -> bool {
    env::var_os("DEAD_ROSE_SOFTWARE_RENDERING").is_some()
        || fs::read_to_string("/proc/cmdline")
            .is_ok_and(|cmdline| cmdline_requests_safe_graphics(&cmdline))
}

fn cmdline_requests_safe_graphics(cmdline: &str) -> bool {
    cmdline
        .split_ascii_whitespace()
        .any(|argument| argument == "deadrose.graphics=safe")
}

fn init_logging() {
    if let Ok(layer) = tracing_journald::layer() {
        use tracing_subscriber::prelude::*;
        let _ = tracing_subscriber::registry().with(layer).try_init();
    } else {
        let _ = tracing_subscriber::fmt().with_target(false).try_init();
    }
}

fn validate_application(path: &Path) -> Result<(), String> {
    let path_string = path
        .to_str()
        .ok_or_else(|| "application path is not valid UTF-8".to_owned())?;
    if !ALLOWED_APPLICATIONS.contains(&path_string) {
        return Err(format!("application is not allow-listed: {path_string}"));
    }
    let metadata = fs::metadata(path)
        .map_err(|error| format!("application metadata is unavailable: {error}"))?;
    if !metadata.is_file() {
        return Err(format!("application is not a regular file: {path_string}"));
    }
    if metadata.mode() & 0o111 == 0 {
        return Err(format!("application is not executable: {path_string}"));
    }
    if metadata.uid() != 0 {
        return Err(format!("application must be owned by root: {path_string}"));
    }
    Ok(())
}

fn start_cage(application: &Path, software_rendering: bool) -> std::io::Result<ExitStatus> {
    let supervisor = env::current_exe()?;
    let mut command = Command::new("/usr/bin/cage");
    command
        .args(["-s", "--"])
        .arg(supervisor)
        .arg("--run-application")
        .arg(application);
    command.env("WLR_LIBINPUT_NO_DEVICES", "1");
    if software_rendering {
        command
            .env("LIBGL_ALWAYS_SOFTWARE", "1")
            .env("WLR_RENDERER", "pixman")
            .env("WEBKIT_DISABLE_DMABUF_RENDERER", "1");
        info!(
            renderer = "pixman",
            webkit_dmabuf = "disabled",
            "using safe graphics mode"
        );
    } else {
        info!(
            renderer = "automatic",
            webkit_dmabuf = "automatic",
            "using normal graphics mode"
        );
    }
    command.stdout(Stdio::piped()).stderr(Stdio::piped());
    info!(application = %application.display(), "starting Cage session");
    let mut child = command.spawn()?;
    let stdout = child
        .stdout
        .take()
        .map(|stream| thread::spawn(move || relay_output("cage stdout", stream, false)));
    let stderr = child
        .stderr
        .take()
        .map(|stream| thread::spawn(move || relay_output("cage stderr", stream, true)));
    let status = child.wait()?;
    if let Some(handle) = stdout {
        let _ = handle.join();
    }
    if let Some(handle) = stderr {
        let _ = handle.join();
    }
    Ok(status)
}

fn run_application(application: &Path) -> ! {
    let mut command = Command::new(application);
    command.stdout(Stdio::piped()).stderr(Stdio::piped());
    info!(application = %application.display(), "starting graphical application");
    let mut child = command.spawn().unwrap_or_else(|error| {
        error!(application = %application.display(), %error, "graphical application failed to start");
        std::process::exit(126);
    });
    info!(application = %application.display(), pid = child.id(), "graphical application started");
    let stdout = child
        .stdout
        .take()
        .map(|stream| thread::spawn(move || relay_output("application stdout", stream, false)));
    let stderr = child
        .stderr
        .take()
        .map(|stream| thread::spawn(move || relay_output("application stderr", stream, true)));
    let status = child.wait().unwrap_or_else(|error| {
        error!(application = %application.display(), %error, "failed to wait for graphical application");
        std::process::exit(125);
    });
    if let Some(handle) = stdout {
        let _ = handle.join();
    }
    if let Some(handle) = stderr {
        let _ = handle.join();
    }
    log_exit_status("application", status);
    std::process::exit(exit_code(status));
}

#[cfg(unix)]
fn log_exit_status(process: &str, status: ExitStatus) {
    use std::os::unix::process::ExitStatusExt;
    error!(
        process,
        code = status.code(),
        signal = status.signal(),
        core_dumped = status.core_dumped(),
        "graphical process exited"
    );
}

#[cfg(unix)]
fn exit_code(status: ExitStatus) -> i32 {
    use std::os::unix::process::ExitStatusExt;
    status
        .code()
        .unwrap_or_else(|| 128 + status.signal().unwrap_or(1))
}

fn relay_output(label: &'static str, stream: impl Read, is_error: bool) {
    for line in BufReader::new(stream).lines() {
        match line {
            Ok(line) if is_error => warn!(source = label, message = %line),
            Ok(line) => info!(source = label, message = %line),
            Err(error) => {
                warn!(source = label, %error, "failed to read session output");
                break;
            }
        }
    }
}

#[cfg(unix)]
fn synthetic_failure() -> ExitStatus {
    use std::os::unix::process::ExitStatusExt;
    ExitStatus::from_raw(1 << 8)
}

fn fail(message: &str) -> ! {
    error!(%message, "session supervisor failed");
    std::process::exit(1)
}

#[cfg(test)]
mod tests {
    use super::cmdline_requests_safe_graphics;

    #[test]
    fn recognizes_only_the_explicit_safe_graphics_kernel_argument() {
        assert!(cmdline_requests_safe_graphics(
            "quiet splash deadrose.graphics=safe console=tty0"
        ));
        assert!(!cmdline_requests_safe_graphics(
            "quiet splash deadrose.graphics=normal"
        ));
        assert!(!cmdline_requests_safe_graphics(
            "quiet splash deadrose.graphics=safe-ish"
        ));
    }
}
