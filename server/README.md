# Mshin independent JSON profile service

This service is the only game-data API. It stores one private JSON document per numeric player ID under `MSHIN_DATA_DIR/players/<player_id>.json`. It does not use Cloudflare, D1, R2, or another database for game state.

## Runtime

- Node.js 20+
- Persistent local disk or a mounted persistent volume
- One active writer process for a data directory (profile and market reads/writes share an in-process lock)
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
- `PUT /v1/profile`: writes the authenticated player's game state using optimistic revision control. Body: `{ "expected_revision": 0, "game_state": { ... } }`. The Simoleons wallet is server-owned after profile initialization and cannot be overwritten by a normal save.
- `GET /v1/market`: public active listings from other players only.
- `GET /v1/market/mine`: the authenticated player's listing history.
- `POST /v1/market/list`: reserve goods from the seller's saved warehouse and publish a listing.
- `POST /v1/market/:listing_id/buy`: debit buyer Simoleons, credit seller Simoleons, transfer goods and close the listing once.
- `POST /v1/market/:listing_id/cancel`: seller-only cancellation that returns reserved goods.
- `POST /v1/dev/session`: development-only synthetic identity. Available only when `DEV_AUTH_ENABLED=true` and `NODE_ENV` is not `production`. Defaults to `admin:100001,player2:100002`; configure with `DEV_IDENTITIES`.

Production requests must carry a short-lived HS256 bearer token issued by the Cloudflare authentication Worker. The Worker and this service share `AUTH_TOKEN_SECRET`; keep it in deployment secrets, never in the repository or game client. The JSON service validates the token but does not call Cloudflare.

## Data and safety properties

- The numeric `user_id` in the verified token selects the file. A request cannot choose another user's file.
- Each player file is selected only from the verified numeric token subject; clients cannot choose another player's file.
- Player JSON contains a numeric `user_id`, `market_account` and `game_state`; email-shaped fields are rejected recursively.
- Simoleons are held in `market_account` and reconciled into the game state on reads/writes. Normal city inventory remains part of the Godot save payload so factory/shop production can continue to synchronize.
- Shared listings are stored in `market/listings.json`, not in Cloudflare or D1.
- Profile and market reads/mutations share a process-wide lock. Each JSON file is written through a temporary file and rename; multi-profile commits attempt rollback if a later write fails.
- Listing creation requires an idempotency key; retries with the same key and payload return the original listing without reserving stock again.
- `expected_revision` prevents stale profile saves from silently overwriting newer saves (HTTP 409).
- The game state is size-limited to 4 MiB.
- The service must run as a dedicated unprivileged user. Back up the data directory and test restores.

## Current marketplace scope and remaining hardening

- Only existing in-game Simoleons are transferred. SimCash and Golden Keys are never used for player trades.
- The server validates item IDs, verified unlock levels, quantity, unit price ceiling, seller ownership, buyer balance, buyer warehouse capacity and duplicate purchase attempts.
- Listings reserve goods; cancellation returns them; successful purchase transfers goods and money and records ledger entries for both players.
- The current Godot production/inventory save path still accepts the player's game-state payload. The market wallet is protected server-side, but complete anti-cheat protection for inventory requires moving production, collection and all inventory mutations to server-authoritative commands. Do not treat this test-market slice as production-hardened against a modified client.
- The filesystem locking model assumes one active writer process for the data directory. A multi-instance deployment needs a shared lock or a transactional storage layer. The rollback path handles ordinary write failures, not a power loss between multiple file renames.

Do not expose direct filesystem writes to clients.
