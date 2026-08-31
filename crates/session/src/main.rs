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

    let application = env::args_os().nth(1).map(PathBuf::from).unwrap_or_else(|| {
        fail("usage: dead-rose-session APPLICATION");
    });
    validate_application(&application).unwrap_or_else(|message| fail(&message));

    let mut failures = VecDeque::new();
    loop {
        let started = Instant::now();
        let status = start_cage(&application).unwrap_or_else(|error| {
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

        warn!(%status, recent_failures = failures.len(), "Cage session exited");
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

fn start_cage(application: &Path) -> std::io::Result<ExitStatus> {
    let mut command = Command::new("/usr/bin/cage");
    command.args(["-s", "--"]).arg(application);
    command.env("WLR_LIBINPUT_NO_DEVICES", "1");
    command.stdout(Stdio::piped()).stderr(Stdio::piped());
    if env::var_os("DEAD_ROSE_SOFTWARE_RENDERING").is_some() {
        command.env("LIBGL_ALWAYS_SOFTWARE", "1");
    }
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
