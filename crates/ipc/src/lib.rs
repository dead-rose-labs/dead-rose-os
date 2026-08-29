use dead_rose_system_types::{CoreRequest, CoreResponse};
use thiserror::Error;
use tokio::{
    io::{AsyncBufReadExt, AsyncWriteExt, BufReader},
    net::UnixStream,
};

pub const DEFAULT_SOCKET: &str = "/run/dead-rose/core.sock";

#[derive(Debug, Error)]
pub enum IpcError {
    #[error("I/O: {0}")]
    Io(#[from] std::io::Error),
    #[error("protocol: {0}")]
    Protocol(#[from] serde_json::Error),
    #[error("empty response")]
    EmptyResponse,
}

pub async fn request(path: &str, message: &CoreRequest) -> Result<CoreResponse, IpcError> {
    let stream = UnixStream::connect(path).await?;
    let (read, mut write) = stream.into_split();
    write.write_all(&serde_json::to_vec(message)?).await?;
    write.write_all(b"\n").await?;
    let mut response = String::new();
    BufReader::new(read).read_line(&mut response).await?;
    if response.is_empty() {
        return Err(IpcError::EmptyResponse);
    }
    Ok(serde_json::from_str(&response)?)
}
