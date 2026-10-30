# Cocos Creator 3.8.6 gameplay-core port

## What this change establishes
The deterministic gameplay layer now has a TypeScript implementation in src/cocos-core.ts. It has no Cocos imports, so CI can compile and test the actual TypeScript logic without pretending the Cocos Editor is installed.

Included contracts:
- CarState and DriveInput for a Cocos component adapter.
- Joystick displacement normalization and safe zero-radius handling.
- Capped-delta arcade acceleration, braking, steering and off-road grip.
- Track-ring collision correction.
- Race timer, start/finish crossing and configurable lap completion.

## Required Editor integration (not yet verified)
In Cocos Creator 3.8.6, create a project and scene in the Editor, then add adapters under assets/scripts/:

1. CarController: own a CarState, read the input provider and call stepCar from update(dt); map world coordinates to the chosen track coordinate system.
2. VirtualJoystick: use touch start/move/end events, convert UI displacement with normalizeJoystick, and release active touch identifiers on cancellation/pause.
3. PedalInput: expose held-state booleans for accelerator and brake.
4. RaceManager: call updateRace, render lap/time state and persist completed-stage progress using platform storage.
5. StageLoader: load JSON metadata and select the matching world theme, track and surface material.

Do not hand-author serialized scene or prefab files. They must be created and opened by a compatible Cocos Creator Editor and smoke-tested.

## Build and test status
- npm run build:core compiles the engine-independent TypeScript core.
- npm test compiles the core and runs Node tests against emitted JavaScript.
- GitHub Actions verifies this portable core.
- This does NOT prove Cocos Editor scene serialization, rendering, native Android builds, touch behavior on device, or Web builds. Those require Cocos Creator 3.8.6 Editor/build tooling and runtime checks.

## Next implementation gate
Install/open the project with Cocos Creator 3.8.6, create the actual scene and component adapters, then validate browser and Android builds from the Editor. Until those checks pass, keep the browser Canvas prototype labeled as a prototype and do not mark the Cocos stage complete.
