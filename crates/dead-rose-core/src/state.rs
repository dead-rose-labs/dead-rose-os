use argon2::{
    Argon2, PasswordHash, PasswordHasher, PasswordVerifier,
    password_hash::{SaltString, rand_core::OsRng},
};
use chrono::{Duration, Utc};
use dead_rose_types::ApplicationState;
use rand::{RngCore, rngs::OsRng as TokenRng};
use rusqlite::{Connection, OptionalExtension, params};
use sha2::{Digest, Sha256};
use std::path::Path;
use thiserror::Error;

const SESSION_LIFETIME_HOURS: i64 = 12;

#[derive(Debug, Error)]
pub enum StateError {
    #[error("persistent database operation failed: {0}")]
    Database(#[from] rusqlite::Error),
    #[error("password processing failed")]
    Password,
    #[error("an administrator already exists")]
    AdminExists,
    #[error("username must be 3-32 characters using letters, numbers, '.', '_' or '-'")]
    InvalidUsername,
    #[error("password must contain between 12 and 1024 characters")]
    InvalidPassword,
    #[error("invalid username or password")]
    InvalidCredentials,
}

pub struct StateStore {
    connection: Connection,
}

impl StateStore {
    pub fn open(path: &Path) -> Result<Self, StateError> {
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)
                .map_err(|_| rusqlite::Error::InvalidPath(parent.into()))?;
        }
        let connection = Connection::open(path)?;
        connection.pragma_update(None, "journal_mode", "WAL")?;
        connection.pragma_update(None, "foreign_keys", "ON")?;
        let store = Self { connection };
        store.migrate()?;
        Ok(store)
    }

    fn migrate(&self) -> Result<(), StateError> {
        self.connection.execute_batch(
            "BEGIN;
             CREATE TABLE IF NOT EXISTS schema_migrations (
               version INTEGER PRIMARY KEY,
               applied_at TEXT NOT NULL
             );
             CREATE TABLE IF NOT EXISTS metadata (
               key TEXT PRIMARY KEY,
               value TEXT NOT NULL
             );
             CREATE TABLE IF NOT EXISTS users (
               id INTEGER PRIMARY KEY AUTOINCREMENT,
               username TEXT NOT NULL UNIQUE COLLATE NOCASE,
               password_hash TEXT NOT NULL,
               role TEXT NOT NULL CHECK(role = 'admin'),
               created_at TEXT NOT NULL
             );
             CREATE TABLE IF NOT EXISTS sessions (
               token_hash TEXT PRIMARY KEY,
               user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
               created_at TEXT NOT NULL,
               expires_at TEXT NOT NULL
             );
             CREATE TABLE IF NOT EXISTS settings (
               key TEXT PRIMARY KEY,
               value TEXT NOT NULL,
               updated_at TEXT NOT NULL
             );
             INSERT OR IGNORE INTO schema_migrations(version, applied_at) VALUES (1, datetime('now'));
             COMMIT;",
        )?;
        Ok(())
    }

    pub fn has_admin(&self) -> Result<bool, StateError> {
        let count: i64 = self.connection.query_row(
            "SELECT COUNT(*) FROM users WHERE role = 'admin'",
            [],
            |row| row.get(0),
        )?;
        Ok(count > 0)
    }

    pub fn application_state(&self, token: Option<&str>) -> Result<ApplicationState, StateError> {
        if !self.has_admin()? {
            return Ok(ApplicationState::FirstBoot);
        }
        if token.is_some_and(|value| self.is_valid_session(value).unwrap_or(false)) {
            Ok(ApplicationState::Dashboard)
        } else {
            Ok(ApplicationState::Login)
        }
    }

    pub fn create_admin(&mut self, username: &str, password: &str) -> Result<(), StateError> {
        validate_username(username)?;
        validate_password(password)?;
        let transaction = self.connection.transaction()?;
        let count: i64 = transaction.query_row(
            "SELECT COUNT(*) FROM users WHERE role = 'admin'",
            [],
            |row| row.get(0),
        )?;
        if count > 0 {
            return Err(StateError::AdminExists);
        }
        let salt = SaltString::generate(&mut OsRng);
        let password_hash = Argon2::default()
            .hash_password(password.as_bytes(), &salt)
            .map_err(|_| StateError::Password)?
            .to_string();
        transaction.execute(
            "INSERT INTO users(username, password_hash, role, created_at) VALUES (?1, ?2, 'admin', ?3)",
            params![username.trim(), password_hash, Utc::now().to_rfc3339()],
        )?;
        transaction.commit()?;
        Ok(())
    }

    pub fn login(&self, username: &str, password: &str) -> Result<String, StateError> {
        let user: Option<(i64, String)> = self
            .connection
            .query_row(
                "SELECT id, password_hash FROM users WHERE username = ?1 COLLATE NOCASE",
                [username.trim()],
                |row| Ok((row.get(0)?, row.get(1)?)),
            )
            .optional()?;
        let Some((user_id, encoded)) = user else {
            return Err(StateError::InvalidCredentials);
        };
        let parsed = PasswordHash::new(&encoded).map_err(|_| StateError::Password)?;
        Argon2::default()
            .verify_password(password.as_bytes(), &parsed)
            .map_err(|_| StateError::InvalidCredentials)?;

        let mut bytes = [0_u8; 32];
        TokenRng.fill_bytes(&mut bytes);
        let token = bytes
            .iter()
            .map(|byte| format!("{byte:02x}"))
            .collect::<String>();
        let hash = token_hash(&token);
        let now = Utc::now();
        self.connection.execute(
            "DELETE FROM sessions WHERE expires_at <= ?1",
            [now.to_rfc3339()],
        )?;
        self.connection.execute(
            "INSERT INTO sessions(token_hash, user_id, created_at, expires_at) VALUES (?1, ?2, ?3, ?4)",
            params![hash, user_id, now.to_rfc3339(), (now + Duration::hours(SESSION_LIFETIME_HOURS)).to_rfc3339()],
        )?;
        Ok(token)
    }

    pub fn logout(&self, token: &str) -> Result<(), StateError> {
        self.connection.execute(
            "DELETE FROM sessions WHERE token_hash = ?1",
            [token_hash(token)],
        )?;
        Ok(())
    }

    pub fn is_valid_session(&self, token: &str) -> Result<bool, StateError> {
        if token.len() != 64 || !token.bytes().all(|byte| byte.is_ascii_hexdigit()) {
            return Ok(false);
        }
        let valid: Option<i64> = self
            .connection
            .query_row(
                "SELECT 1 FROM sessions WHERE token_hash = ?1 AND expires_at > ?2",
                params![token_hash(token), Utc::now().to_rfc3339()],
                |row| row.get(0),
            )
            .optional()?;
        Ok(valid.is_some())
    }
}

