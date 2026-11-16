CREATE TABLE IF NOT EXISTS player_identities (
  player_id INTEGER PRIMARY KEY AUTOINCREMENT,
  google_subject_hash TEXT NOT NULL UNIQUE,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_player_identities_subject_hash
ON player_identities (google_subject_hash);
