# Mshin — 2D Top-Down Arcade Racing

Mshin is a colorful top-down arcade racing game targeting Cocos Creator 3.8.6 + TypeScript, with a lightweight browser-playable edition hosted on GitHub Pages.

## زبان بازی و اعتبار توسعه

رابط کاربری نسخه مرورگر و منوهای نسخه Cocos به فارسی ایران بومی‌سازی شده‌اند. در صفحه آغازین، نام **Hamed Babaei** به‌عنوان صاحب اثر و توسعه‌دهنده درج شده و به صفحه LinkedIn او پیوند دارد.

## Latest release: 0.9.3 — repository-local runtime assets

The game now renders volumetric 2.5D trackside scenery across all ten world themes: layered tree canopies and trunks, extruded building faces and roofs, human-shaped spectator crowds, faceted rocks, contact shadows and a moving helicopter silhouette. The release also includes the independently controlled CC0 music/SFX system and verified offline audio cache from 0.8.9.

Version 0.9.3 vendors all 23 external runtime assets (10 photographic scenes, 3 control icons and 10 audio files) into `cdn/assets/`, removes runtime CDN fallbacks, and precaches the complete local asset set with service-worker cache `mshin-arcade-v34`. The eight-second aerial-lighting refresh from 0.9.2 remains included.

## Play the browser edition

