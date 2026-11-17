# Mshin Cloudflare API deployment

The game remains hosted on GitHub Pages. Cloudflare Workers now runs the authenticated profile and player-market API; the private GitHub repository remains the only store for player and market JSON. D1 stores only the SHA-256 hash of Google's stable subject and the numeric player ID.

## Provisioned resources

- Worker name: `mshin-player-auth`
- D1 database: `mshin-player-identities`
- D1 location: EU jurisdiction (created in EEUR)
- D1 schema: `player_identities(player_id, google_subject_hash, created_at)` and one-time `auth_nonces(nonce_hash, expires_at)`\n- Worker URL: `https://mshin-player-auth.pasoooir-erp.workers.dev`\n- Initial D1 sequence is set to `100000`; first and second distinct Google identities receive player IDs `100001` and `100002` respectively.
- JSON repository: `pasoooir/mshin-player-data` (private, branch `main`)
- Durable Object: `MshinApiCoordinator`, one global instance serializing all profile and market writes

The D1 database and schema have already been created in the connected Cloudflare account. The database UUID is recorded in `wrangler.toml`.

## Required secrets and public configuration

From `cloudflare-auth/`, set the secrets using Wrangler (or the Worker Settings > Variables and Secrets dashboard):

```sh
npx wrangler secret put AUTH_TOKEN_SECRET
npx wrangler secret put GITHUB_JSON_TOKEN
```

- `AUTH_TOKEN_SECRET`: a new random secret of at least 32 characters. Keep it only as a Worker secret.
- `GITHUB_JSON_TOKEN`: the existing Fine-grained token, restricted to `pasoooir/mshin-player-data`, with Contents read/write. Never put it in GitHub Pages, Godot, source files, or chat.
- `GOOGLE_CLIENT_ID`: replace the placeholder in `wrangler.toml` with the Google Web OAuth client ID. It is public configuration, not a secret.
- Keep `GAME_ORIGIN=https://pasoooir.github.io`.

Deploy:

```sh
npm install
npm test
npx wrangler deploy
```

## API endpoints

- `GET /healthz` — Worker process health.
- `GET /v1/auth/nonce` — issues a cryptographically random, single-use five-minute nonce stored only as a SHA-256 hash in D1.\n- `POST /v1/auth/google` — validates Google ID token, nonce, issuer, audience, signature and expiry; consumes the nonce exactly once; maps the SHA-256 Google subject hash to a numeric player ID in D1; returns a short-lived Mshin bearer token.
- `GET /v1/profile` and `PUT /v1/profile` — read/write only the authenticated player's JSON.
- `GET /v1/market` and `GET /v1/market/mine` — list active offers and the current player's offers.
- `POST /v1/market/list` — reserve seller inventory and create an offer.
- `POST /v1/market/:listing_id/buy` — transfer goods and Simoleons once.
- `POST /v1/market/:listing_id/cancel` — cancel an active offer and release reserved inventory.

The API derives the player ID from a verified bearer token. It never accepts a client-supplied player ID for data selection. Player profiles reject email fields recursively. The GitHub token stays server-side in Worker Secrets. The Godot web build now has a Google sign-in panel and obtains a one-time nonce before opening Google Identity Services; the Google Web Client ID must be the same in `wrangler.toml` and `godot-city-buildit/project.godot` (`mshin/account/google_client_id`). The game API/Auth URLs are preconfigured to the Worker URL above.

## Consistency and operating limits

Every profile and market API request is routed through one SQLite-backed Durable Object. It serializes operations globally before touching the GitHub branch, avoiding concurrent branch-ref writes from independent Worker isolates. The market transaction writes buyer profile, seller profile and listings into one Git tree/commit. This is suitable for the initial two-account acceptance test, not a high-volume economy.

GitHub is versioned JSON storage, not a transactional database. Each write creates Git objects and a commit, and reads/writes consume GitHub API quota. Cloudflare Workers Free currently includes 100,000 requests/day and 50 external subrequests per invocation; Durable Objects are available on Free with separate daily request/compute quotas. Measure actual usage before expanding the market to many players. Sources: [Workers limits](https://developers.cloudflare.com/workers/platform/limits/) and [Durable Objects pricing](https://developers.cloudflare.com/durable-objects/platform/pricing/).

## Current readiness

Code and D1 schema are prepared. The first two new Google identities are assigned 100001 and 100002 in login order; the first should be the intended admin test account and the second player2. The Worker is not considered production-ready until `AUTH_TOKEN_SECRET`, `GITHUB_JSON_TOKEN`, and the real Google Web Client ID are configured, deployment succeeds, and the two-account acceptance cycle passes against the deployed API. The old Node API remains in `server/` for local tests/reference; it is no longer the intended production host.
