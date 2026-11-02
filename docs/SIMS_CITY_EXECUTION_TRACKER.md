# Sims City — Execution Tracker

**Repository:** `pasoooir/Mshin`  
**Baseline:** Phase-zero audit and initial design package, 2026-11-02  
**Documentation branch:** `docs/sims-city-phase-zero-audit`  
**Documentation PR:** [#135](https://github.com/pasoooir/Mshin/pull/135)  
**Rule:** only verified runtime features with passing acceptance evidence may be marked 🟢. Documents, commits, file creation and a passing workflow alone do not count as gameplay completion.

## Status legend
- ⬜ شروع‌نشده
- 🟡 در حال اجرا
- 🟢 تکمیل‌شده و تأییدشده
- 🔴 شکست‌خورده یا مسدود

## Progress policy
- Gameplay progress is calculated only from accepted gameplay Feature IDs.
- Audit/design/documentation work is tracked separately and contributes **0% gameplay completion**.
- A feature is green only after code, runtime behavior, independent and integration tests, performance review, evidence, and regression checks.
- No percentage is published until the feature inventory and weights are baselined.

## Phase 0 — Repository audit

| ID | Task | Owner | Dependencies | Priority | Status | Start | Complete | Test / evidence | Commit | PR |
|---|---|---|---|---|---|---|---|---|---|---|
| SC-AUD-001 | Inspect repository, package, source tree and engine declarations | Technical lead | None | P0 | 🟢 تکمیل‌شده و تأییدشده | 2026-11-02 | 2026-11-02 | GitHub API tree (206 entries), package.json, Cocos setup docs | 86d52be | #135 |
| SC-AUD-002 | Audit browser racing runtime and reusable vehicle systems | Technical lead | SC-AUD-001 | P0 | 🟢 تکمیل‌شده و تأییدشده | 2026-11-02 | 2026-11-02 | Source inventory and existing vertical-slice documentation | 86d52be | #135 |
| SC-AUD-003 | Verify Cocos Creator scene/build readiness | Technical lead | SC-AUD-001 | P0 | 🟢 تکمیل‌شده و تأییدشده | 2026-11-02 | 2026-11-02 | Cocos 3.8.6 declared; assets/scenes contains only .gitkeep; no Editor build evidence | 86d52be | #135 |
| SC-AUD-004 | Inspect open PRs and latest CI failure | Technical lead | SC-AUD-001 | P0 | 🟢 تکمیل‌شده و تأییدشده | 2026-11-02 | 2026-11-02 | 20 open PRs; latest browser smoke failure at tests/browser-smoke.mjs:260, 5321.6ms draw stall | 86d52be | #135 |
| SC-AUD-005 | Inventory current-session plugin/tool surfaces | Technical lead | None | P1 | 🟢 تکمیل‌شده و تأییدشده | 2026-11-02 | 2026-11-02 | Available namespaces/skills inspected; unavailable Meshy/Contour3D not assumed | 86d52be | #135 |

## Phase 1 — Product research and architecture

| ID | Task | Owner | Dependencies | Priority | Status | Start | Complete | Test / evidence | Commit | PR |
|---|---|---|---|---|---|---|---|---|---|---|
| SC-RSH-001 | Research city-builder references and public player feedback | Product/design | SC-AUD-001 | P1 | 🟡 در حال اجرا | 2026-11-02 | — | Initial qualitative synthesis and 2026 player-feedback follow-up added to GAME_DESIGN_DOCUMENT; structured comparison across all requested titles and 12 review dimensions remains | 0353e4c | #135 |
| SC-ARC-001 | Define engine-independent simulation/domain boundaries | Software architecture | SC-AUD-001 | P1 | 🟢 تکمیل‌شده و تأییدشده | 2026-11-02 | 2026-11-02 | Layer boundaries, module map, events, scheduling and Cocos adapter boundary documented | 86d52be | #135 |
| SC-ARC-002 | Define coordinate, road graph and city-save schemas | Software architecture | SC-ARC-001 | P1 | 🟡 در حال اجرا | 2026-11-02 | — | Coordinate conventions, graph topology and save envelope outlined; detailed typed schemas and migration fixtures remain | — | #135 |
| SC-ART-001 | Define cohesive city art direction and asset acceptance gates | Art direction | SC-RSH-001 | P1 | 🟢 تکمیل‌شده و تأییدشده | 2026-11-02 | 2026-11-02 | Art direction, asset families, plugin-led pipeline and runtime QA criteria documented | 86d52be | #135 |
| SC-PLG-001 | Produce first city-block/road concept through available design tools | Art/design | SC-ART-001 | P2 | 🟡 در حال اجرا | 2026-11-02 | — | Figma FigJam runtime architecture diagram created (link in technical architecture doc); OpenArt connected but balance is 0 credits, so concept generation is blocked; no final 3D assets accepted | — | — |

### Design package created (documentation only; 0% gameplay completion)
- `SIMS_CITY_GAME_DESIGN_DOCUMENT.md`
- `SIMS_CITY_FEATURE_MATRIX.md`
- `SIMS_CITY_TECHNICAL_ARCHITECTURE.md`
- `SIMS_CITY_GAMEPLAY_SYSTEMS.md`
- `SIMS_CITY_ART_DIRECTION.md`
- `SIMS_CITY_PERFORMANCE_STRATEGY.md`
- `SIMS_CITY_ASSET_PIPELINE.md`
- Research synthesis is in the Game Design Document; the first plugin-authored city-block concept remains pending.

## Phase 2 — Existing-game stabilization

| ID | Task | Owner | Dependencies | Priority | Status | Start | Complete | Test / evidence | Commit | PR |
|---|---|---|---|---|---|---|---|---|---|---|
| SC-QA-001 | Profile and fix the single-frame 5.3-second draw stall | Runtime/performance | SC-AUD-004 | P0 | 🟡 در حال اجرا | 2026-11-02 | — | First cause found: late crowd/billboard/rail meshes bypassed the upload queue. Bounded uploads exposed a second issue: pending meshes were not drawn until track-build completion, causing a two-color blank scene at 91.6% build progress. Commit 6128c2c draws pending geometry and adds a regression assertion; portable validation passed, browser smoke is running | 6128c2c | #136 |
| SC-QA-002 | Review PR #132 and its CI/diff; preserve current driving controls | Gameplay/QA | SC-QA-001 | P1 | 🟡 در حال اجرا | 2026-11-02 | — | Core validation passed on the inspected head; browser smoke previously failed at framebuffer color assertion on PR #136 and is being re-run after progressive-render fix | — | #132 / #136 |
| SC-QA-003 | Review stacked open PR dependency graph and test evidence | Technical lead | SC-AUD-004 | P1 | ⬜ شروع‌نشده | — | — | Per-PR diff, base/head, checks and review state | — | — |

## Phase 3 — Sims City vertical slice (not yet implemented)

| ID | Feature | Acceptance target | Dependencies | Priority | Status |
|---|---|---|---|---|---|
| SC-CORE-001 | Deterministic simulation clock and world state | Seeded fixed-tick simulation with pause/speed controls | SC-ARC-001 | P1 | 🟡 در حال اجرا | 2026-11-02 | — | Implementation in PR #137: immutable city state, fixed-tick clock, seeded PRNG and six Node tests; initial PR #137 portable validation passed (237 tests, 0 failures); a pause/backlog regression test was then added in commit 98b4c7b and revalidation is pending; browser smoke remains pending | 98b4c7b | #137 |
| SC-WORLD-001 | Small city map/grid and terrain | Selectable buildable parcels; persistent coordinates | SC-CORE-001 | P2 | ⬜ شروع‌نشده |
| SC-ROAD-001 | Road placement and road graph | Validated connected road segments; costs, undo-safe placement | SC-WORLD-001 | P1 | ⬜ شروع‌نشده |
| SC-BLD-001 | Building placement and occupancy | Data-driven residential/commercial/public buildings attached to road access | SC-ROAD-001 | P2 | ⬜ شروع‌نشده |
| SC-CIT-001 | Citizen/household simulation | Population, home/work assignment and daily schedule independent of rendered NPC count | SC-BLD-001 | P2 | ⬜ شروع‌نشده |
| SC-ECO-001 | Base city economy | Budget, tax revenue, upkeep, employment and deterministic tick | SC-BLD-001, SC-CIT-001 | P2 | ⬜ شروع‌نشده |
| SC-SRV-001 | One functioning municipal service | Coverage/capacity affects building/citizen state | SC-ROAD-001, SC-BLD-001 | P2 | ⬜ شروع‌نشده |
| SC-TRF-001 | City traffic graph routing | NPC cars follow legal connected road paths and respond to congestion | SC-ROAD-001 | P2 | ⬜ شروع‌نشده |
| SC-DRV-001 | Player free-drive on city roads | Existing vehicle dynamics/control operates on city road coordinates | SC-ROAD-001 | P2 | ⬜ شروع‌نشده |
| SC-MIS-001 | City-linked driving mission | Mission completion mutates city economy/service state and persists | SC-ECO-001, SC-DRV-001 | P2 | ⬜ شروع‌نشده |
| SC-SAV-001 | Versioned multi-city save/load | Round-trip save/load, validation, recovery and migration tests | SC-CORE-001 | P1 | ⬜ شروع‌نشده |
| SC-UI-001 | City dashboard and build controls | All visible controls invoke real simulation actions and expose reasons on rejection | SC-ROAD-001, SC-BLD-001 | P2 | ⬜ شروع‌نشده |

## Release gates
- No main-branch merge while required checks fail.
- No destructive migration, removal of existing race functionality, history rewrite or production release without explicit user approval.
- Do not claim Creator readiness until a real `.scene` is opened and a Web build is produced in Cocos Creator 3.8.6.
- All generated 2D/3D assets must be produced/reviewed through the relevant professional design pipeline and pass engine import, visual, scale, polygon/texture and performance checks.
- The first vertical slice must run in the browser and retain the existing standalone race mode as a regression-tested subsystem.
