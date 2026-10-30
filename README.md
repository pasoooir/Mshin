# Mshin — 2D Top-Down Arcade Racing

Mshin is a colorful top-down arcade racing game targeting Cocos Creator 3.8.6 + TypeScript, with a lightweight browser-playable edition hosted on GitHub Pages.

## Play the browser edition

Open the GitHub Pages site and choose from **10 themed worlds and 50 playable stages**. The browser edition includes procedural track variants, themed scenery and hazards, touch joystick, gas/brake, keyboard controls, lap timing, pause/finish screens, and local best-time/progress storage. It works without a backend after the page assets are loaded.

## Project implementation

- Browser game entry: `index.html` + `src/web-game.js` (Canvas 2D, no external runtime dependency).
- Cocos Creator runtime components: `assets/scripts/`.
- Engine-independent game logic and deterministic 50-stage catalog: `src/`.
- World/stage planning metadata: `data/worlds.json`, `data/stages.json`.
- 50 SVG stage concept previews: `cdn/previews/` (not final in-game art).
- Offline browser progress: `localStorage`; Cocos adapter uses `sys.localStorage`.
- Stateless optional Worker API: `workers.js`; see `docs/CLOUDFLARE_WORKER.md`.

## Cocos Creator 3.8.6 editor build

1. Install Cocos Creator 3.8.6.
2. Open this repository folder from Cocos Dashboard.
3. Create a 2D scene under `assets/scenes/` using the Editor.
4. Add a root node and attach `assets/scripts/MshinGame.ts` as a component.
5. Save the scene and set it as the startup scene in Build Settings.

**Editor gate:** the available development runner does not include Cocos Creator. A verified `.scene` asset, Editor import, Creator Web build, APK/AAB, and device QA have not yet been generated. Do not treat Node tests or the browser edition as proof of a Cocos build.

## Cloudflare Worker API

The Worker exposes `GET /api/v1/health` and `GET /api/v1/config`. It is stateless and does not store player scores or provide a leaderboard. No R2, D1, KV, Durable Objects, paid storage, or storage bindings are used.

## Validate

Requires Node.js 20+ and npm:

```sh
npm install
npm run check
```

CI validates stage data, portable TypeScript, Cocos script syntax, Worker syntax, browser runtime syntax, and Node tests. Cocos scripts still require the actual Creator Editor for engine type-check/import/build verification.
