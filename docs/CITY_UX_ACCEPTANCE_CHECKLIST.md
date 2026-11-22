# Mshin City UX Acceptance Checklist

> Purpose: evaluate the city as a mobile-first player experience, not only as a technically valid scene.
> Status vocabulary: PASS (verified), PARTIAL (incomplete or limited), FAIL (reproduced defect), NOT TESTED, NOT APPLICABLE.
> Evidence rule: never mark PASS from code inspection alone when the behavior requires runtime interaction. Record the exact test, device/browser profile, and artifact or log.

## Severity
- **P0 — Blocking:** data loss, unrecoverable progression, game cannot be played.
- **P1 — Critical:** common action is broken, accidental destructive action, touch controls unusable.
- **P2 — Major:** confusing or unreliable common workflow; workaround exists.
- **P3 — Minor:** polish, clarity, feedback, or rare edge case.

## Review record template
For every finding record:
- ID and checklist item
- Status and severity
- Exact reproduction steps
- Expected result / actual result
- Evidence (file + symbol/line, test name, screenshot/video/log)
- Root cause (confirmed or hypothesis)
- Fix and regression test
- Verification environment (Godot headless, Chromium desktop/mobile emulation, physical Android device/model)

## A. First impression and orientation
- [ ] A1. On entry, the city has a clear visual focal point and calm visual hierarchy.
- [ ] A2. The player can identify the next useful action without reading a wall of instructions.
- [ ] A3. HUD does not obscure the city or compete with the main action.
- [ ] A4. Empty plots, roads, locked areas, and interactive objects are visually distinguishable.
- [ ] A5. Initial camera framing shows a useful, attractive portion of the city.
- [ ] A6. Tutorial/hints are contextual, dismissible, and do not repeatedly interrupt.

## B. Camera and navigation
- [ ] B1. One-finger drag pans the city; a stationary tap does not pan.
- [ ] B2. Two-finger pinch zooms in/out in the intuitive direction.
- [ ] B3. Two-finger drag pans around the intended focal point.
- [ ] B4. Two-finger twist rotates smoothly without jumps.
- [ ] B5. Gesture transitions (1→2→1 fingers) do not create taps, long-presses, or camera jumps.
- [ ] B6. Cancelled/interrupted touches reset all pointer state.
- [ ] B7. Camera limits do not strand the city off-screen or expose unusable voids.
- [ ] B8. Focus-on-building and return-to-city behavior are predictable.
- [ ] B9. Camera gestures remain stable at minimum/maximum zoom and near screen edges.
- [ ] B10. Touches beginning on HUD controls never leak into camera navigation.

## C. Selection and object feedback
- [ ] C1. Tapping a visible building facade/roof selects that building, not the plot behind it.
- [ ] C2. Overlapping/tall buildings select the visually frontmost hit object.
- [ ] C3. Selection highlight and focus feedback are immediate and unambiguous.
- [ ] C4. Empty-plot taps do not silently select a neighboring building.
- [ ] C5. Road, tree, service, park, and decoration selection behavior is consistent with their affordances.
- [ ] C6. A selected object exposes only actions valid for its type and state.
- [ ] C7. Under-construction, completed, upgrading, and blocked objects communicate their state.
- [ ] C8. Tapping the same object repeatedly does not open duplicate panels or enqueue duplicate actions.

## D. Build, move, upgrade, demolish
- [ ] D1. Build catalog categories and locked items are understandable.
- [ ] D2. Cost, required resources, footprint, road access, and restrictions are visible before confirmation.
- [ ] D3. Placement preview tracks the finger and clearly distinguishes valid/invalid plots.
- [ ] D4. A tap places once; a drag does not accidentally commit a placement.
- [ ] D5. Rotation is discoverable and does not lose the chosen plot.
- [ ] D6. Cancel reliably exits placement/move/road/bulldoze modes.
- [ ] D7. Moving a building has clear origin, destination, and cancel behavior.
- [ ] D8. Invalid move/place attempts preserve the original building and resources.
- [ ] D9. Demolition is deliberate and destructive actions have appropriate confirmation.
- [ ] D10. Construction start, progress, completion, and cancellation are clear.
- [ ] D11. Long-press does not conflict with camera pan, double tap, or UI interaction.
- [ ] D12. After multi-touch, the remaining finger cannot accidentally place, move, or demolish.

