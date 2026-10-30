# Mshin — Game Design

## Approved art direction
Colorful cartoon graphics, top-down camera, rounded silhouettes, bright palettes, readable track edges, playful props and soft shadows. Landscape-first touch gameplay.

## Core loop
Choose a world and unlocked stage; race; avoid hazards; finish against a target; earn up to three stars; save progress and unlock the next stage.

## Controls
Left thumb virtual joystick for steering; right-side accelerator and brake; pause/resume/restart. Support touch and mouse for browser testing.

## Driving
Arcade handling with acceleration, braking, speed-sensitive steering, lateral grip, surface friction and collision response. Validate feel on real mobile hardware.

## Stage scope
50 stages across 10 worlds, five stages per world. Every stage has an individual preview, metadata record, track identifier and world-specific surface. A preview is not a playable level: each stage still needs actual track geometry, collision, obstacles and finish logic.

## Worlds
1. Green Valley — #8bd46b, #d9f2a5, #4d9b58.
2. Desert Storm — #f4c16e, #ffe3a1, #bd7845.
3. Frozen World — #a8e7f5, #e8fbff, #6c9fc4.
4. Tropical Island — #48d5b2, #ffe18a, #268e83.
5. Neon City — #25265c, #ff55c8, #43e9ff.
6. Industrial Zone — #87939d, #f5a64c, #49545f.
7. Mountain Rush — #80c5a0, #d8e4c4, #6585a5.
8. Ancient World — #e6bd73, #f4dfa6, #a86c48.
9. Space Racing — #222653, #9d7bff, #58d7e8.
10. Ultimate Championship — #f06f68, #f7d66d, #4b74b9.

## CDN strategy
Original SVG previews live in this repository and are delivered by GitHub Pages and jsDelivr. Example: https://cdn.jsdelivr.net/gh/pasoooir/Mshin@main/cdn/previews/stage-01.svg . Pin production URLs to a release tag or commit SHA. Gameplay assets must be bundled locally; CDN is optional and never required to launch or play. Cloudflare R2 is not used. Third-party assets require a recorded source and license.

## Technology
Cocos Creator 3.8.x and TypeScript. Planned systems: GameManager, StageManager, CarController, TouchInput, TrackCollision, RaceManager, SaveManager and ThemeLoader.

## Quality gates
Validate 50 unique stages and all previews; test input, movement, collisions, pause, finish, progression and persistence; verify landscape safe areas, offline gameplay and browser/mobile builds. Do not claim deployment or APK output until actually built and verified.
