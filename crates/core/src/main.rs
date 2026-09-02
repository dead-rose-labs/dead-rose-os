use dead_rose_auth::{AuthError, CredentialStore, RateLimiter, Sessions};
use dead_rose_ipc::DEFAULT_SOCKET;
use dead_rose_system_types::{CoreRequest, CoreResponse, ErrorCode, PRODUCT_NAME, VERSION};
use std::{env, fs, io, path::Path, sync::Arc, time::Duration};
use tokio::{
    io::{AsyncBufReadExt, AsyncWriteExt, BufReader},
    net::{UnixListener, UnixStream},
    sync::Mutex,
};
use tracing::{error, info};

struct State {
    credentials: CredentialStore,
    limiter: RateLimiter,
    sessions: Sessions,
}

#[tokio::main]
async fn main() {
    init_logging();
    if let Err(error) = run().await {
        error!(stage = "startup", %error, "Dead Rose core failed to start");
        std::process::exit(1);
    }
}

async fn run() -> io::Result<()> {
    let socket = env::var("DEAD_ROSE_SOCKET").unwrap_or_else(|_| DEFAULT_SOCKET.to_owned());
    let credentials = env::var("DEAD_ROSE_CREDENTIALS")
        .unwrap_or_else(|_| "/var/lib/dead-rose/auth/accounts.json".to_owned());
    if let Some(parent) = Path::new(&socket).parent() {
        fs::create_dir_all(parent)?;
    }
    if Path::new(&socket).exists() {
        fs::remove_file(&socket)?;
    }
    let listener = UnixListener::bind(&socket)?;
    let state = Arc::new(Mutex::new(State {
        credentials: CredentialStore::load(credentials).map_err(io::Error::other)?,
        limiter: RateLimiter::new(5, Duration::from_secs(60)),
        sessions: Sessions::new(Duration::from_secs(15 * 60)),
    }));
    info!(stage = "ready", socket, "Dead Rose core ready");
    loop {
        let (stream, _) = listener.accept().await?;
        let state = state.clone();
        tokio::spawn(async move {
            if let Err(error) = serve(stream, state).await {
                error!(%error, "IPC request failed");
            }
        });
    }
}

fn init_logging() {
    let subscriber = tracing_subscriber::fmt().with_target(false);
    if let Ok(layer) = tracing_journald::layer() {
        use tracing_subscriber::prelude::*;
        let _ = tracing_subscriber::registry().with(layer).try_init();
    } else {
        let _ = subscriber.try_init();
    }
}

async fn serve(stream: UnixStream, state: Arc<Mutex<State>>) -> io::Result<()> {
    let (read, mut write) = stream.into_split();
    let mut line = String::new();
    BufReader::new(read).read_line(&mut line).await?;
    let response = match serde_json::from_str::<CoreRequest>(&line) {
        Ok(request) => {
            let mut guard = state.lock().await;
            handle(request, &mut guard)
        }
        Err(_) => CoreResponse::Error {
            code: ErrorCode::MalformedRequest,
            message: "The request is malformed.".into(),
            retry_after_seconds: None,
        },
    };
    write
        .write_all(&serde_json::to_vec(&response).map_err(io::Error::other)?)
        .await?;
    write.write_all(b"\n").await
}

fn handle(request: CoreRequest, state: &mut State) -> CoreResponse {
    match request {
        CoreRequest::Readiness => CoreResponse::Ready,
        CoreRequest::ProductInfo => CoreResponse::ProductInfo {
            name: PRODUCT_NAME.into(),
            version: VERSION.into(),
        },
        CoreRequest::Authenticate { username, password } => {
            if let Err(AuthError::RateLimited(seconds)) = state.limiter.check(&username) {
                return CoreResponse::Error {
                    code: ErrorCode::RateLimited,
                    message: "Too many authentication attempts.".into(),
                    retry_after_seconds: Some(seconds),
                };
            }
            match state
                .credentials
                .authenticate(&username, password.as_bytes())
            {
                Ok(()) => {
                    state.limiter.clear(&username);
                    let id = state.sessions.create();
                    CoreResponse::Authenticated {
                        session_id: id.to_string(),
                        expires_in_seconds: 900,
                    }
                }
                Err(AuthError::InvalidCredentials) => {
                    state.limiter.record_failure(&username);
                    CoreResponse::Error {
                        code: ErrorCode::InvalidCredentials,
                        message: "Invalid credentials.".into(),
                        retry_after_seconds: None,
                    }
                }
                Err(_) => CoreResponse::Error {
                    code: ErrorCode::Internal,
                    message: "Authentication storage is unavailable.".into(),
                    retry_after_seconds: None,
                },
            }
        }
        CoreRequest::ValidateSession { session_id } => match session_id
            .parse()
            .ok()
            .filter(|id| state.sessions.validate(*id))
        {
            Some(_) => CoreResponse::ValidSession,
            None => CoreResponse::Error {
                code: ErrorCode::InvalidSession,
                message: "Session is invalid or expired.".into(),
                retry_after_seconds: None,
            },
        },
        CoreRequest::Logout { session_id } => {
            if let Ok(id) = session_id.parse() {
                state.sessions.invalidate(id);
            }
            CoreResponse::LoggedOut
        }
    }
}