## E. Roads and city connectivity
- [ ] E1. Road tool activation and exit are obvious.
- [ ] E2. Road drawing follows the finger without gaps, duplicate segments, or unintended branches.
- [ ] E3. Invalid road connections explain why placement failed.
- [ ] E4. Road upgrades target the intended segment.
- [ ] E5. Bulldoze road/building modes are visually distinct and safely cancellable.
- [ ] E6. Building access requirements are visible before construction.
- [ ] E7. Road/terrain/water boundaries do not create misleading clickable areas.

## F. Panels, HUD, and touch targets
- [ ] F1. Every panel has a visible close/back action.
- [ ] F2. Opening a panel prevents background city actions.
- [ ] F3. Opening one panel closes or replaces conflicting panels.
- [ ] F4. Panel layout fits mobile landscape and safe areas.
- [ ] F5. Buttons have adequate touch size and spacing.
- [ ] F6. Scroll areas scroll naturally and do not trigger buttons while dragging.
- [ ] F7. Mixed touches (one finger on HUD, one on city) are handled safely.
- [ ] F8. Touch cancel/focus loss clears UI pointer state.
- [ ] F9. Text, icons, costs, and status messages remain legible at target mobile sizes.
- [ ] F10. Back/Escape behavior is consistent and does not unexpectedly exit the game.
- [ ] F11. Compact landscape profiles render at 854x480 and 960x540 without clipping or overlapping HUD/catalog controls.
- [ ] F12. Tablet profiles render at 1024x768 and 1280x800 without clipped labels, hidden actions or compressed catalog cards.
- [ ] F13. Desktop profiles render at 1366x768, 1536x864 and 1920x1080 with the correct navigation profile and readable hierarchy.
- [ ] F14. Portrait resize remains a usable fallback when orientation lock is unavailable; returning to landscape restores the intended layout.
- [ ] F15. Resizing while a category/submenu is open preserves the selected category, visible close action, scrollability and valid control bounds.
- [ ] F16. Category icons are at least 48 logical px, category buttons at least 64 logical px high, labels at least 14 logical px, and interactive targets at least 48x48 logical px.
- [ ] F17. Catalog cards retain the 196x148 logical-pixel baseline, stable widths and horizontal swipe behavior; long names and locked badges remain readable.
- [ ] F18. All seven build categories and nested service/specialization groups remain reachable at every responsive profile.

## G. Economy, production, and progression
- [ ] G1. Costs and rewards are explicit before the action.
- [ ] G2. Resource shortages explain the missing amount and how to resolve them.
- [ ] G3. Production duration, queue, capacity, and collection are understandable.
- [ ] G4. Product drag/drop and tap-to-collect do not double-submit.
- [ ] G5. Storage capacity and overflow consequences are clear.
- [ ] G6. Upgrade requirements and benefits are visible before starting.
- [ ] G7. Progression locks explain their unlock condition.
- [ ] G8. Offline progress and return-from-background behavior are understandable.

## H. Services, population, and city feedback
- [ ] H1. Service coverage is inspectable and easy to exit.
- [ ] H2. Happiness/satisfaction changes explain the underlying causes.
- [ ] H3. Population, jobs, and demand indicators have clear meaning.
- [ ] H4. Warnings identify the affected area/object and a useful next action.
- [ ] H5. Emergency/service vehicles and effects do not obscure normal play.

## I. Visual comfort and readability
- [ ] I1. Default view is calm, attractive, and not overloaded with markers.
- [ ] I2. Visual hierarchy distinguishes roads, plots, buildings, services, and interactive states.
- [ ] I3. Selection/placement colors are distinguishable and not color-only where avoidable.
- [ ] I4. Camera motion, focus transitions, and effects avoid abrupt disorientation.
- [ ] I5. Day/night, shadows, water, terrain, and roads preserve visual readability.
- [ ] I6. Close and far views both communicate useful detail without visual noise.

