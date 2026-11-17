> **Superseded for production:** the current deployment target is Cloudflare Workers. Keep this document only as the historical Node.js-host alternative. Follow [`cloudflare-auth/DEPLOYMENT.md`](../cloudflare-auth/DEPLOYMENT.md) for the active architecture.

# Independent Mshin JSON API deployment

This deploys the game-data API as a single Node.js container on an independent host. It does not deploy to Cloudflare. GitHub Pages remains the static game host; the private GitHub repository remains the JSON file store; the Cloudflare Worker only authenticates Google identity and issues the numeric player ID/token.

## Required topology

- **Game client:** `https://pasoooir.github.io/Mshin/`
- **Auth issuer:** Cloudflare Worker endpoint `/v1/auth/google` (identity mapping only)
- **Game-data API:** one always-on Node.js 22+ container on a separate host, behind HTTPS
- **JSON storage:** private GitHub repository `pasoooir/mshin-player-data`

Do not point this service at the public `pasoooir/Mshin` repository. Startup and seeding reject repositories whose GitHub API response does not say `private: true`.

## Host requirements

Choose a host that supports Docker or Node.js 20+, environment secrets, HTTPS/custom domains, and a single continuously running instance. For the initial two-account test, keep exactly **one API instance**. Do not enable horizontal autoscaling or multiple replicas: the current lock is process-local and is not a distributed lock.

The service is lightweight, but each profile save and market transaction writes Git objects and a commit to GitHub. A host that sleeps or scales to zero is unsuitable for reliable live gameplay. Check the host's current price and idle/sleep policy before deploying; this repository does not assume a specific vendor or price.

## Environment variables

Set these as host-managed secrets/environment values. Never commit real values to Git or place the GitHub token in the game client.

| Variable | Value |
| --- | --- |
| `NODE_ENV` | `production` |
| `PORT` | host-provided port, or `8788` |
| `ALLOWED_ORIGINS` | `https://pasoooir.github.io` |
| `GITHUB_JSON_REPOSITORY` | `pasoooir/mshin-player-data` |
| `GITHUB_JSON_BRANCH` | `main` |
| `GITHUB_JSON_TOKEN` | fine-grained token limited to the private data repo, Contents read/write |
| `AUTH_TOKEN_SECRET` | same random secret configured in the Cloudflare Auth Worker; at least 32 characters |
| `DEV_AUTH_ENABLED` | `false` |

The Cloudflare Worker also needs its Google Web Client ID, D1 identity database binding, and the same `AUTH_TOKEN_SECRET`. Keep Google identity and numeric-ID mapping in that Worker/D1 layer only; do not add email to player JSON.

## First deployment

1. Create `pasoooir/mshin-player-data` as a **private** GitHub repository and initialize its `main` branch.
2. Create a fine-grained token restricted to that repository. Grant only the repository permissions needed for Contents read/write. Store it in the API host's secret manager.
3. Build and deploy the `server/Dockerfile` from the repository. Configure all variables above. Expose the service only through the host's HTTPS endpoint/reverse proxy.
4. Confirm the host reports a healthy container and call `GET /healthz`. Startup also verifies repository privacy and branch access; it exits instead of serving if that verification fails.
5. Run the seed command exactly once. The container includes the seed script:
   ```sh
   npm run seed:github
   ```
   Run it as a one-off command with the same `GITHUB_JSON_REPOSITORY`, `GITHUB_JSON_BRANCH`, and `GITHUB_JSON_TOKEN` secrets. It creates only missing files and never overwrites existing profiles:
   - `players/100001.json`
   - `players/100002.json`
   - `market/listings.json`
6. Set `mshin/account/api_base_url` in the Godot project to the API's HTTPS origin (no trailing slash), and `mshin/account/auth_url` to the Cloudflare Worker origin. Keep both as deployment configuration, not credentials.
7. Verify Google login and then run the two-account acceptance cycle below.

## Two-account acceptance cycle

Use two separate browser/device sessions and verify the numeric identities are 100001 and 100002.

1. Save a different city/profile from each account; reload both and prove neither profile crosses into the other.
2. Give the seller a known quantity of an unlocked item and confirm the warehouse count.
3. List part of that stock; confirm it is reserved and no longer available to spend.
4. Buy from the second account; verify exactly one Simoleons debit, one seller credit, and one item transfer.
5. Retry the same purchase request; it must not transfer or debit twice.
6. Cancel another active listing; verify reserved stock returns exactly once.
7. Try insufficient funds, insufficient stock, locked item, full buyer warehouse, self-purchase, and a second purchase of a sold listing. Each must fail without partial balance/inventory changes.
8. Restart the API container and verify both player files and market history remain available.

Do not call the market production-ready until this cycle passes against the deployed host. The current game inventory/production save payload is still client-authoritative; the market wallet and market transactions are server-controlled, but a modified client can still attempt to falsify non-market inventory. Keep this as a controlled two-account test.

## Operations and recovery

- Keep one API writer instance and use HTTPS only.
- Keep the GitHub token and auth secret in the host's secret manager; rotate them if exposed.
- Back up the private repository and periodically test restoring a copy to a separate private repository.
- Monitor API response latency and GitHub API quota. GitHub JSON storage is versioned file storage, not a transactional database designed for frequent autosaves or many concurrent players.
- Do not enable public repository access, client-side GitHub credentials, filesystem fallback in production, or multiple API replicas.
