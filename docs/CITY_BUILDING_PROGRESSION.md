# Native city building progression

## Component

`assets/scripts/CityBuildingProgression.ts` provides a reusable construction timer and upgrade lifecycle for placed building roots in Cocos Creator 3.8.6.

- Attach `MshinCityBuildingProgression` to each placed building root.
- Set `constructionDuration` according to the building's value or category.
- While constructing, `state` is `constructing`, `constructionProgress` moves from 0 to 1, and `secondsRemaining` counts down.
- On completion, `state` changes to `complete`.
- Call `upgrade()` only when complete; it increments `level` and starts a new construction cycle using `upgradeDuration`.
- `maxLevel` prevents upgrades beyond the configured cap.

## API

- `beginConstruction(durationSeconds?)`: starts or restarts a construction cycle.
- `upgrade(): boolean`: starts the next upgrade cycle or returns false when unavailable.
- Read `state`, `level`, `constructionProgress`, and `secondsRemaining` to drive UI.

## Integration boundary

This component is a progression primitive; it does not yet create a placement ghost, perform touch raycasts, deduct currency, persist state, or render a construction scaffold/progress UI. Those systems require city placement, economy and save integration. The repository still has no serialized Cocos scene, so Editor and Android runtime verification remain outstanding.

## Acceptance checks

1. New building begins in constructing state and counts down using frame delta time.
2. Progress is bounded from 0 to 1 and reaches 1 on completion.
3. Upgrade is rejected during construction and after reaching max level.
4. A valid upgrade increments level and starts its own construction timer.
5. Zero-duration construction completes immediately.
