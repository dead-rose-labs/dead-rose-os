use argon2::password_hash::rand_core::OsRng;
use argon2::{
    Algorithm, Argon2, Params, Version,
    password_hash::{PasswordHash, PasswordHasher, PasswordVerifier, SaltString},
};
use serde::{Deserialize, Serialize};
use std::{
    collections::{HashMap, VecDeque},
    fs, io,
    path::{Path, PathBuf},
    time::{Duration, Instant},
};
use thiserror::Error;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Account {
    pub username: String,
    pub password_hash: String,
    pub created_at: String,
    pub disabled: bool,
}

#[derive(Debug, Error)]
pub enum AuthError {
    #[error("invalid credentials")]
    InvalidCredentials,
    #[error("rate limited for {0} seconds")]
    RateLimited(u64),
    #[error("credential storage error: {0}")]
    Storage(#[from] io::Error),
    #[error("invalid credential database: {0}")]
    InvalidStore(#[from] serde_json::Error),
    #[error("password hashing failed")]
    Hashing,
}

pub fn hash_password(password: &[u8]) -> Result<String, AuthError> {
    let params = Params::new(19_456, 2, 1, Some(32)).map_err(|_| AuthError::Hashing)?;
    let algorithm = Argon2::new(Algorithm::Argon2id, Version::V0x13, params);
    let salt = SaltString::generate(&mut OsRng);
    algorithm
        .hash_password(password, &salt)
        .map(|hash| hash.to_string())
        .map_err(|_| AuthError::Hashing)
}

pub fn verify_password(hash: &str, password: &[u8]) -> bool {
    PasswordHash::new(hash)
        .ok()
        .is_some_and(|parsed| Argon2::default().verify_password(password, &parsed).is_ok())
}

pub struct CredentialStore {
    path: PathBuf,
    accounts: HashMap<String, Account>,
}

impl CredentialStore {
    pub fn load(path: impl Into<PathBuf>) -> Result<Self, AuthError> {
        let path = path.into();
        let accounts = match fs::read(&path) {
            Ok(bytes) => serde_json::from_slice::<Vec<Account>>(&bytes)?
                .into_iter()
                .map(|a| (a.username.clone(), a))
                .collect(),
            Err(error) if error.kind() == io::ErrorKind::NotFound => HashMap::new(),
            Err(error) => return Err(error.into()),
        };
        Ok(Self { path, accounts })
    }
    pub fn authenticate(&self, username: &str, password: &[u8]) -> Result<(), AuthError> {
        let account = self
            .accounts
            .get(username)
            .filter(|a| !a.disabled)
            .ok_or(AuthError::InvalidCredentials)?;
        if verify_password(&account.password_hash, password) {
            Ok(())
        } else {
            Err(AuthError::InvalidCredentials)
        }
    }
    pub fn upsert(&mut self, username: &str, password: &[u8]) -> Result<(), AuthError> {
        let account = Account {
            username: username.to_owned(),
            password_hash: hash_password(password)?,
            created_at: chrono::Utc::now().to_rfc3339(),
            disabled: false,
        };
        self.accounts.insert(username.to_owned(), account);
        self.persist()
    }
    fn persist(&self) -> Result<(), AuthError> {
        if let Some(parent) = self.path.parent() {
            fs::create_dir_all(parent)?;
        }
        let mut values: Vec<_> = self.accounts.values().collect();
        values.sort_by_key(|account| &account.username);
        let temporary = self.path.with_extension("tmp");
        fs::write(&temporary, serde_json::to_vec_pretty(&values)?)?;
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            fs::set_permissions(&temporary, fs::Permissions::from_mode(0o600))?;
        }
        fs::rename(temporary, &self.path)?;
        Ok(())
    }
    pub fn path(&self) -> &Path {
        &self.path
    }
}

pub struct RateLimiter {
    attempts: HashMap<String, VecDeque<Instant>>,
    limit: usize,
    window: Duration,
}
impl RateLimiter {
    pub fn new(limit: usize, window: Duration) -> Self {
        Self {
            attempts: HashMap::new(),
            limit,
            window,
        }
    }
    pub fn check(&mut self, key: &str) -> Result<(), AuthError> {
        let now = Instant::now();
        let attempts = self.attempts.entry(key.to_owned()).or_default();
        while attempts
            .front()
            .is_some_and(|instant| now.duration_since(*instant) >= self.window)
        {
            attempts.pop_front();
        }
        if attempts.len() >= self.limit {
            let remaining = self
                .window
                .saturating_sub(
                    now.duration_since(*attempts.front().expect("non-empty after limit check")),
                )
                .as_secs()
                .max(1);
            return Err(AuthError::RateLimited(remaining));
        }
        Ok(())
    }
    pub fn record_failure(&mut self, key: &str) {
        self.attempts
            .entry(key.to_owned())
            .or_default()
            .push_back(Instant::now());
    }
    pub fn clear(&mut self, key: &str) {
        self.attempts.remove(key);
    }
}

pub struct Sessions {
    sessions: HashMap<Uuid, Instant>,
    lifetime: Duration,
}
impl Sessions {
    pub fn new(lifetime: Duration) -> Self {
        Self {
            sessions: HashMap::new(),
            lifetime,
        }
    }
    pub fn create(&mut self) -> Uuid {
        let id = Uuid::new_v4();
        self.sessions.insert(id, Instant::now() + self.lifetime);
        id
    }
    pub fn validate(&mut self, id: Uuid) -> bool {
        self.sessions.retain(|_, expires| *expires > Instant::now());
        self.sessions.contains_key(&id)
    }
    pub fn invalidate(&mut self, id: Uuid) -> bool {
        self.sessions.remove(&id).is_some()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn password_round_trip_and_invalid_password() {
        let hash = hash_password(b"correct horse battery staple").unwrap();
        assert!(verify_password(&hash, b"correct horse battery staple"));
        assert!(!verify_password(&hash, b"wrong"));
    }
    #[test]
    fn credential_store_handles_valid_unknown_and_invalid() {
        let dir = tempfile::tempdir().unwrap();
        let mut store = CredentialStore::load(dir.path().join("accounts.json")).unwrap();
        store.upsert("admin", b"a-long-test-password").unwrap();
        assert!(store.authenticate("admin", b"a-long-test-password").is_ok());
        assert!(matches!(
            store.authenticate("admin", b"bad"),
            Err(AuthError::InvalidCredentials)
        ));
        assert!(matches!(
            store.authenticate("unknown", b"bad"),
            Err(AuthError::InvalidCredentials)
        ));
    }
    #[test]
    fn rate_limit_enforces_window() {
        let mut limiter = RateLimiter::new(2, Duration::from_secs(60));
        limiter.record_failure("admin");
        limiter.record_failure("admin");
        assert!(matches!(
            limiter.check("admin"),
            Err(AuthError::RateLimited(_))
        ));
    }
    #[test]
    fn logout_invalidates_session() {
        let mut sessions = Sessions::new(Duration::from_secs(60));
        let id = sessions.create();
        assert!(sessions.validate(id));
        assert!(sessions.invalidate(id));
        assert!(!sessions.validate(id));
    }
}