## J. Performance, resilience, and accessibility
- [ ] J1. Target mobile landscape resolution maintains usable frame pacing.
- [ ] J2. Large-city object counts do not cause severe input latency or frame drops.
- [ ] J3. UI remains responsive during production, construction, and camera motion.
- [ ] J4. App pause/resume and browser tab visibility do not leave stuck pointers or modes.
- [ ] J5. Save/load preserves city state and does not duplicate or lose actions.
- [ ] J6. Critical actions have non-color cues and readable labels/icons.
- [ ] J7. Reduced-motion / audio-off scenarios remain usable.
- [ ] J8. Errors and network/offline states are recoverable and explained.
- [ ] J9. Normal text meets 4.5:1 contrast and large text/meaningful boundaries meet 3:1 where applicable.
- [ ] J10. Focus states are visible and navigable by keyboard; state is not communicated by color alone.
- [ ] J11. Reduced-motion preferences are respected where supported; animation and camera movement do not cause discomfort.

## Current audit notes (2026-11-22)
- **AUDIT-001 — Mixed HUD/world multi-touch isolation: PARTIAL; P1/P2 acceptance remains open.**
  - Implemented guard: HUD exposes `has_active_native_ui_touch()`; CameraController and CityInput block world interaction while HUD owns a pointer.
  - PR #656 adds a live-scene GameplaySmoke sequence for both HUD→world and world→HUD start orderings. It routes a real temporary HUD `Button` through `_route_native_ui_touch`, invokes both actual world handlers for the other pointer, and asserts that camera/city pointer state is cleared and a cancelled HUD release never activates the button.
  - This is an engine-level handler integration test, not a physical touch-controller test. Browser CDP still dispatches generic canvas gestures; it does not prove the HUD hit target was touched.
  - Required next: browser/device test against measured visible HUD coordinates; repeat with each finger released in both orders, and on physical Android. Do not mark F7 PASS yet.
- **AUDIT-002 — World pointer event propagation: FIX IMPLEMENTED; PR #655 CI PASS.**
  - Root cause: CameraController and CityInput independently own pointer state; consuming a HUD-blocked or OS-cancelled pointer in the first `_unhandled_input` handler could prevent the sibling handler from clearing its state.
  - Fix in PR #655: HUD-owned touch/drag, modal-blocked pointer events and cancelled releases are not consumed by either world handler. Both handlers clear their own state; non-pointer modal input remains consumable.
  - Regression evidence: PR #655 GameplaySmoke tests the shared pointer-consumption rule for touch, drag and keyboard events. Full real mixed-finger interaction remains an open runtime test.
- **AUDIT-003 — Camera gesture math and building selection: AUTOMATED COVERAGE, NOT FULL DEVICE ACCEPTANCE.**
  - Existing tests cover pinch direction/scale invariance, rotation across the +/-180-degree seam, focal-anchor correction, and facade/roof building selection.
  - Chromium touch emulation and physical-device gesture feel, edge behavior, and frame pacing remain separate acceptance requirements.
- **AUDIT-004 — Touch cancellation and app focus loss: AUTOMATED COVERAGE.**
  - PR #654 adds regression checks for normal/cancelled/dragged release handling, stale camera inertia reset, city pointer/road-stroke cleanup, and HUD touch ownership cleanup.
  - Godot validation and Android Debug APK export/signature verification passed; Web/mobile Chromium smoke passed on commit `468f92067ce61580fa6e446012456598facf287c`.
  - Physical Android interruption, notification shade, app switch, screen lock, and resume behavior remain NOT TESTED.
- **AUDIT-005 — Checklist completion state: OPEN.**
  - No A–J item is globally marked PASS solely from code inspection or CI. The checklist remains an acceptance plan until each item has reproducible evidence recorded against its required environment.
- **AUDIT-006 — Escape key did not cancel active city tools: FIX IMPLEMENTED; PR #655 CI PASS.**
  - Responsive UX standard requires Escape to close the current panel or cancel the active tool; prior HUD routing only used X for tool cancellation, while Escape was reserved for detail panels.
  - PR #655 adds Escape handling for production panel close, build-menu close, and active placement/move/road/road-upgrade/bulldoze cancellation. Backspace remains a production-panel close shortcut; X remains supported.
  - Physical keyboard and Android system-back behavior still require device/browser verification.
