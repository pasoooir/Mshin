# Production Economy & City Needs — Implementation Tracker

**Snapshot:** 2026-11-13  
**Project:** godot-city-buildit  
**Branch:** main  
**Status:** PR #438 is merged. Recipe data, economy audit, trade eligibility, offline/queue stress coverage and mobile catalog layout are implemented and CI-verified. Physical Android visual/touch acceptance remains open, so the domain is not falsely marked fully closed.

**Baseline:** PR #394 — `06c3e2bd87435ddc3dce5df0d2c73ff37bff8fa8`.  
**Previous expansion:** PR #437 — `c9ea5e7b6ed61a2b3afa2a92e33406522da528ff`.  
**Completion PR:** [#438](https://github.com/pasoooir/Mshin/pull/438) — merge commit `4e886a01b6d4f05d4d2d36235373113f3e415d93`.

**Main-branch evidence after Merge:**
- Godot City BuildIt Validation: run `43489826154` — success.
- Mshin Playable Web: run `43489826228` — success, including GameplaySmoke, Web export and Chromium desktop/mobile landscape launch.
- GitHub Pages build/deploy: run `43489825540` — success.

**Acceptance boundary:** production code, recipe integrity, economy diagnostics, long-session/offline regression tests and mobile-viewport UI behavior are automated and passing. A real Android device screenshot comparison and physical touch test remain unverified. Do not claim pixel-identical SimCity BuildIt UI until that physical check is performed.

## Six implementation slices

| Slice | Deliverable | Evidence | Status |
|---|---|---|---|
| 1 | One authoritative raw/crafted/store catalog | `scripts/autoload/ProductionManager.gd`; 73 recipe definitions plus one conflict-only catalog identity | 🟢 73/74 identities have recipe definitions; 70 currently craftable |
| 2 | Per-slot production and warehouse transfer | `scripts/production/ProductionComponent.gd`; `scripts/autoload/StorageManager.gd`; `scripts/buildings/Building.gd` | 🟢 Core + stress regression |
| 3 | Residential upgrade requirements and supplier visibility | `scripts/ui/HUD.gd`; `scripts/buildings/Building.gd`; ProductionManager upgrade requirements | 🟢 Core |
| 4 | City-wide needs and no-double-count allocation | `scripts/autoload/CityDemandManager.gd`; HUD City Needs shortcut | 🟢 Core |
| 5 | SCBI-inspired mobile production/residential panels | `scripts/ui/HUD.gd`; `scripts/ui/Icons.gd`; local crafted SVG icons | 🟡 Chromium mobile passes; physical Android comparison pending |
| 6 | Economy, construction timers, save/load and scores | `EconomyManager.gd`; `SaveManager.gd`; `BuildManager.gd`; `Building.gd` | 🟢 Code/CI regression passes; device review separate |

## Product and recipe coverage

- Raw material catalog: 16 entries total — 11 standard SCBI materials plus 5 Mshin regional materials.
- Standard commercial catalog: 74 product identities across 14 store families.
- Authoritative `crafted_items`: 73 recipe definitions.
- Currently craftable: 70 recipes.
- Recipe definitions with known inputs, base time and reference value but unknown exact Mayor Level: 3. These remain locked.
- Catalog-only conflict identity: 1 (Tapestry). It remains visible but not craftable.
- Building Supplies: 6 recipes.
- Hardware Store: 6 recipes.
- Farmer's Market: 7 recipes.
- Furniture Store: 5 recipes.
- Fast Food Restaurant: 6 recipes.
- Donut Shop: 6 recipes.
- Home Appliances: 5 recipes.
- Gardening Supplies: 6 recipes.
- Fashion Store: 5 recipes.
- Sports Shop: 5 identities (4 craftable; Football Shoes has an unverified Mayor Level gate).
- Toy Shop: 4 identities (2 craftable; Kite and Teddy Bear have unverified Mayor Level gates).
- Bureau of Restoration: 5 identities (4 craftable; Tapestry has conflicting input evidence).
- Farmer's Store: 3 recipes.
- Dessert Shop: 5 recipes.

### Source-backed product records added in PR #438

- Football Shoes: Shoes ×1 + Chemicals ×3; 35-minute base production; reference value 920. Exact item Mayor Level is unknown, so it cannot be produced or selected for generated Global Trade/Cargo Ship offers.
- Kite: Home Textiles ×2 + Planks ×2 + Paint ×2; 75-minute base time; reference value 1,000. Exact item Mayor Level remains unknown and is not guessed.
- Teddy Bear: Home Textiles ×4 + Plastic ×2; 60-minute base time; reference value 600. Exact item Mayor Level remains unknown and is not guessed.
- Tapestry: reference time 210 minutes and reference value 2,560 are recorded. Current Bureau of Restoration 2024 table reports Textiles ×4 + Paint ×2 + Glue ×2; its product page reports Textiles ×3 + Paint ×2 + Glue ×2. Both candidate ingredient sets are exposed in the detail panel; production remains disabled.
- Sources are community-reference pages, not official EA documentation. A missing Mayor Level is represented as unverified metadata, not replaced with a guessed level.

### Previous recipe expansion

PR #437 added Backpack, Tennis Racket, Sports Drink, Protein Bar, Chiseled Stone and Stained Glass. Stained Glass requires one Store Star. Recipe inputs, base times, level gates and star gates are covered by GameplaySmoke.

## Economy integrity and balancing evidence

- `get_recipe_economy_profile()` reports output reference value, summed input reference value, gross reference-value spread, production duration and spread per minute.
- This profile is explicitly a comparison of reference max-selling values. It is not net profit: it excludes time opportunity cost, taxes, trade fees, bonuses and player-specific effects.
- `get_economy_catalog_audit()` checks raw/crafted reference values and times, supplier IDs, non-empty input definitions, positive quantities, valid ingredient references, catalog-only duplication and unresolved gates.
- Negative reference-value spreads are warnings, not silently rebalanced prices. The current reference data flags Sports Drink, Protein Bar, Football Shoes, Kite and Teddy Bear. These warnings must not be interpreted as proof of negative cash profit or as a reason to override source-backed values without in-game evidence.
- Unknown item IDs return zero reference value and zero production time. They no longer receive invented fallback values.
- Trade eligibility is centralized. Generated Global Trade and Cargo Ship pools exclude products whose Mayor Level gate is unverified or whose reference value is missing.
- No source-backed price, ingredient quantity or Mayor Level was changed solely to force a positive spread.

## Production, inventory and offline invariants

1. First residential upgrade remains 1 Nail + 1 Metal.
2. Product inputs are checked as a complete set before inventory mutation.
3. A failed order never partially consumes inventory.
4. Commercial queue inputs are reserved exactly once when the order is accepted.
5. Commercial stores process one active order at a time; the next queued order starts after the previous one completes.
6. Factory slots run independently in parallel.
7. Collect adds exactly one output to City Storage.
8. A full warehouse leaves a ready output on its production slot.
9. Production and construction use persisted Unix finish timestamps.
10. Restoring a queue does not charge reserved inputs again.
11. Offline elapsed timers restore to ready and advance the next sequential commercial order without skipping a batch.
12. A recipe with unresolved source conflicts or an unverified unlock level cannot start.
13. Trade generation does not offer products whose item unlock level is unverified.

## Mobile production panel

- The production studio uses a darker city backdrop, a warm metallic frame and a high-contrast building nameplate so the selected factory/store is immediately recognizable.
- Product artwork and labels are larger; product tiles show current raw stock or the number of missing recipe materials without replacing the full selected-product detail view.
- The catalog reflows into 3 compact / 4 tablet / 6 desktop columns with vertical scrolling; recipe and ingredient details have their own vertical scroll area; the production queue remains horizontally scrollable.
- Empty queue slots display a visible plus/empty affordance. Active, queued, producing, ready-to-collect and storage-blocked states still come from the existing ProductionComponent state machine.
- Ingredient and candidate-input labels wrap within narrow detail panels. Product details continue to expose known reference time/value and disclose disputed ingredients or unknown Mayor Level gates.
- Resizing the viewport while the studio is open rebuilds the panel using the new responsive profile.
- GameplaySmoke checks responsive catalog columns, scroll behavior, building nameplate, queue affordance, product selection, start, timer, collect and storage blocking.
- Chromium CI launches the actual Web game in a touch-enabled landscape viewport. This is browser evidence, not a physical Android screenshot or touch-acceptance result.

## Source-conflict register

- Tapestry: Textiles ×3 vs ×4 conflict remains unresolved; do not choose one silently.
- Football Shoes, Kite and Teddy Bear: exact product Mayor Level gates remain unknown; recipes stay locked.
- Other source-derived values such as ingredient quantities and trade values remain community-reference. Re-check them against current in-game captures before making balance changes.
- Mshin-specific residential upgrade fallback plans are not represented as exact SimCity BuildIt randomized material rolls.

## Automated test coverage

- All existing raw-material level/time and factory-tier permissions.
- Existing 70 craftable recipes, their supplier ownership, material inputs, production times and Store Star gates.
- Football Shoes, Kite and Teddy Bear source inputs, reference values/times and explicit unknown-level lock.
- Tapestry's two candidate ingredient sets, known reference time/value and explicit conflict lock.
- Economy catalog audit has no structural errors and surfaces negative reference-value spreads.
- Unknown product IDs do not receive fabricated prices or production times.
- Global Trade and Cargo Ship eligibility excludes unverified unlock-level products.
- Three sequential commercial orders survive serialization/restoration; ingredients are not deducted twice.
- Offline completion advances the commercial queue one order at a time.
- Full storage blocks collection without losing ready output; collection succeeds after storage space is freed.
- Five factory slots run and collect independently in parallel.
- Production panel catalog remains one horizontally scrollable row and ingredient text wraps.
- Existing GameplaySmoke continues to cover construction, services, residential upgrades, save/load and general city gameplay.

## Final acceptance

- [x] PR #394 production-economy foundation merged to main.
- [x] PR #437 verified recipe expansion merged to main.
- [x] PR #438 source-backed product metadata, economy audit, trade filtering, queue stress tests and mobile panel robustness merged to main.
- [x] Godot Validation run `43489826154` passed on main merge commit `4e886a01b6d4f05d4d2d36235373113f3e415d93`.
- [x] Web/Chromium desktop and mobile launch run `43489826228` passed on the same main commit.
- [x] GitHub Pages build/deploy run `43489825540` passed on the same main commit.
- [x] 73/74 product identities have recipe definitions; 70 are currently craftable, three are safely locked by unknown Mayor Level, and one Tapestry record remains disabled due to conflicting inputs.
- [x] Long-session/offline queue, parallel factory, save/restore and full-storage collection regression tests pass in CI.
- [x] Mobile Chromium landscape launch and production catalog scroll contract pass in CI.
- [ ] Physical Android screenshot comparison against current SimCity BuildIt production/residential panels.
- [ ] Physical Android touch acceptance: horizontal catalog scroll, select product, start, collect, close, queue expansion and upgrade.
- Do not claim this domain fully closed until the two physical-device checks above are evidenced.
