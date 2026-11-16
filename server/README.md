# Mshin independent JSON profile service

This service is the only game-data API. It stores one private JSON document per numeric player ID under `MSHIN_DATA_DIR/players/<player_id>.json`. It does not use Cloudflare, D1, R2, or another database for game state.

## Runtime

- Node.js 20+
- Persistent local disk or a mounted persistent volume
- One active writer instance for a data directory (the service serializes writes per player in-process)
- HTTPS reverse proxy in production

Run:

```sh
npm test
AUTH_TOKEN_SECRET='replace-with-at-least-32-random-bytes' \
MSHIN_DATA_DIR='/var/lib/mshin' \
ALLOWED_ORIGINS='https://pasoooir.github.io' \
NODE_ENV=production PORT=8788 npm start
```

The directory must be on persistent storage and included in the host's backup plan. Do not deploy this service on an ephemeral filesystem. Do not expose the data directory through a static web server.

## API

- `GET /healthz`: process health only.
- `GET /v1/profile`: returns the authenticated player's JSON profile.
- `PUT /v1/profile`: writes the authenticated player's profile using optimistic revision control. Body: `{ "expected_revision": 0, "game_state": { ... } }`.
- `POST /v1/dev/session`: development-only synthetic identity. Available only when `DEV_AUTH_ENABLED=true` and `NODE_ENV` is not `production`. Defaults to `admin:100001,player2:100002`; configure with `DEV_IDENTITIES`.

Production requests must carry a short-lived HS256 bearer token issued by the Cloudflare authentication Worker. The Worker and this service share `AUTH_TOKEN_SECRET`; keep it in deployment secrets, never in the repository or game client. The JSON service validates the token but does not call Cloudflare.

## Data and safety properties

- The numeric `user_id` in the verified token selects the file. A request cannot choose another user's file.
- The profile contains only `schema_version`, `user_id`, `revision`, timestamps and `game_state`; email-shaped fields are rejected recursively.
- Writes are serialized per player and use a temporary file plus atomic rename.
- `expected_revision` prevents stale clients from silently overwriting newer saves (HTTP 409).
- The game state is size-limited to 4 MiB.
- The service must run as a dedicated unprivileged user. Back up the data directory and test restores.

This first service slice stores complete Godot SaveManager payloads. Marketplace listings and cross-player transactions are a separate shared JSON aggregate and must be added with atomic inventory reservation and ledger semantics before enabling real player-to-player trading. Do not expose direct filesystem writes to clients.
