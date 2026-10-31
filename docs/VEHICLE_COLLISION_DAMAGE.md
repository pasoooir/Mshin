# Vehicle collision and damage model

The browser runtime uses a deterministic, engine-independent 2D impulse solver in `src/collision-physics.js`. Vehicles carry world-space velocity, approximate mass and a collision radius. A contact normal is computed from the two centers; only closing relative velocity generates an impulse. Restitution and bounded tangential friction dissipate energy, while inverse-mass positional correction prevents persistent overlap. Static barriers use a one-body normal reflection.

Impact energy is estimated from reduced mass and normal closing speed. Each vehicle has cumulative 0–100 damage with independent front/rear/left/right zones and engine wear. Five presentation bands (0–4) drive performance loss, smoke, localized body overlays and critical disablement. Small impacts are capped and do not instantly destroy a car. Damage persists for the current race only.

The browser integrates the player's longitudinal/lateral velocity with the impulse result and updates rival speed and lateral drift. A short contact cooldown prevents repeated impulses while bodies overlap. Trackside hazard contacts use the static-barrier solver. Vehicle-to-vehicle contacts are resolved between the player and AI rivals and between AI rivals. The Cocos Creator adapter shares typed impulse/damage primitives and applies static-barrier physics and cumulative performance loss. The current Cocos scene adapter has no AI rival simulation or damage-sprite overlay yet; those remain browser-first functionality pending a verified Creator scene build.

Validation: `npm test` builds the shared TypeScript core and runs tests covering rear, head-on, left/right side, oblique, static barrier, overlap correction, closing-direction guard, mass response, cumulative/localized damage and critical state. Browser smoke imports the solver in the browser and checks damage telemetry; source-contract tests verify the localized overlay integration. Actual Android-device and Cocos Creator Editor testing still require those environments.


## Rigid-body upgrade (feature branch)

The new `src/rigid-body-physics.js` module models each vehicle as one oriented rectangular rigid body. The body footprint represents the integrated chassis, bumpers and wheel envelope; those parts are not independent colliders. Four-axis OBB separating-axis tests determine contact and penetration for arbitrary headings. Contact impulses include the angular lever arm, rotational inertia, restitution and Coulomb-limited tangential friction; positional correction is inverse-mass weighted. The returned impact energy is based on reduced mass and normal closing speed after restitution.

The browser player-versus-rival path now uses the rigid-body solver and projects corrected world positions back onto the race-track coordinates. It also carries yaw-rate between contacts. A swept transform query samples the path from the previous to current frame, with the sample count based on relative travel and the smallest body dimension, to detect fast crossings. AI-to-AI contacts use the same oriented-body impulse solver. The solver is deterministic and has no per-frame dependencies on a physics engine.

The solver tests cover low-speed contact, heavy/light response, oblique and side impacts, chain transfer, separating overlap, damage localization and swept high-speed contact. These are deterministic unit-level validations; they are not a substitute for visual inspection in a real browser or Cocos Creator Editor. The current integration still maps the browser race to a track-relative longitudinal/lateral model, so the solver's angular response is represented as yaw-rate and lateral/longitudinal velocity rather than a fully free 2D world simulation. The Cocos scene adapter has not yet been switched to this new solver.


## Cocos Creator rigid-body integration

The shared TypeScript core now also exposes `RigidBody2D`, `createRigidBody2D`, `resolveRigidBody2D` and `resolveRigidVehiclePair`. The Cocos `VehicleController` runs movement in fixed substeps capped at 1/120 second and resolves oriented chassis-versus-static-hazard contacts using the same SAT/impulse model. Vehicle mass, footprint, inertia, angular velocity, restitution and friction are part of the body state. Impact energy is fed into the existing cumulative, localized damage model. A reusable vehicle-pair hook applies the same impulse to both participants and attributes opposite contact normals for their damage zones.

The Cocos project currently has a player vehicle and static course hazards, but no active AI traffic actors in its scene adapter. The pair-contact API is ready for any Cocos AI/traffic actor to call; it is not claimed as an active Cocos AI-vs-AI simulation until such actors are added. The browser runtime already executes player/AI and AI/AI rigid-body contacts. Cocos Editor/device visual validation remains separate from TypeScript compilation and automated core tests.
