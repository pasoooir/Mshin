# Native city building progression

## Runtime adapter

`assets/scripts/CityBuildingProgression.ts` is the Cocos Creator 3.8.6 component adapter. Attach `MshinCityBuildingProgression` to a placed building root. Serialized component properties configure initial construction duration, maximum level and upgrade duration.

## Engine-independent lifecycle

The deterministic state machine lives in `src/city/core/building-progression.ts` and is included in the portable TypeScript build. It exposes:

- `createCityBuildingProgression(config)`: initializes level 1 and starts construction; zero duration completes immediately.
- `advanceCityBuildingProgression(state, deltaSeconds)`: advances using frame delta time and safely ignores negative/non-finite deltas.
- `cityBuildingProgress(state)`: returns progress clamped to 0..1.
- `startCityBuildingUpgrade(state)`: returns a new state for a valid upgrade, or `null` when construction is active or max level is reached.

The Cocos adapter delegates state transitions to this module. It does not duplicate timer or level rules.

## Visible construction lifecycle (browser city)

- Newly placed homes, shops, factories and service buildings enter a 45-second simulation construction phase. Their final building model is not rendered during this phase and they do not contribute residents, jobs, service capacity or economic output until completion.
- The Three.js city renderer displays a fenced construction plot, three animated workers with hand tools, and a live countdown badge above the site. The 2D fallback displays the same lifecycle with animated worker silhouettes and a countdown.
- When the timer reaches zero, the construction representation is removed and the finished, enlarged building model is rendered. Construction state is validated and persisted in the city save.
- Parks remain immediately available as landscaping; roads are immediate infrastructure.

## Native Cocos integration boundary

The separate Cocos `CityBuildingProgression` component remains a lifecycle primitive. Native prefab-based worker animation and serialized Cocos scene integration are not claimed complete. Cocos Creator Editor import/build and Android device verification remain external acceptance gates.

## Automated acceptance

`tests/city-building-progression.test.mjs` covers construction timing, bounded progress, invalid frame deltas, upgrade eligibility, max level, zero-duration flows and defensive configuration normalization. The standard portable TypeScript build and full Node suite exercise the state machine without requiring Cocos Creator.
