# Cocos Creator 3.8.6 runtime setup

## Current source layout

- Runtime components: `assets/scripts/MshinGame.ts`, `VehicleController.ts`, `WorldRenderer.ts`, and `ProgressStore.ts`.
- Shared stage catalogue and portable simulation: `src/stage-catalog.ts` and `src/cocos-core.ts`.
- Cocos preload data: `assets/resources/vector-art.json` (Creator imports this as a `JsonAsset` under the resource key `vector-art`).
- Browser build: the independent Canvas 2D runtime in `src/web-game.js`; it is not a Cocos export.

## Editor bootstrap

The repository currently contains an empty `assets/scenes/` directory placeholder and **does not yet contain a serialized Cocos `.scene` asset**. Therefore the Cocos runtime scripts are source-integrated and syntax-validated, but opening the repository in Creator will not yet launch a playable scene automatically.

To bootstrap in Cocos Creator 3.8.6:

1. Open the repository root as a Creator project and wait for asset import to finish.
2. Create a 2D scene named `Main` under `assets/scenes/`.
3. Add a root node named `MshinGame` and attach the `MshinGame` component from `assets/scripts/MshinGame.ts`.
4. Save the scene and set it as the project's startup scene in Project Settings.
5. Confirm `assets/resources/vector-art.json` is imported as a JsonAsset with the resource path `vector-art`.
6. Preview the scene, confirm the vector-art loading screen exits to the home menu, and test keyboard and touch controls.
7. Build the Web Desktop/Mobile target, then create an Android build if the Android toolchain is installed.

## Important release boundary

The GitHub Actions Cocos check runs TypeScript transpilation and duplicate-class-member validation. It is not equivalent to Creator's engine-aware type checking, scene import, Editor Preview, Web build, or Android build. Those steps must be run in Creator 3.8.6 before describing the Cocos runtime as editor-verified or release-ready.


## Cocos camera and vehicle scale

The Cocos Creator runtime now counter-rotates the HUD while rotating the camera against the player vehicle heading, keeping the car oriented toward the top of the race view through bends without rotating the interface. The Cocos vehicle visual node is scaled 1.25×; simulation position and collision geometry remain unchanged. This is source-level and CI syntax validation only until a serialized scene is opened in Creator 3.8.6.
