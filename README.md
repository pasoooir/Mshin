# Mshin — 2D Top-Down Arcade Racing

Mshin is a colorful top-down arcade racing game targeting Cocos Creator 3.8.6 + TypeScript, with a lightweight browser-playable edition hosted on GitHub Pages.

## Play the browser edition

Open [the GitHub Pages game](https://pasoooir.github.io/Mshin/) and choose from **10 themed worlds and 50 playable stages**. The browser edition includes procedural tracks, themed scenery and hazards, touch joystick, gas/brake/nitro controls, keyboard controls, lap timing, three AI rivals, live race position, a circuit minimap, weather effects and weather-dependent handling, pause/finish screens, and local best-time/progress storage.

The garage starts with three cars: Rally Fox (balanced), Comet GT (top speed), and Lynx 4x4 (high grip). Two additional cars — Thunder EV and Desert Raptor — can be unlocked with coins earned by finishing races. A local workshop lets players buy up to three engine, tyre-grip and nitro upgrades for each car. Five milestone achievements reward extra coins for a first finish, podiums, exploring worlds, collecting all cars and fully tuning a vehicle. Coins, unlocks, achievements, upgrade levels, best times and vehicle selection persist on the device. Collect glowing track pickups to recharge nitro, then trigger a temporary speed boost.

The browser edition is a landscape installable PWA. Its versioned service worker (`mshin-arcade-v7`) precaches the 15 vector illustrations/sprites and refreshes the complete app shell; photographic world scenes are decoded before the menu appears before the game is considered ready, and serves it offline. The browser boot process decodes art before importing the race runtime; gameplay does not fetch or decode art during a race. No backend is required for gameplay.

## Project implementation

- Browser game entry: `index.html` + `src/web-game.js` (Canvas 2D, no external runtime dependency).
- Cocos Creator runtime components: `assets/scripts/`.
- Cocos Creator 3.8.6 Editor bootstrap and current scene requirements: [`docs/COCOS_CREATOR_38_SETUP.md`](docs/COCOS_CREATOR_38_SETUP.md).
- Shared Cocos vector art palette/catalogue: `assets/resources/vector-art.json`; the Cocos runtime loads this `JsonAsset` before displaying the main menu and draws world landmarks and cars through `Graphics`.
- Browser vector art: `assets/vector/` + `src/asset-manifest.json`; bounded preload/decode loader: `src/asset-loader.js`.
- Engine-independent game logic and deterministic 50-stage catalog: `src/`.
- World/stage planning metadata: `data/worlds.json`, `data/stages.json`.
- 50 SVG stage concept previews: `cdn/previews/` (not final in-game art).
- Offline browser progress and settings: `localStorage`; selected car, mute preference, stage completion and best times remain on the device. Cocos adapter uses `sys.localStorage`.
- PWA: `manifest.webmanifest`, `service-worker.js`, and `icons/mshin.svg`; offline-first app-shell caching is covered by Playwright.
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
