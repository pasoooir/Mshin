# Pasoo City BuildIt

**Version 1.0.0 — Playable Godot project**

A self-contained, mobile-first 3D city-building game built with **Godot 4.3+**, GDScript and the GL Compatibility renderer (required for browser export). All gameplay code and generated visuals are local; the project does not need a network connection after import.

## Play in a browser

After the **Mshin Playable Web** GitHub Actions workflow succeeds, open [Play Mshin](https://pasoooir.github.io/Mshin/) on a phone or desktop browser. Tap **PLAY MSHIN**; the launcher opens the exported game and requests fullscreen and landscape orientation where the browser allows it. No Godot installation is required for players.

The web build is generated automatically from this Godot project and deployed to GitHub Pages. The first deployment may take a few minutes.

## Open and run in Godot

1. Download and install the **standard (non-.NET) Godot 4.3 or newer editor** from the [official Godot download archive](https://godotengine.org/download/archive/).
2. Open Godot Project Manager and choose **Import**.
3. Select this folder: `godot-city-buildit/project.godot`.
4. Wait for the first asset/script scan to finish.
5. Select the imported project and press **F6** to run the main scene or **F5** to run the project.

From a terminal at the repository root:

```bash
godot --path godot-city-buildit
```

Main scene: `res://scenes/main.tscn`.

## Latest production UI update (2026-11-16)

The production queue now presents only real orders in a live, touch-friendly order panel. Empty queue placeholders are hidden; product taps place an order into the first available internal slot. Each active order shows its state, live countdown, progress, and a storage-aware Collect action. Queue capacity, production scheduling, recipe validation, and City Storage transfers remain backed by the existing gameplay systems.

## Godot quality and acceptance contract

The mandatory engineering rules for mobile/web compatibility, rendering, input, production UI, asset pipeline, dependency selection and CI acceptance are documented in [Godot Quality & Acceptance Contract (FA)](docs/GODOT_QUALITY_AND_ACCEPTANCE_CONTRACT_FA.md). Treat this as the implementation gate for all future Godot work.

## Production economy and city-needs design

The detailed gameplay design contract is maintained in the [Persian Production Economy & City Needs Specification](docs/PRODUCTION_ECONOMY_AND_CITY_NEEDS_SPEC_FA.md), with a [technical English companion](docs/PRODUCTION_ECONOMY_AND_CITY_NEEDS_SPEC.md). These documents distinguish EA-confirmed behaviour, community-reference item data, and existing Mshin-specific rules.

## Live production economy and City Needs

- ProductionManager is the authoritative catalog for 11 raw materials, 32 craftable items and 42 catalog-only identities, factory-tier permissions and store recipes. Storage display metadata is derived from this catalog.
- All 14 standard SCBI commercial store families are selectable and have store-specific product panels. The current verified recipe sets are Building Supplies (6), Hardware (6), Farmer's Market (7), Furniture (5), Fast Food (5), Donut Shop (1) and Home Appliances (2). The other known products remain visible but disabled until their exact recipes are verified. Traditional Restaurant and Art Supplies are Mshin-specific custom stores and show an explicit no-verified-catalog state.
- Every production slot stores start/finish timestamps, consumes craft inputs atomically at order start, and adds its output to City Storage only after the player collects it. A full warehouse blocks collection without deleting the ready batch.
- Construction finish timestamps are saved and restored. Old save version 1 remains loadable; version 2 stores the construction timestamp.
- The persistent City Needs HUD action aggregates all completed residential upgrade plans, allocates shared stock across homes without double-counting, and displays the complete City Storage inventory, stored / producing / ready / deficit counts, supplier routes, next-ready ETA, every active production job, currencies, XP, population and happiness.
- Selecting a home opens its detailed upgrade plan; the city-wide dashboard exposes all home requirements without opening each building.

Detailed implementation status and acceptance evidence: [Production Economy Implementation Tracker](docs/PRODUCTION_ECONOMY_IMPLEMENTATION_TRACKER.md).

## First city — complete gameplay loop

1. Tap the **road** icon and place a connected road chain. Each tile costs 50 Simoleons; after the first tile, each new tile must connect to the existing road network.
2. Tap **house** and place a house beside the road.
3. Tap **factory** and place a factory beside the road.
4. Tap **shop** and place a Building Supplies shop beside the road.
5. Wait for construction and factory production. Tap the factory when its green check appears to collect Metal.
6. Tap the Building Supplies shop to craft Nails from Metal.
7. Collect another Metal from the factory.
8. Tap the house when its yellow hard hat appears. The house upgrades, its population increases, and the city gains XP.

The first upgrade consumes **1 Nail + 1 Metal**. House progression has six stages. The initial city starts with 5,000 Simoleons so the complete starter loop, including two utilities, can be tested immediately.

## Residential architectural progression — first implementation slice

Residential upgrades retain their available local GLTF base models, while level-specific procedural geometry is layered on top so the imported base does not freeze the house silhouette. The bespoke level-one villa hero remains intact. Villa stages 2–6 add distinct building massing and silhouettes: attached garage/roof wing, offset upper floor and balcony, glass sunroom/pergola terrace, split-level modernist volume with roof garden and solar canopy, then a premium penthouse volume with full-height glazing. Apartment progression has podium/wing/glass-core/tower-crown changes; farm progression adds a barn, silo, greenhouse and expanded crop infrastructure.

Commercial buildings now have trade-specific silhouettes and props for restaurants, fast food, hardware, markets, furniture, gardening, donuts, appliances, fashion, sports, toys, restoration, country stores and desserts. Industrial tiers distinguish small/basic/mass/high-tech/nano facilities with tier-specific equipment. Civic/service models add recognisable fire, police, health, water, sewage, waste, power and town-hall features. The pocket park now includes paths, planted beds, benches and a fountain. A follow-up refinement also distinguishes the chain-store facade from independent retail, deluxe wind generation from the standard turbine, and the elevated water tower from the ground-level pumping station.

This is an implemented procedural visual foundation, **not** a claim that the full catalog has production GLB assets. Commercial, industrial, civic/service and recreation assets still require their own type-specific models; residential stages also remain subject to in-game visual review and mobile performance profiling. The automated validator checks that the stage-specific architecture paths remain present and that residential buildings are not masked by the shared category GLTF.

## Visual foundation — Phase 0.1 first slice

The coastal environment uses local procedural assets only (no runtime downloads): multi-palette terrain vertex colors, instanced grass blades and varied tree crowns, a layered beach/shallow-water transition, animated blue/turquoise water shader, locally generated asphalt grain, raised curbs and sidewalks. Building facades include framed windows, doors, awnings, roof details, signs and industrial vents; construction completion uses a lightweight sparkle burst. Warm directional fill and atmospheric fog are configured for the GL Compatibility renderer.

This is the first visual-quality slice, not the final art target: production-quality GLB building families, richer road intersections/markings, stronger shoreline foam/reflections, mobile GPU profiling and a verified 60 FPS budget remain open.

## HUD and local icon assets

Existing HUD/build icons use local transparent 128×128 PNG artwork. Newly added production products and commercial stores may use local transparent SVG artwork when no PNG exists; scripts/ui/Icons.gd resolves PNG first, then SVG, then the safe placeholder. All assets are bundled locally and work offline. The validator continues to enforce PNG requirements for required build icons and accepts a local PNG or SVG for catalog-only products. The artwork is original and uses no third-party icon pack or external runtime assets.
\n## City services

The HUD keeps a persistent service-alert banner visible while completed homes lack an unlocked service or Gateway road access. It reports affected home counts for road access, power, water, sewage, waste, fire, police and health; each service group is included only from its catalog unlock level. The banner clears automatically when coverage is restored. This is a residential service warning, not a claim that non-residential buildings consume the same service demand.

Wind power and water towers each provide 12 units of capacity within a 28 m coverage radius. Each completed home requires 2 power and 2 water. The HUD shows capacity used, and city happiness is calculated from homes receiving both services.

## Controls

- **Mobile:** landscape orientation; one-finger drag pans; two-finger pinch zooms and twist rotates the camera; while a building is selected for placement, hold on the map for 0.55 seconds to rotate its preview by 90° (repeat to continue), then tap a valid plot to place.
- **Desktop:** left-drag pans; mouse wheel zooms; press `R` to rotate a selected building preview by 90°; left-click places or interacts.
- The placement preview is green on a valid plot and red on an invalid plot.
- Successful building placement and successful product collection request short optional vibration pulses through the browser Vibration API in Web builds. Browsers/devices without API support continue silently; native Android/iOS haptics and physical-device behavior are not yet verified.
- The right-side vertical toolbar uses locally drawn vector icons (no emoji glyphs, external textures or CDN): roads, residential, commercial, industrial, services, specializations and bulldoze. Selecting a category opens a compact icon-only submenu. Storage, trade, save and cancel remain in the bottom action row. Specialization options beyond parks and destructive bulldozing are currently UI entry points; their full gameplay behavior is not yet implemented.
- The **save** icon writes the city immediately. The game also autosaves every 30 seconds and on window close.
- **Trade Depot** unlocks at 8,000 population and must be placed/completed in Services → Trade. It provides four timed sale slots; goods are removed when listed and Simoleons are collected manually when a listing is ready.
- **Global Trade HQ** unlocks at 10,000 population and must be placed/completed in Services → Trade. Its purchase board is currently an offline local simulation, not a live player-to-player marketplace. Trade listings, market offers, ship manifest, departure state and return timer are included in save version 3.
- **Cargo Port** unlocks at 20,000 population and opens the Cargo Ship tab. Load all three manifest crates from City Storage; each crate consumes its exact requested quantity. Completing the manifest grants one Golden Key, sends the visible 3D ship into open water, and returns it after 180 seconds with a new manifest. The manifest, departure state and return timer are saved.
- Citizen feedback bubbles appear above completed residential buildings in short rotating groups. They identify road, utility, sewage, waste and emergency-service gaps; tapping a bubble opens the corresponding home's residential panel. The bubbles are contextual UI feedback, not animated citizen/NPC characters.

## Validation and automated gameplay test

Run the static validator:

```bash
python tools/validate_project.py
```

Run the automated gameplay integration test with Godot:

```bash
godot --headless --path godot-city-buildit res://tests/gameplay_smoke.tscn
```

The integration test builds a connected road, checks building footprints and road access, completes construction, collects two Metal, crafts Nails, verifies power/water coverage, upgrades the house, checks population growth and writes a save file. GitHub Actions runs this test using Godot 4.3 on every relevant push and pull request.


## Senior-friendly popup accessibility — 2026-11-16

Popup/detail-window typography now has a 16 px minimum after UI scaling, rather than allowing dense labels to fall to 8–13 px. Factory/store product cards and residential material tokens are enlarged together with their icons and six-sided 3D platforms. This change is intended for mobile landscape and low-vision users; physical-device verification is tracked separately and is not inferred from automated tests.


## Production queue panel rebuild — 2026-11-16

- [x] Replaced the dark production dock styling with a blue, rounded queue panel inspired by the supplied reference image.
- [x] Moved the panel to the top of the screen and kept the building title inside the panel.
- [x] Empty queue slots now use bright, high-contrast plus markers; occupied slots use larger local product artwork.
- [x] Queue countdown labels display remaining whole seconds (for example, `295s`) and refresh from each slot's persisted finish timestamp.
- [x] Product selection still submits directly to the first available slot through the existing production component; recipe checks, ingredient consumption, collection and storage capacity remain authoritative.
- [ ] Verify the complete touch-to-queue-to-countdown-to-collection lifecycle in Godot CI and on a physical mobile device. The latter is not claimed by automated tests.


### CI regression correction — 2026-11-16

- [x] Restored the six visible production queue tiles required by the commercial production dock contract; smaller purchased capacity remains visibly locked rather than disappearing.
- [x] Kept the redesigned blue queue styling while restoring the six-tile layout.
- [ ] Re-run both Godot validation and playable-web workflows; confirm they pass before merge.

## Smart non-blocking city coach — 2026-11-16

- [x] Replaced the large centered tutorial modal with a compact, translucent floating coach near the top-left; it no longer covers the center of the city.
- [x] Set the coach background to pass pointer/touch input through to the city; only its explicit action buttons handle interaction.
- [x] Added an icon-first quick legend for roads, homes, factories, shops and City Storage, while keeping one contextual task, tap path and expected result visible.
- [x] Reduced the reopen affordance to a small persistent **☁ HELP** button; players can dismiss the coach and reopen it at any time.
- [x] Added periodic reconciliation against the live building registry and City Storage as a recovery path when a gameplay event occurs before the guide connects; milestone completion still depends on real city state and collected inventory.
- [x] Godot GameplaySmoke and Playable Web desktop/mobile Chromium checks passed after the pointer-target correction (PR #559; main runs 43848134141 and 43848134338). Android landscape review on a physical device remains open.
- [ ] Verify click-through behavior, text wrapping, touch targets and HUD overlap on a physical Android device.


## City coach input propagation correction — 2026-11-16

- [x] Changed the floating coach container from input-ignore to input-pass so child guide actions can receive taps while taps on the coach background continue to underlying HUD controls.
- [x] Set the guide layout containers to input-pass and the Later, Skip/Close and HELP buttons explicitly to input-stop.
- [x] GameplaySmoke exercises native screen-touch interaction for city-name entry, SAVE CITY, Later, HELP, Residential, Villa House details and BUILD; the coach finger is checked against the actual Residential, Villa House and BUILD controls.
- [ ] Verify on a physical Android device in landscape; CI/browser success is not a substitute for device acceptance.


## Actionable first-session city coach — 2026-11-16

- [x] Added a real **Name your city** first step with an editable field and SAVE CITY action; players are no longer told to enter a name without an actual input.
- [x] Added a moving finger pointer that points at the city-name field and resolves named HUD targets for later guide steps when those controls are visible.
- [x] Persisted the city name in the game save; legacy saves without a city name migrate to **Pasoo City**.
- [x] Expanded GameplaySmoke to require the city-name step, validate blank-name rejection and the 28-character limit, and simulate real screen touches on SAVE CITY, Later, HELP, the Residential HUD action and an underlying HUD control beneath the coach background.
- [x] GameplaySmoke native-touch regression passed: city-name LineEdit focus, SAVE CITY, Later, HELP, Residential category, Villa House details and BUILD all handled through `InputEventScreenTouch` without synthetic mouse emulation (commit `7ce8942`).
- [x] Godot City BuildIt Validation and Mshin Playable Web Chromium desktop/mobile smoke both passed on commit `7ce8942`.
- [ ] Verify the complete touch experience on a physical Android landscape device; CI does not replace device testing.
- [x] Merged as PR #559 (commit `a85c0c6f4f90c03082be8befe9e79195fd17b115`) and confirmed GitHub Pages deployment in run 43848134338.
- [x] Godot GameplaySmoke and playable-web Chromium desktop/mobile checks passed on the merged main commit (runs 43848134141 and 43848134338).
- [x] Automated pointer alignment checks now cover the category button, catalog card and BUILD action; the LineEdit focus/keyboard request path and native touch buttons are covered by GameplaySmoke.\n- [ ] Verify the complete experience, including the on-screen keyboard, on a physical Android landscape device. Physical-device acceptance is not claimed.


## City coach: actionable touch guidance and fixture safety — 2026-11-16

- [x] First onboarding step provides a real city-name field and SAVE CITY action; the animated finger points to that field.
- [x] Construction steps point to the actual BUILD action before guiding the player to a valid road-connected plot; factory and store instructions now describe the same tap sequence.
- [x] The finger cue uses a small press/release pulse so it reads as an action pointer rather than a static decoration.
- [x] Building notification polling ignores non-Building test/migration fixtures before reading Building-only fields; the integration smoke test explicitly refreshes notifications while such a fixture is registered.
- [x] Main-branch verification passed after merge: Godot City BuildIt Validation [run 43842039456](https://github.com/pasoooir/Mshin/actions/runs/43842039456), including GameplaySmoke and Android Debug APK export; Playable Web [run 43842039295](https://github.com/pasoooir/Mshin/actions/runs/43842039295), including desktop/mobile Chromium launch and GitHub Pages deployment.
- [ ] Physical Android acceptance in landscape remains outstanding; CI touch simulation and Chromium mobile viewport are not a substitute for testing on the user's phone.


## City coach pointer-target root-cause correction — 2026-11-16

- [x] Fixed the tutorial's submenu lookup: `ToolSubmenu` is nested inside `ToolSubmenuScroll`, so a direct-child lookup left the finger stuck on the category icon after the player opened Residential/Industrial/Commercial.
- [x] Converted pointer anchors between the HUD and coach CanvasLayers through viewport coordinates; this avoids mixing local Control positions with another CanvasLayer's global rectangle.
- [x] Extended GameplaySmoke to follow real `InputEventScreenTouch` actions through Residential → Villa House → BUILD and assert that the finger tracks each actual control.
- [x] Godot Validation, GameplaySmoke and Android Debug APK export passed on main: [run 43848134141](https://github.com/pasoooir/Mshin/actions/runs/43848134141).
- [x] Playable Web desktop/mobile Chromium verification and GitHub Pages deployment passed on main: [run 43848134338](https://github.com/pasoooir/Mshin/actions/runs/43848134338).
- [ ] Physical Android landscape testing remains outstanding; automated touch simulation and Chromium mobile viewport do not replace testing on the phone.