Open [the GitHub Pages game](https://pasoooir.github.io/Mshin/) and choose from **10 themed worlds and 50 playable stages**. The browser edition includes large-scale race circuits, four clearly marked driving lanes on a 360-unit asphalt surface, a pulled-back forward-facing chase camera, tangent-aligned player and rival cars, themed scenery and hazards, touch steering, icon-only repository-local gas/brake/nitro controls, keyboard controls, lap timing, three AI rivals, live race position, a circuit minimap, weather effects and weather-dependent handling, deterministic player/AI and AI/AI collision impulses, cumulative localized damage, impact-dependent smoke/sparks/camera shake, pause/finish screens, and local best-time/progress storage.

The garage starts with three cars: Rally Fox (balanced), Comet GT (top speed), and Lynx 4x4 (high grip). Two additional cars — Thunder EV and Desert Raptor — can be unlocked with coins earned by finishing races. A local workshop lets players buy up to three engine, tyre-grip and nitro upgrades for each car. Five milestone achievements reward extra coins for a first finish, podiums, exploring worlds, collecting all cars and fully tuning a vehicle. Coins, unlocks, achievements, upgrade levels, best times and vehicle selection persist on the device. Collect glowing track pickups to recharge nitro, then trigger a temporary speed boost.

The live browser release is **version 0.9.3**, merged to `main` and deployed to GitHub Pages after successful merged-main validation and desktop/mobile Playwright browser smoke tests. Version 0.9.2 refreshes the cached aerial scene every eight seconds so stage-aware sunlight, ambient light and cast shadows keep changing during a race. It retains the volumetric 2.5D scenery and independent CC0 music/SFX mixer with verified offline audio cache. Its service-worker cache is `mshin-arcade-v32`. The browser menu now uses a motorsport-inspired vertical navigation rail with a dedicated content panel, while the Cocos runtime menus share a dark navy, red-accented angular visual system. The first screen no longer contains a latest-changes link. This release makes nearby traffic visibly smarter: three rival cars move independently, anticipate track curvature, adapt pace, keep following gaps, and smoothly choose adjacent lanes around congestion and the player. Vehicle impacts now feed a progressive destruction lifecycle: localized panels accumulate soot, dark engine smoke and flames grow with damage, critical damage triggers a one-shot explosion with camera/audio feedback, and AI wrecks burn out before fading and leaving traffic, collisions, minimap and ranking. A destroyed player car ends the race explicitly. The browser renderer uses bounded pooled particles for smoke/fire/debris effects. The release builds on 0.6.0 localized dents/scratches/cracked glass and the 0.5.0 grip-limited tire model. Its versioned service worker (`mshin-arcade-v32`) precaches the complete browser runtime—including rigid-body physics, traffic AI and vehicle destruction modules—plus the 15 vector illustrations/sprites. The boot loader also loads and decodes all ten repository-local photographic scenes, three repository-local control icons, six CC0 engine RPM layers, braking/downshift effects and two CC0 background music tracks before the game module starts; audio buffers are decoded on the first menu gesture while the player chooses a stage, so gameplay does not perform late asset requests or expensive audio decoding. No backend is required for gameplay.

## Version 0.8.5 — release consistency and localized mobile polish

- Corrected the remaining English-only portrait-orientation guidance so the Persian UI remains consistent on phones.
- Synchronized the README, splash, home-menu badge, package metadata, PWA manifest and asset catalogs on the same published release.
- Added regression checks that fail if the public release label, metadata or offline cache marker drift apart.
- Advanced the service-worker cache to v24 so existing installations fetch the refreshed release shell.

## Version 0.8.3 — vehicle identity, cinematic intro and traffic rewards

- Replaced synthesized sawtooth engine audio with repository-local race-car idle/rev recordings, braking and downshift effects from SFXMint CC0 1.0 (AI-generated assets, not field recordings).
- Expanded the asphalt to a four-lane road with three visible separators and four AI lane centers.
- Pulled the chase camera back so the complete road width remains visible on desktop and mobile.
- Added an animated 3 → 2 → 1 → GO countdown; player and AI movement begins together only after GO.
- Replaced gas, brake and nitro button text with accessible repository-local SVG icons.
- Boot preloads all world art, car sprites, photographic scenes, icons and audio data before importing the game loop.
- Advanced the visible release to 0.8.2 and service-worker cache to v19.

## Latest published build

The live game is **version 0.9.3**. PR #52 vendors all 23 external runtime assets into `cdn/assets/`, keeps all 38 runtime asset references local, removes CDN runtime dependencies, and precaches the complete set using `mshin-arcade-v34`. Merged-main validation run `41206965694` and GitHub Pages deployment run `41206965179` both succeeded for commit `07695e04a4645dedd6fc0fed6a85ffbd8f895412`.

## Project implementation

- Browser game entry: `index.html` + `src/web-game.js` (Canvas 2D, no external runtime dependency).
- Cocos Creator runtime components: `assets/scripts/`; localized body creases and engine-damage smoke are rendered by `VehicleDamageRenderer.ts`.
- Cocos Creator 3.8.6 Editor bootstrap and current scene requirements: [`docs/COCOS_CREATOR_38_SETUP.md`](docs/COCOS_CREATOR_38_SETUP.md).
- Shared Cocos vector art palette/catalogue: `assets/resources/vector-art.json`; the Cocos runtime loads this `JsonAsset` before displaying the main menu and draws world landmarks and cars through `Graphics`.
- Browser vector art: `assets/vector/` + `src/asset-manifest.json`; bounded preload/decode loader: `src/asset-loader.js`.
- Engine-independent game logic and deterministic 50-stage catalog: `src/`.
- World/stage planning metadata: `data/worlds.json`, `data/stages.json`.
- 50 SVG stage concept previews: `cdn/previews/` (not final in-game art).
- Offline browser progress and settings: `localStorage`; selected car, mute preference, stage completion and best times remain on the device. Cocos adapter uses `sys.localStorage`.
- PWA: `manifest.webmanifest`, `service-worker.js`, and `icons/mshin.svg`; offline-first app-shell caching is covered by Playwright.
- Stateless optional Worker API: `workers.js`; see `docs/CLOUDFLARE_WORKER.md`.

## Vehicle collision and damage

The browser edition resolves player/AI and AI/AI contacts with a mass-weighted 2D impulse model and static hazard contacts with a barrier solver. Closing speed, contact normal, restitution, tangential friction and overlap correction determine velocity changes. Cumulative front/rear/left/right damage drives body overlays, smoke, handling loss and critical power reduction. See [the collision model notes](docs/VEHICLE_COLLISION_DAMAGE.md).

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