fn token_hash(token: &str) -> String {
    format!("{:x}", Sha256::digest(token.as_bytes()))
}

fn validate_username(username: &str) -> Result<(), StateError> {
    let username = username.trim();
    if !(3..=32).contains(&username.len())
        || !username
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'.' | b'_' | b'-'))
    {
        return Err(StateError::InvalidUsername);
    }
    Ok(())
}

fn validate_password(password: &str) -> Result<(), StateError> {
    if !(12..=1024).contains(&password.chars().count()) {
        return Err(StateError::InvalidPassword);
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    #[test]
    fn first_boot_admin_and_session_flow() {
        let directory = tempdir().unwrap();
        let mut store = StateStore::open(&directory.path().join("state.db")).unwrap();
        assert_eq!(
            store.application_state(None).unwrap(),
            ApplicationState::FirstBoot
        );
        store
            .create_admin("rose-admin", "correct horse battery staple")
            .unwrap();
        assert_eq!(
            store.application_state(None).unwrap(),
            ApplicationState::Login
        );
        assert!(matches!(
            store.login("rose-admin", "wrong password"),
            Err(StateError::InvalidCredentials)
        ));
        let token = store
            .login("rose-admin", "correct horse battery staple")
            .unwrap();
        assert_eq!(
            store.application_state(Some(&token)).unwrap(),
            ApplicationState::Dashboard
        );
        store.logout(&token).unwrap();
        assert_eq!(
            store.application_state(Some(&token)).unwrap(),
            ApplicationState::Login
        );
    }

    #[test]
    fn password_is_stored_as_argon2id_hash() {
        let directory = tempdir().unwrap();
        let path = directory.path().join("state.db");
        let mut store = StateStore::open(&path).unwrap();
        store
            .create_admin("admin", "a secure local password")
            .unwrap();
        drop(store);
        let connection = Connection::open(path).unwrap();
        let hash: String = connection
            .query_row("SELECT password_hash FROM users", [], |row| row.get(0))
            .unwrap();
        assert!(hash.starts_with("$argon2id$"));
        assert!(!hash.contains("a secure local password"));
    }
}
