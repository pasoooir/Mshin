# Mshin — 2D Top-Down Arcade Racing

A colorful cartoon racing game planned with Cocos Creator 3.8.x and TypeScript.

- Top-down camera and landscape-first mobile gameplay.
- Virtual joystick, accelerator and brake.
- 50 stages across 10 visually distinct worlds.
- Offline-first gameplay; CDN is for previews and optional content only.
- Android and Web targets from one codebase.
- Cloudflare R2 is intentionally not used.

## Stage preview CDN
50 original SVG stage previews are stored in `cdn/previews/`.

Example: `https://cdn.jsdelivr.net/gh/pasoooir/Mshin@main/cdn/previews/stage-01.svg`

GitHub Pages alternative: `https://pasoooir.github.io/Mshin/cdn/previews/stage-01.svg`

Metadata: `data/stages.json`, `data/worlds.json`. Design brief: `docs/GAME_DESIGN.md`.

## Play the prototype
Open `index.html` in a modern browser or use the GitHub Pages URL after Pages is configured. The first playable slice is Green Valley / Stage 01. Touch controls and keyboard controls are supported. See `docs/PLAYABLE_VERTICAL_SLICE.md`.

## Validate
Run `npm run check` with Node.js 20+.

## Cocos Creator
Open the repository in Cocos Creator 3.8.6 or compatible 3.8.x. The playable vertical slice (car movement, touch controls, collision and race loop) is the next milestone.

## Asset rights
The stage preview illustrations are original project SVG artwork. Record source and license for all third-party assets before adding them.

## GitHub write access
The README was successfully updated through the GitHub Contents API on 2026-10-30.