- **AUDIT-007 — Mixed-pointer event fan-out: FIX IMPLEMENTED; PR #655 CI PASS.**
  - Both CameraController and CityInput let HUD-blocked touch/drag events reach the sibling handler after clearing their own state; non-pointer modal input remains consumable.
  - GameplaySmoke verifies the propagation policy. AUDIT-008 adds the stronger live-scene handler sequence for both start-order permutations.
  - Browser/device hit-testing and physical Android behavior remain unverified; F7 remains PARTIAL.
- **AUDIT-008 — Live mixed-touch handler integration: IMPLEMENTED; PR #656 CI PASS.**
  - `GameplaySmoke._test_mixed_hud_world_touch_isolation` runs in the actual gameplay scene with a temporary HUD Button and the real HUD router, CameraController and CityInput handlers.
  - It covers HUD-first then world touch, world-first then HUD touch, world drag/release while HUD owns a finger, OS-cancelled releases, stale pointer/road-stroke cleanup, camera transform invariance, unchanged building/road counts, and accidental button activation.
  - Assertions are on runtime handler state, not merely static policy helpers. The probe button is removed before the rest of gameplay smoke proceeds.
  - PR #656 Godot validation, GameplaySmoke, Android Debug APK export/signature verification, and Chromium desktop/mobile Web build all passed. The PR was merged as `06cd613e27bc113f8c6884e57e3848d4e39b8eeb`.
  - Remaining gap: browser CDP does not yet target a measured production HUD control, and physical Android multi-touch remains NOT TESTED.
