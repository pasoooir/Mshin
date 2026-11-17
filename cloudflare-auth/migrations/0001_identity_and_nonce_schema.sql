CREATE TABLE IF NOT EXISTS player_identities (
  player_id INTEGER PRIMARY KEY AUTOINCREMENT,
  google_subject_hash TEXT NOT NULL UNIQUE,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS auth_nonces (
  nonce_hash TEXT PRIMARY KEY,
  expires_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_auth_nonces_expires_at
  ON auth_nonces(expires_at);
