# Cloudflare Worker API

The API entry point is `workers.js` and the Wrangler configuration is `wrangler.toml`.
It is intentionally stateless and compatible with a no-storage deployment:

- `GET /api/v1/health` — service and version health check.
- `GET /api/v1/config` — public game metadata (10 worlds / 50 stage slots).
- `OPTIONS` — CORS preflight for approved origins.

The GitHub Pages origin `https://pasoooir.github.io` and local development origins on port 8080 are allowed by default. Additional exact origins may be supplied through the non-secret Worker variable `ALLOWED_ORIGINS`, as a comma-separated list. The Worker does not use wildcard CORS.

## Data and cost boundary

Gameplay progress and best times remain local-first in the game via browser/device storage. This Worker does **not** claim to save player data or provide a leaderboard. Server persistence would require a separately reviewed storage choice and explicit approval before provisioning or changing bindings. There is no R2, D1, KV, Durable Object, paid service, secret, or external asset-storage dependency in this configuration.

## Local validation

```sh
node --check workers.js
node --test tests/worker.test.mjs
```

## Deployment (not performed by this change)

After reviewing the Worker in the Cloudflare dashboard, deploy from the repository root with Wrangler and the account's approved authentication context:

```sh
npx wrangler deploy
```

No deployment, account change, secret update, or paid resource creation is performed by CI. The API URL should be configured in the game client only after a Worker deployment has been explicitly approved and verified.
