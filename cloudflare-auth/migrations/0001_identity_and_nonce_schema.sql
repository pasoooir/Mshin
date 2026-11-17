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

-- Reserve the first two stable test player IDs and continue from 100001.
INSERT INTO sqlite_sequence(name, seq)
SELECT 'player_identities', 100000
WHERE NOT EXISTS (SELECT 1 FROM sqlite_sequence WHERE name = 'player_identities');

UPDATE sqlite_sequence
SET seq = MAX(seq, 100000)
WHERE name = 'player_identities';
