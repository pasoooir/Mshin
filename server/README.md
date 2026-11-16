# Mshin independent JSON profile service

This service is the only game-data API. Production game data is stored as JSON files in a **separate private GitHub repository**, not in the public Mshin Pages repository. Cloudflare is limited to authentication and issuing the numeric player ID; it does not store game state, inventory, wallet or market data.

## GitHub JSON storage

Configure a dedicated private repository, for example `pasoooir/mshin-player-data`. It must be private, have an initialized default branch, and must never be made public. Create a fine-grained GitHub token restricted to that one repository with **Contents: Read and write** only. Store the token only as a secret on the independent API host.

Required environment:

```sh
GITHUB_JSON_REPOSITORY='pasoooir/mshin-player-data'
GITHUB_JSON_BRANCH='main'
GITHUB_JSON_TOKEN='server-side-secret'
AUTH_TOKEN_SECRET='same-secret-used-by-auth-worker-at-least-32-bytes'
ALLOWED_ORIGINS='https://pasoooir.github.io'
NODE_ENV=production
PORT=8788
npm start
```

Initialize the two test accounts and shared market document once:

```sh
GITHUB_JSON_REPOSITORY='pasoooir/mshin-player-data' \
GITHUB_JSON_BRANCH='main' \
GITHUB_JSON_TOKEN='server-side-secret' npm run seed:github
```

The initializer creates only missing files and never overwrites existing player data:
- `players/100001.json` — admin
- `players/100002.json` — player2
- `market/listings.json` — shared active and historical listings

Both API startup and the seed command verify that the configured repository is actually private and that the configured branch exists. A public repository is rejected before player data can be read or written. The GitHub adapter reads JSON through the Contents API and writes a complete transaction through GitHub's Git Blobs, Trees and Commits APIs. Buyer profile, seller profile and market listings are placed in one Git commit, so readers see the transaction as one repository revision. The API token is never sent to Godot or the browser.

**Important operating limits:** GitHub is versioned file storage, not a high-throughput database. Each save/market mutation creates a Git commit and API reads consume the token's GitHub API quota. This implementation is intentionally an initial two-account/test deployment. Before opening the market to many players or frequent autosaves, add a server-side write queue/cache and measure GitHub API quota and latency; do not silently fall back to public files or Cloudflare storage.

For local automated tests only, the service continues to use filesystem JSON when `GITHUB_JSON_REPOSITORY` is absent. Production must be configured with the private repository and token.

## Deployment

See [DEPLOYMENT.md](./DEPLOYMENT.md) for the independent Docker-host deployment steps, required secrets, two-account acceptance cycle, and operational limits.

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
- Profile and market reads/mutations share a process-wide lock. GitHub-backed multi-file transactions are published as one Git tree/commit and one branch-ref update.
- Run exactly one API writer instance against this repository. The in-process lock is not a distributed lock; multiple independent API instances can race on stale profile snapshots.
- Listing creation requires an idempotency key; retries with the same key and payload return the original listing without reserving stock again.
- `expected_revision` prevents stale profile saves from silently overwriting newer saves (HTTP 409).
- The game state is size-limited to 4 MiB.
- The service must run as a dedicated unprivileged user. Back up the data directory and test restores.

## Current marketplace scope and remaining hardening

- Only existing in-game Simoleons are transferred. SimCash and Golden Keys are never used for player trades.
- The server validates item IDs, verified unlock levels, quantity, unit price ceiling, seller ownership, buyer balance, buyer warehouse capacity and duplicate purchase attempts.
- Listings reserve goods; cancellation returns them; successful purchase transfers goods and money and records ledger entries for both players.
- The current Godot production/inventory save path still accepts the player's game-state payload. The market wallet is protected server-side, but complete anti-cheat protection for inventory requires moving production, collection and all inventory mutations to server-authoritative commands. Do not treat this test-market slice as production-hardened against a modified client.
- The GitHub adapter retries branch-ref conflicts, but it does not provide distributed application-level locking across multiple API instances. Keep one writer instance until a shared transactional lock/storage layer is implemented.

Do not expose direct filesystem writes to clients.
