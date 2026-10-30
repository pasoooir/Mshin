# Playable vertical slice — Green Valley / Stage 01

## Current deliverable
A browser-playable top-down arcade racing proof of concept is available at the repository root. It uses Canvas 2D for the first interaction prototype while the Cocos Creator 3.8.6 project integration is prepared as a separate implementation step. Do not describe this browser prototype as a completed Cocos build.

## Controls
- Touch: left virtual joystick, right GO and BRAKE buttons.
- Desktop: arrows or WASD; Space brakes; Escape pauses.
- Race: complete three laps; the finish line is at the east side of the oval track.

## Gameplay systems implemented
- Delta-time based arcade acceleration, braking and steering.
- Speed-sensitive steering and reduced grip off-road.
- Track-boundary correction and speed penalty.
- Hay-bale obstacle collision with temporary hit cooldown.
- Lap crossing detection, timer, speed readout, pause and restart.
- Responsive canvas sizing and capped device pixel ratio.
- All scenery is procedurally drawn locally; no network/CDN is needed during play.

## Validation
Run `npm run check` with Node.js 20+. Unit tests cover acceleration, braking, steering, track detection, boundary correction and finish-line wrap.

## Known limitations
- This is a first playable browser slice, not the final Cocos Creator scene or Android build.
- Stage 01 only; remaining stage records are content metadata and preview art, not yet playable.
- Collision uses a simplified oval track and circular obstacle bounds.
- Art is procedural prototype art and will be replaced/augmented by polished sprite assets.
