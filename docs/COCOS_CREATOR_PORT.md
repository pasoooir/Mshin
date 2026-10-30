# Cocos Creator 3.8.6 project foundation

## Project source added

This branch now contains a Cocos Creator 3.8.6 project configuration (package.json, settings/v2/packages/project.json, tsconfig.json) and native Cocos TypeScript components under assets/scripts/.

- MshinGame.ts: runtime-created home, world and stage selection, race HUD, pause/results flow and touch/keyboard controls.
- VehicleController.ts: arcade vehicle motion, route-edge correction, obstacle collision and lap/timer state.
- WorldRenderer.ts: Cocos Graphics rendering for procedural routes and theme decoration.
- ProgressStore.ts: offline local progress and best-time persistence.
- src/stage-catalog.ts: 10 themed worlds, 50 stage definitions and procedural route generation.

Scene content is created at runtime with Cocos Node, Graphics, Label, UITransform and Camera components. No hand-authored scene serialization is included.

## Editor integration gate

Cocos Creator 3.8.6 is not installed in the development container. The repository currently has no verified .scene asset and no generated Cocos library import state. Open the project in Cocos Creator 3.8.6, create a 2D scene under assets/scenes, add an empty root node, attach the MshinGame component and save it as the startup scene in Build Settings. This Editor-created scene is required before preview or build.

Do not treat portable Node tests as an Editor build or runtime test. Cocos script compilation, scene import, touch event behavior, rendering and camera configuration still require validation in the actual Editor.

## Verification boundary

The Node suite compiles and tests engine-independent TypeScript stage catalog and driving core. It does not compile files importing cc because the Cocos Editor provides the matching engine declarations and project compiler configuration.

## Targets

- Web: Cocos Creator 3.8.6 Editor -> Project -> Build -> Web Mobile.
- Android: requires Cocos Creator 3.8.6, Android SDK/NDK and Java toolchain configured in the Editor.
- No APK/AAB or Cocos Web build is claimed until those tools produce real outputs.
- Cloudflare R2 is not used.
