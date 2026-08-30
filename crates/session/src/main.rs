use std::{
    collections::VecDeque,
    env, fs,
    os::unix::fs::MetadataExt,
    path::{Path, PathBuf},
    process::{Command, ExitStatus},
    thread,
    time::{Duration, Instant},
};

const ALLOWED_APPLICATIONS: [&str; 2] = [
    "/usr/lib/dead-rose/dead-rose-shell",
    "/usr/lib/dead-rose/dead-rose-installer",
];
const CRASH_WINDOW: Duration = Duration::from_secs(60);
const NORMAL_RESTART_DELAY: Duration = Duration::from_secs(2);
const RATE_LIMIT_DELAY: Duration = Duration::from_secs(30);
const CRASH_LIMIT: usize = 5;

fn main() {
    let application = env::args_os().nth(1).map(PathBuf::from).unwrap_or_else(|| {
        fail("usage: dead-rose-session APPLICATION");
    });
    validate_application(&application).unwrap_or_else(|message| fail(&message));

    let mut failures = VecDeque::new();
    loop {
        let started = Instant::now();
        let status = start_cage(&application).unwrap_or_else(|error| {
            eprintln!("dead-rose-session: Cage failed to start: {error}");
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

        eprintln!(
            "dead-rose-session: Cage session exited with {status}; recent_failures={}",
            failures.len()
        );
        let delay = if failures.len() >= CRASH_LIMIT {
            eprintln!(
                "dead-rose-session: crash rate limit reached; delaying restart for {} seconds",
                RATE_LIMIT_DELAY.as_secs()
            );
            failures.clear();
            RATE_LIMIT_DELAY
        } else {
            NORMAL_RESTART_DELAY
        };
        thread::sleep(delay);
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
    if env::var_os("DEAD_ROSE_SOFTWARE_RENDERING").is_some() {
        command.env("LIBGL_ALWAYS_SOFTWARE", "1");
    }
    command.status()
}

#[cfg(unix)]
fn synthetic_failure() -> ExitStatus {
    use std::os::unix::process::ExitStatusExt;
    ExitStatus::from_raw(1 << 8)
}

fn fail(message: &str) -> ! {
    eprintln!("dead-rose-session: {message}");
    std::process::exit(1)
}
