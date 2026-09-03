use dead_rose_types::{Request, RequestEnvelope, ResponseEnvelope};
use std::io::{BufRead, BufReader, Read, Write};
use std::os::unix::net::UnixStream;
use std::path::Path;
use std::time::Duration;
use thiserror::Error;
use uuid::Uuid;

const MAX_FRAME_BYTES: u64 = 64 * 1024;

#[derive(Debug, Error)]
pub enum IpcError {
    #[error("failed to connect to Dead Rose Core: {0}")]
    Connect(#[source] std::io::Error),
    #[error("failed to communicate with Dead Rose Core: {0}")]
    Io(#[source] std::io::Error),
    #[error("invalid response from Dead Rose Core: {0}")]
    Protocol(#[from] serde_json::Error),
    #[error("Dead Rose Core closed the connection without a response")]
    EmptyResponse,
    #[error("Dead Rose Core returned a mismatched response id")]
    MismatchedResponse,
}

pub fn call(socket: impl AsRef<Path>, request: Request) -> Result<ResponseEnvelope, IpcError> {
    let mut stream = UnixStream::connect(socket).map_err(IpcError::Connect)?;
    stream
        .set_read_timeout(Some(Duration::from_secs(30)))
        .map_err(IpcError::Io)?;
    stream
        .set_write_timeout(Some(Duration::from_secs(5)))
        .map_err(IpcError::Io)?;

    let envelope = RequestEnvelope {
        id: Uuid::new_v4().to_string(),
        request,
    };
    serde_json::to_writer(&mut stream, &envelope)?;
    stream.write_all(b"\n").map_err(IpcError::Io)?;

    let mut line = String::new();
    BufReader::new(stream)
        .take(MAX_FRAME_BYTES)
        .read_line(&mut line)
        .map_err(IpcError::Io)?;
    if line.is_empty() {
        return Err(IpcError::EmptyResponse);
    }
    let response: ResponseEnvelope = serde_json::from_str(&line)?;
    if response.id != envelope.id {
        return Err(IpcError::MismatchedResponse);
    }
    Ok(response)
}

#[cfg(test)]
mod tests {
    use super::MAX_FRAME_BYTES;

    #[test]
    fn frame_limit_is_bounded() {
        assert_eq!(MAX_FRAME_BYTES, 65_536);
    }
}
