## Version 0.15.2 — professional multi-touch racing controls (merged)

- Added independent pointer tracking for gas and brake, so one finger can release without cancelling another held finger.
- Preserved simultaneous steering, throttle, braking and nitro input across separate touch pointers; interruption, pause, restart and visibility loss clear stale held inputs safely.
- Enlarged mobile steering, pedal and nitro touch targets and added clear pressed-state feedback with touch-action protection.
- Added dedicated multi-pointer unit coverage; the merged commit passed the portable validation suite (229 tests, 0 failures).
- Advanced the offline service-worker cache to mshin-arcade-v53 and precached the new multi-touch input module.
- Browser smoke still reports a failure in the pre-existing economy-race completion scenario; this is tracked separately and is not represented as a passing gameplay test.

## Version 0.15.0 — automotive PBR materials and studio reflections (under review)

- Replaced the previous flat diffuse/metal tint with a shared WebGL 1 metallic-roughness physically based shading pipeline for both the 360-degree showroom and live race scene.
- Added Cook–Torrance GGX specular response, Schlick Fresnel, energy-aware diffuse, metallic response, automotive clearcoat and filmic highlight roll-off.
- Added a locally generated six-face studio environment cubemap with large softbox reflections; no external HDRI, CDN or runtime download is required.
- Added material-specific procedural surface detail: metallic paint micro-flake, carbon-fibre twill on aero parts, rubber sidewall grain and brushed-alloy highlights. Body paint, glazing, trim, rubber, rims, lamps, aero and decals now use distinct metallic/roughness/clearcoat presets.
- The same PBR shader and material definitions are shared by showroom and gameplay, including player and AI cars. WebGL context restoration rebuilds the PBR program and environment.
- Cache advanced to `mshin-arcade-v48`; the new shader module is precached for offline use. Browser GPU validation is required before this draft can be considered complete.
- These are locally generated procedural materials and studio lighting, not scanned photogrammetry assets; no scanned-source provenance is claimed.

## Version 0.14.0 — true 3D 360-degree vehicle showroom (under review)

- Replaced the garage's flat SVG image and CSS perspective rotation with an actual WebGL vehicle model rendered on a canvas.
- Added five garage profiles plus five distinct AI race-car profiles, all generated locally from one shared model builder with sculpted body sections, glazed cockpit, wheel arches, flared fenders, alloy wheels, brake details, lights, mirrors, side skirts, splitters and racing aero.
- Touch/mouse dragging now orbits a real 3D camera around the vehicle; the 360-degree button performs a full camera orbit rather than rotating a flat image.
- The same generated vehicle meshes are used by both the 360-degree garage and the live race renderer, so the selected car no longer changes shape between showroom and gameplay. The renderer is repository-local and precached for offline use. Version 0.15.0 adds shared PBR materials to these meshes. No runtime model CDN is required.
- Browser and device validation are required before this draft can be considered complete.

## Version 0.12.0 — sculpted in-race 3D vehicle (merged)

- Rebuilt the vehicle visible on the race track as a tapered, multi-section WebGL body instead of stacked rectangular primitives.
- Added pronounced body character creases along both flanks, hood power lines, wheel-arch lips, sculpted side sills, sloped glazing, LED lamps, grille, splitter, diffuser and rear wing.
- Added rubber tires and metallic wheel hubs. Geometry is generated locally by the WebGL renderer; no runtime CDN/model download is required.
- The sculpted in-race vehicle geometry was merged to `main` in pull request #77; the current showroom work is tracked separately in version 0.14.0.

## Version 0.11.7 — verified live release on main

- Verified browser release on GitHub Pages.
- The WebGL race scene is visible and the offline app shell uses cache `mshin-arcade-v44`.
- The 0.12.0 vehicle geometry is merged; the 0.14.0 WebGL showroom remains under review.

# Mshin — 2D Top-Down Arcade Racing

Mshin is a colorful top-down arcade racing game targeting Cocos Creator 3.8.6 + TypeScript, with a lightweight browser-playable edition hosted on GitHub Pages.

## زبان بازی و اعتبار توسعه

رابط کاربری نسخه مرورگر و منوهای نسخه Cocos به فارسی ایران بومی‌سازی شده‌اند. در صفحه آغازین، نام **Hamed Babaei** به‌عنوان صاحب اثر و توسعه‌دهنده درج شده و به صفحه LinkedIn او پیوند دارد.

## Version 0.11.0 — first true 3D race-rendering milestone

This branch introduces a native, repository-local WebGL perspective renderer for the active race scene. During countdown and gameplay, the browser now renders a perspective chase-camera view with a generated 3D road surface, shoulders, lane markings, three-dimensional roadside geometry, and mesh-based player/rival vehicles. The 2D game simulation remains the source of truth for vehicle motion, traffic, collisions, damage, pickups, race progression, and controls; the new renderer consumes that live state rather than replacing the gameplay physics. The renderer is bundled locally and precached by the service worker, with no runtime CDN dependency. This is the first migration milestone, not a claim that every legacy visual/effect has already been ported to 3D; minimap, weather overlays, particle effects, and full 3D damage deformation remain follow-up work.

## Latest published release on main: 0.15.2

Version 0.15.2 is published on GitHub Pages. The portable validation suite passed (229 tests, 0 failures), and GitHub Pages build/deployment run 41391832740 completed successfully. The offline service-worker cache is `mshin-arcade-v53`.

Versions 0.11.0–0.11.6 were published on GitHub Pages; the in-race vehicle geometry was merged afterward in pull request #77. Version 0.14.0 remains a separate draft and is not claimed as live.

## Play the browser edition

Open [the GitHub Pages game](https://pasoooir.github.io/Mshin/) and choose from **10 themed worlds and 50 playable stages**. The browser edition includes large-scale race circuits, four clearly marked driving lanes on a 360-unit asphalt surface, a pulled-back forward-facing chase camera, tangent-aligned player and rival cars, themed scenery and hazards, touch steering, icon-only repository-local gas/brake/nitro controls, keyboard controls, lap timing, three AI rivals, live race position, a circuit minimap, weather effects and weather-dependent handling, deterministic player/AI and AI/AI collision impulses, cumulative localized damage, impact-dependent smoke/sparks/camera shake, pause/finish screens, and local best-time/progress storage.

The garage starts with three cars: Rally Fox (balanced), Comet GT (top speed), and Lynx 4x4 (high grip). Two additional cars — Thunder EV and Desert Raptor — can be unlocked with coins earned by finishing races. A local workshop lets players buy up to three engine, tyre-grip and nitro upgrades for each car. Five milestone achievements reward extra coins for a first finish, podiums, exploring worlds, collecting all cars and fully tuning a vehicle. Coins, unlocks, achievements, upgrade levels, best times and vehicle selection persist on the device. Collect glowing track pickups to recharge nitro, then trigger a temporary speed boost.

The release history and live-version status are maintained in the **Latest published release on main** section above; older feature notes below are historical.

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


## Next release candidate: 0.10.0 — NFS-inspired menu system

- Reworked the main and pause interface with angular graphite/red motorsport panels.
- Added a ten-slot pause navigation layout; only implemented actions are interactive.
- Replaced static MOST WANTED placeholders with a five-row live race/profile-derived ranking.
- Added automatic software landscape rotation for portrait browser viewports, with landscape logical canvas sizing and touch-coordinate remapping.
- Advanced the PWA shell cache to `mshin-arcade-v35`.
