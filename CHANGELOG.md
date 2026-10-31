# Changelog

## 0.7.0 — 2026-10-31

### Visible gameplay
- Rival traffic now uses continuous AI steering, safe following gaps, curve-aware pace and smooth lane changes.
- Vehicle collisions accumulate panel-local soot and progressively produce dark smoke and flames.
- Critical damage triggers a single explosion effect with camera and audio feedback.
- AI wrecks burn, fade and leave active traffic, collision checks, minimap and ranking.
- Player vehicle destruction ends the race with a visible explanation.

### Runtime and offline
- Added all browser runtime physics/AI/destruction modules to the service-worker app shell.
- Bumped the PWA cache to `mshin-arcade-v18`.
- Updated visible splash/home release labels and metadata to 0.7.0.

### Verification boundaries
- Browser desktop/mobile Playwright smoke and automated test suite are required release gates.
- Cocos Creator Editor builds and physical-device QA are not represented as completed by browser CI.