- **AUDIT-009 — First-entry visual acceptance: FAIL; remediation in PR #657.**
  - Reviewed the real WebGL captures from [Mshin Playable Web run 44997719591](https://github.com/pasoooir/Mshin/actions/runs/44997719591): `desktop-pacific-entry.png`, `desktop-pacific-medium.png`, `desktop-pacific-near.png`, and `desktop-pacific-overview.png`.
  - Confirmed defects: the first-step coach initially used a 430×300 logical-pixel panel at 1280×720; its pointing-hand emoji rendered as a missing-glyph box; the initial `Connected City` toast fired because the 50-road target exactly matched the 50 free starter tiles; the persistent GameBootstrap status line overlapped the bottom action dock; and the guest login indicator's `●` text glyph rendered as a red square over the Settings button.
  - PR #657 reduces the compact coach to 380×230, shortens the city-name instruction, hides the pointer during that self-explanatory first step, draws the later pointer from vector primitives (no font glyph), raises the road achievement threshold to 75 tiles, suppresses status feedback while the coach panel is visible, moves later status feedback above the bottom action dock with responsive wrapping, and replaces the guest login glyph with a procedural red dot.
  - PR #657 final WebGL captures from run 45000792101 confirm the desktop first-entry fixes: no false startup toast, no duplicate status/dock overlap, the guest badge is a clean circle, and the first-step pointer is hidden. A/I are now PARTIAL, not PASS: compact/mobile screenshots and physical Android acceptance are still required.

## Area-level evidence ledger (2026-11-22)

This ledger is deliberately conservative. A category marked PARTIAL means some sub-items have automated evidence; it does not mean the entire category passes. The individual checkboxes above remain open until their own reproduction evidence is attached.

| Area | Current status | Evidence-backed coverage | Still required |
|---|---|---|---|
| A. First impression and orientation | PARTIAL | PR #657 final WebGL captures at 1280×720 show the smaller city coach, no startup achievement toast, no duplicate status line, and a clean procedural guest badge. Evidence: [Web run 45000792101](https://github.com/pasoooir/Mshin/actions/runs/45000792101), including entry/medium/near/overview captures. | Review compact-landscape/tablet captures and physical Android entry, orientation and safe-area behavior before marking A PASS. |
| B. Camera and navigation | PARTIAL | GameplaySmoke camera math; Chromium dispatches pinch-out, two-finger pan/twist, 2→1 transition and one-finger pan; PR #654 cancellation/focus reset tests. | Assert actual camera transform and anchor stability, edge/zoom limits, HUD isolation; physical Android gesture feel and resume. |
| C. Selection and object feedback | PARTIAL | GameplaySmoke resolves visible facade/roof taps to the building volume and checks construction feedback. | Frontmost overlap, empty plot, roads/trees/services, duplicate panel/action behavior and visible feedback review. |
| D. Build, move, upgrade, demolish | PARTIAL | GameplaySmoke exercises move/cancel restoration and construction/building state paths; PR #654 prevents cancelled release from committing a move. | Full touch-driven build/rotate/move/cancel/bulldoze flows, resource preservation, confirmations and construction UX on mobile. |
| E. Roads and city connectivity | PARTIAL | Automated road gateway/connectivity and system-level road placement coverage exist. | Finger-drawn continuity, cancellation semantics for already placed segments, invalid-connection messaging and water/terrain edge taps. |
| F. Panels, HUD and touch targets | PARTIAL | PR #656 live-scene mixed-touch integration; existing GameplaySmoke catalog/scroll/category tests; PR #658 browser canvas matrix for seven standard viewports and portrait-to-landscape return. | Inspect latest responsive captures for HUD/card clipping; test resize while submenu is open, safe areas, production HUD hit-testing, 48px targets and physical Android. |
| G. Economy, production and progression | PARTIAL | Gameplay/economy integration and production queue/system tests run in CI. | Mobile UI walkthrough for costs, shortages, queue/collect, overflow, upgrades, locks and offline return. |
| H. Services, population and city feedback | PARTIAL | Service/connectivity and citizen feedback logic have automated gameplay coverage. | Inspect coverage overlays, explainable happiness changes, warning-to-object navigation and vehicle visual obstruction in live play. |
| I. Visual comfort and readability | PARTIAL | PR #657 entry/medium/near/overview captures confirm the startup toast/status overlap and missing-glyph badge are corrected at 1280×720. Evidence: PR #657 Web run 45000792101 visual-acceptance artifact. | Review all responsive captures and inspect near/far road, terrain, water, marker density, color-independent states and motion comfort; physical-device sign-off remains open. |
| J. Performance, resilience and accessibility | PARTIAL | Godot headless, Web/mobile Chromium launch, APK export, focus-loss cleanup and automated economy/gameplay tests. | Real target-device FPS/draw-call benchmark, memory/input latency, save/load interruption, reduced-motion/audio-off and physical Android resume. |

### Explicit release blockers / open acceptance
- **P1/P2 candidate:** complete mixed HUD/world two-finger interaction test (AUDIT-001); current predicate coverage is not an end-to-end pass.
- **P2:** physical Android interruption/resume, landscape/safe-area and touch-target acceptance.
- **P2:** real mobile performance benchmark with uploaded evidence; tooling alone is not a performance result.
- **P2:** visual first-entry and near/far review with screenshots; CI geometry smoke is not visual UX acceptance.

## Acceptance policy
- A checklist item is PASS only with reproducible evidence.
- All P0/P1 findings must be fixed and regression-tested before a UX milestone is accepted.
- P2 findings must have an explicit fix/defer decision; P3 items may be scheduled.
- Chromium emulation is not physical Android acceptance. Record both separately.

## Responsive viewport and orientation audit

- **AUDIT-010 — Responsive viewport and orientation matrix: CI PASS on the pre-PR-657 baseline; rerun required on merged UI.**
  - PR #658 uses CDP device-metric overrides to resize one live WebGL game session through 854x480, 960x540, 1024x768, 1280x800, 1366x768, 1536x864 and 1920x1080; it verifies the game iframe fills each viewport, the Godot canvas remains visible, and stores a real screenshot for visual review.
  - The touch-enabled mobile browser is also emulated through 844x390 -> 390x844 -> 844x390 using CDP screen-orientation metrics. The canvas must remain visible through portrait fallback and landscape return.
  - This proves browser canvas continuity and supplies screenshots; it does not automatically prove HUD text/card clipping, orientation lock on a phone, or physical safe-area behavior. Human visual review and Android device acceptance remain required.
