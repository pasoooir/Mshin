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

## Current audit notes (2026-11-22)
- **AUDIT-001 — Mixed HUD/world multi-touch isolation: NOT TESTED, candidate P1/P2.**
  - Code observation: HUD routes native UI touch through `_route_native_ui_touch`; CityInput independently starts a pointer when it receives a screen touch.
  - Risk scenario to verify: first finger begins on an interactive HUD control and second finger begins on the city (or the reverse). Confirm whether camera/build tools receive a partial gesture while the UI owns the other pointer.
  - Do not label as a confirmed defect until a runtime reproduction test exists.
  - Required regression: touch down on HUD, touch down/drag/release on city, release HUD; assert no camera movement, placement, selection, or accidental activation. Repeat with order reversed and cancellation.

## Acceptance policy
- A checklist item is PASS only with reproducible evidence.
- All P0/P1 findings must be fixed and regression-tested before a UX milestone is accepted.
- P2 findings must have an explicit fix/defer decision; P3 items may be scheduled.
- Chromium emulation is not physical Android acceptance. Record both separately.
