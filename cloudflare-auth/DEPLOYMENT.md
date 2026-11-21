# Mshin Cloudflare API deployment

The game remains hosted on GitHub Pages. Cloudflare Workers now runs the authenticated profile and player-market API; the private GitHub repository remains the only store for player and market JSON. D1 stores a SHA-256 hash of Google's stable subject mapped to a numeric player ID, plus short-lived hashes of one-time login nonces. It never stores Google email addresses.

## Provisioned resources

- Worker name: `mshin-player-auth`
- D1 database: `mshin-player-identities`
- D1 location: EU jurisdiction (created in EEUR)
- D1 schema: `player_identities(player_id, google_subject_hash, created_at)` and one-time `auth_nonces(nonce_hash, expires_at)`
- Worker URL: `https://mshin-player-auth.pasoooir-erp.workers.dev`
- Initial D1 sequence is set to `100000`; first and second distinct Google identities receive player IDs `100001` and `100002` respectively.
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
- `GOOGLE_CLIENT_ID`: the public Google Web OAuth Client ID. It is already configured in `wrangler.toml` and must remain identical to `mshin/account/google_client_id` in `godot-city-buildit/project.godot`; it is not a secret.
- Keep `GAME_ORIGIN=https://pasoooir.github.io`.

Deploy:

```sh
npm install
npm test
npx wrangler deploy
```

## API endpoints

- `GET /healthz` — Worker process health.
- `GET /v1/auth/nonce` — issues a cryptographically random, single-use five-minute nonce stored only as a SHA-256 hash in D1.
- `POST /v1/auth/google` — validates Google ID token, nonce, issuer, audience, signature and expiry; consumes the nonce exactly once; maps the SHA-256 Google subject hash to a numeric player ID in D1; returns a short-lived Mshin bearer token.
- `GET /v1/profile` and `PUT /v1/profile` — read/write only the authenticated player's JSON.
- `GET /v1/market` and `GET /v1/market/mine` — list active offers and the current player's offers.
- `POST /v1/market/list` — reserve seller inventory and create an offer.
- `POST /v1/market/:listing_id/buy` — transfer goods and Simoleons once.
- `POST /v1/market/:listing_id/cancel` — cancel an active offer and release reserved inventory.

The API derives the player ID from a verified bearer token. It never accepts a client-supplied player ID for data selection. Player profiles reject email fields recursively. The GitHub token stays server-side in Worker Secrets. The Godot web build now has a Google sign-in panel and obtains a one-time nonce before opening Google Identity Services; the Google Web Client ID must be the same in `wrangler.toml` and `godot-city-buildit/project.godot` (`mshin/account/google_client_id`). The game API/Auth URLs are preconfigured to the Worker URL above.

## Consistency and operating limits

Every profile and market API request is routed through one SQLite-backed Durable Object. It serializes operations globally before touching the GitHub branch, avoiding concurrent branch-ref writes from independent Worker isolates. The market transaction writes buyer profile, seller profile and listings into one Git tree/commit. This is suitable for the initial two-account acceptance test, not a high-volume economy.

GitHub is versioned JSON storage, not a transactional database. Each write creates Git objects and a commit, and reads/writes consume GitHub API quota. Cloudflare Workers Free currently includes 100,000 requests/day and 50 external subrequests per invocation; Durable Objects are available on Free with separate daily request/compute quotas. Measure actual usage before expanding the market to many players. Sources: [Workers limits](https://developers.cloudflare.com/workers/platform/limits/) and [Durable Objects pricing](https://developers.cloudflare.com/durable-objects/platform/pricing/).

## Current readiness (2026-11-21; live Cloudflare resource inspection)

- Worker `mshin-player-auth` is deployed at `https://mshin-player-auth.pasoooir-erp.workers.dev`; the live script is present in the connected Cloudflare account.
- The live Worker has the `IDENTITIES` D1 binding, `API_COORDINATOR` Durable Object binding, and the `AUTH_TOKEN_SECRET` and `GITHUB_JSON_TOKEN` secret bindings. Secret values were not read or exposed.
- The live public `GOOGLE_CLIENT_ID` equals `mshin/account/google_client_id` in `godot-city-buildit/project.godot`; `GAME_ORIGIN` is `https://pasoooir.github.io`.
- D1 currently contains three identity mappings (numeric player IDs 100001, 100002 and 100004). The private player-data repository currently contains JSON files for 100001 and 100002. A missing JSON file for a newly allocated identity is initialized by the first authenticated `GET /v1/profile` as a revision-zero default with timestamps. Returning accounts load their own remote `game_state` before the post-login autosave; if a player-scoped local snapshot has a newer UTC `saved_at`, it is reconciled to GitHub first rather than overwritten. A first-time account with no remote game state keeps the guest city once and writes it into the new player-scoped JSON file. The snapshot includes game progress plus notification, audio, haptics and graphics preferences. Sign-out saves the current account snapshot locally and requires a successful final cloud sync before restoring the guest save scope.
- The deployed smoke workflow already checks Worker health, CORS and D1-backed nonce issuance. The expanded smoke also checks malformed Google-token rejection, unauthorized profile access and rejection of untrusted origins without creating a player identity.
- Worker unit tests exercise a complete signed OIDC test-token path with an ephemeral RSA key: JWKS verification, nonce consumption/replay rejection, D1 identity allocation, Mshin bearer-token issuance and authenticated profile routing. This validates the implementation contract but does not substitute for signing in with a real Google account.

### Acceptance still required before calling Google sign-in and the online market production-ready

1. Open the published game in a real browser, complete Google Identity Services sign-in with an authorized account, and verify the returned Mayor ID and circular profile image in Settings.
2. Save a changed city name and another game setting; reload the game and verify that both the local save and private `players/<player_id>.json` profile restore the same values.
3. Sign in with a second, distinct Google account on a separate browser/device and verify that its player ID, local save and private JSON file are isolated from the first account.
4. Complete a two-account market cycle: list an item from real inventory, buy it from the second account, verify both balances/inventories and ledger entries, then test cancel/retry and duplicate purchase protection.
5. The current Godot Google adapter explicitly supports the Web build. Native Android Google sign-in is not implemented by this adapter; Android APK export success must not be described as proof of native Google authentication.

**Credential handling:** Google Identity Services on the Web uses the public Web Client ID and the signed ID token. The Google Client Secret is not needed in the Godot client or this Web token-validation flow; keep it private and never commit it. The Worker validates the token using Google's public JWKS and issues its own Mshin session.

The old Node API remains in `server/` for local tests/reference; it is no longer the intended production host.
