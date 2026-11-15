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

## Research documentation

- [SCBI Item & Recipe Reference](reference/SCBI_ITEM_RECIPE_REFERENCE.md) — standalone, source-traceable index of 16 raw materials and all 73 current `ProductionManager.gd` recipe definitions across 14 store families, with direct ingredients, base times, unlock gates, provenance, and unresolved conflicts.
- The catalogue is a documentation snapshot of current Mshin data; community recipe tables are secondary sources, not official EA confirmation. No gameplay data was changed in this documentation-only branch.

## Complete dependency-system specification

- [Complete Dependency & Prerequisite System](reference/COMPLETE_DEPENDENCY_SYSTEM_SPEC.md) — binding rules for item recipes, factory sources, unlock gates, building construction BOMs, residential stages, utilities, roads, services, workforce, regions, trade, inventory allocation, transparency and regression gates.
- This specification separates verified current behaviour from future requirements. The baseline inspection recorded missing universal BOM and operational gates; subsequent implementation evidence is tracked below, while official EA numeric recipe provenance and physical-device acceptance remain separate open gates.
- The implementation sequence starts with catalog integrity and a unified dependency planner; no recipe or building cost is changed by this documentation-only change.

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
## Merged implementation PR #477 — 2026-11-14

[PR #477](https://github.com/pasoooir/Mshin/pull/477) is an implementation slice, not a closure of all six remaining gates. The merged branch adds:

- Runtime recipe graph validation: supplier building identity is checked against `BuildManager.building_types`; recipe duration and input quantities must be positive; all raw/crafted input IDs must resolve; every node participating in a dependency cycle is blocked from production.
- Live queue-aware ETA inputs: production components register in a shared runtime group; store estimates read active/queued work; raw-material estimates inspect parallel factory slots and use the earliest available matching slot.
- Independent regional warehouses: region snapshots now include `StorageManager` state; switching regions saves/restores separate inventory; save schema advances to version 5, with legacy top-level inventory retained for the active region when no region-level inventory exists.
- GameplaySmoke coverage for cycle/malformed recipe rejection, live store/factory queue ETA and regional warehouse isolation across switches.

**Acceptance status:** PR #477 was merged to `main` as merge commit `5aa4d7d06ec6cc0de3ea30fc000b8374a7e2bf91`. The final PR metadata reports 17 commits and seven changed files. No physical Android device test is claimed.

**Still open:** full source/provenance adjudication of recipe numeric values against official EA data; a precise critical-path ETA for live automatic chains (the execution scheduler is real, but displayed ETA remains an estimate); refund/rollback of paid BOMs when canceling in-progress construction or upgrades; complete regional production chains beyond the implemented warehouse transfer; physical Android acceptance.


## Follow-up audit — 2026-11-14

- [PR #480](https://github.com/pasoooir/Mshin/pull/480) fixes a real version-5 save/load precedence defect: `load_game()` previously restored the active region warehouse and then overwrote it with the legacy top-level inventory. The loader now prefers the active region snapshot and uses the top-level inventory only when migrating a save without regional storage.
- GameplaySmoke now covers both version-5 regional inventory precedence and legacy top-level inventory migration.
- PR #480 merged to `main` as `fed82e2699638e95c6cdbe189e53c6771aee60ad`.
- CI on PR head `b10e75f414806d2b0c14a51c95a1ed9676d8f3c4`: Godot City BuildIt Validation run `43637146435` passed, including headless startup, end-to-end GameplaySmoke, Android Debug APK export and APK signature/package verification. Mshin Playable Web run `43637146481` passed, including browser launch in desktop and touch-enabled mobile landscape Chromium and website artifact upload.
- Android APK export is automated build evidence only. No physical Android device installation, visual comparison or touch test is claimed.

- [PR #482](https://github.com/pasoooir/Mshin/pull/482) merged the recursive ETA scheduler as `b79f843d64842feac9f6ae5bfc0be6e237853c02`.
- GameplaySmoke now verifies shared-store serialization (Bread Roll ETA 11,700 seconds), reuse of a shared Cream dependency (Ice Cream Sandwich ETA 12,540 seconds), and retains the Nails/Backpack baseline plus live queue/factory-slot checks.
- CI on PR head `f460a532372f8a2bb1f5c441ca650cbfa7368805`: Godot City BuildIt Validation run `43637770031` passed, including the complete GameplaySmoke suite and Android Debug APK export/signature verification. Mshin Playable Web run `43637768630` passed, including desktop and touch-enabled mobile-landscape Chromium launch and web artifact upload.

**Remaining acceptance gates (not closed by PR #477 or #480):**
- [x] Deterministic recursive display ETA across shared store lanes, shared intermediate outputs, live queues and parallel factory slots; disconnected suppliers are excluded. This remains a planning estimate, not a guaranteed live-chain critical-path countdown.
- [x] Automatic production execution is implemented from the commercial production panel. Missing raw and intermediate inputs are recursively scheduled in compatible live factories/stores; completed outputs are collected automatically; each real store order atomically consumes/reserves its full input set at start. Root and dependency jobs persist in existing production slots/save data. Multiple roots can run concurrently with per-chain accounting and shared-storage atomicity. GameplaySmoke covers parallel Metal factory jobs, nested Nails/Hammer/Chair chains, unresolved supplier rejection, concurrent roots sharing raw stock and slot release. Suppliers must already exist and be operational; the scheduler does not auto-build missing facilities.
- [x] Construction and non-residential upgrade BOMs are data-driven for every building type and all five supported upgrade stages. Explicit Mshin profiles cover distinctive infrastructure tiers; other types use deterministic per-building footprint/build-time/unlock profiles; exact material snapshots and provenance are exposed by a catalog-wide audit. Placement and upgrade paths consume the required materials. These are Mshin balance values, not EA recipe claims. Refund/rollback on cancellation of an in-progress build/upgrade remains a separate open item.
- [x] Unified operational gates now include Gateway road access, power, water, sewage, waste and workforce for relevant producers. Sewage/waste capacity is contributed only by completed, connected and staffed treatment providers; household capacity is allocated before production demand. Fire/Police/Health coverage counts only operational providers with required access, utilities and workforce. Workforce derives from occupied residents; individual citizen commute simulation remains out of scope.
- [x] Player-initiated inter-region warehouse transfers are implemented through the Regional Trade tab. Transfers require Global Trade HQ, unlocked source/target regions, trade-eligible items, sufficient source stock and target capacity; both sides are updated atomically and saved. Full region-specific production recipes and resource loops remain open.

- [PR #484](https://github.com/pasoooir/Mshin/pull/484) merged non-residential power/water operating gates as `309298d52ac24bc99dd7ab83640435131e6014ae`.
- GameplaySmoke verifies commercial and industrial utility demand, allocation, operation while served, shutdown after power loss and reactivation after power restoration. The pre-existing road-only factory outage tests remain isolated from the new utility requirement.
- CI on PR head `c38f7e38dfc0eb111a57f875ff5bcebd4cc2e543`: Godot City BuildIt Validation run `43638352489` passed, including the full GameplaySmoke suite and Android Debug APK export/signature verification. Mshin Playable Web run `43638352498` passed, including desktop/mobile-landscape Chromium and web artifact upload.

- [PR #486](https://github.com/pasoooir/Mshin/pull/486) merged workforce allocation and operating gates as `e3e41321d2f8ee1dd8742ed457d14da49ebdcdea`.
- Workforce is allocated only after household population synchronization. Treatment/waste providers receive first-phase staffing before their capacity is counted; production and emergency facilities receive remaining workers only after sewage/waste coverage is allocated. GameplaySmoke verifies staffed-provider capacity, zero-worker shutdown, recovery, and emergency coverage shutdown/recovery. The Services summary/HUD tooltip displays available, demanded and employed workers.
- [PR #496](https://github.com/pasoooir/Mshin/pull/496) merged automatic recursive production execution as `4b1ee730c52db2dac04c4ded0174f71af4fa6d57`. Factory outputs and intermediate store products are auto-collected; complete recipe inputs are atomically removed at actual order start. Root/dependency state uses the existing saved production slots.
- [PR #499](https://github.com/pasoooir/Mshin/pull/499) merged concurrent automatic chains and the explicit AUTO CHAIN action as `576356546a7b2b5eec4cfb7280e8ec5270612b99`. Multiple roots can progress concurrently without double-spending shared inventory; the manual START queue remains available.
- [PR #497](https://github.com/pasoooir/Mshin/pull/497) merged per-building BOM profiles, all-stage non-residential upgrade bills and the full catalog audit as `09c52b9f389c89ae13b75f274190d91cde87a6fb`.
- [PR #498](https://github.com/pasoooir/Mshin/pull/498) merged staffed sewage/waste capacity and operational emergency coverage as `db6b068a430f2d7553a2bf4dcd1441b08374916a`.
- CI evidence: PR #496 runs `43687874854` (Godot GameplaySmoke + Android Debug APK export/signature verification) and `43687874851` (web GameplaySmoke, Chromium desktop/mobile-landscape and web artifact) passed. PR #497 runs `43688038225` and `43688038303` passed. PR #498 runs `43687714953` and `43687714963` passed. PR #499 runs `43688631658` and `43688631691` passed. These verify CI APK export, not physical Android-device acceptance.
- CI on PR head `5927e1f8efe7406a2e73c0a0973da0ecf2a3325b`: Godot City BuildIt Validation run `43638809300` passed, including full GameplaySmoke and Android Debug APK export/signature verification. Mshin Playable Web run `43638809284` passed, including desktop/mobile-landscape Chromium and web artifact upload.

- [PR #488](https://github.com/pasoooir/Mshin/pull/488) merged player-initiated inter-region warehouse trade as `4e32ab6091457911190144a47f9cf430fe436f13`.
- GameplaySmoke verifies active-to-inactive and inactive-to-active transfers, both inventories updating, and insufficient-stock rejection without mutating the active warehouse. The Regional Trade tab provides source, target, item and amount selectors with stock/capacity feedback; transfers are persisted through SaveManager.
- CI on PR head `ee6b4ef45f201893052d15763a442d51f5dc5d3c`: Godot City BuildIt Validation run `43639351487` passed, including GameplaySmoke and Android Debug APK export/signature verification. Mshin Playable Web run `43639351492` passed, including desktop/mobile-landscape Chromium and web artifact upload.
- Physical Android install, screenshot comparison and touch acceptance remain open.


## Currency-driven city progression — PR in progress

- [ ] **Simoleons material market:** unlocked raw and crafted items can be purchased in quantities 1/5 into City Storage. Balance debit and inventory credit are guarded by capacity and level gates. Price = community reference maximum selling value × 1.5; this is explicitly Mshin balance, not EA Global Trade buy price.
- [ ] **SimCash time acceleration:** active factory/store production slots, building construction and building upgrades expose a quote based on remaining time; spending completes the timer but leaves produced items in Ready state for normal collection.
- [ ] **Commercial queue expansion:** SimCash buys additional supported commercial queue slots using community reference costs; existing slot count is saved through production component serialization.
- [ ] **Currency panel integration:** Simoleons popup includes market goods; SimCash popup includes active timer offers, commercial slot expansion and the existing sandbox pack store.
- [ ] **Smoke coverage:** market purchases, storage-full rejection, level-lock rejection, production speed-up, collection exactly once and popup section visibility are covered by `currency_economy_smoke.gd`.
- [ ] **Open by design:** direct SimCash purchase of land/storage Special Items is not implemented here; these remain tied to the item-based expansion/storage gates until their complete inventory workflows are in place. Real multiplayer Global Trade HQ and real payment-provider validation are also separate work.
- Source separation: EA's beginner guide confirms currency roles, factory/store production and building plans. Fandom Building Materials supplies community recipe/value/unlock data. All new Mshin buy prices and per-minute speed-up pricing are labelled Mshin-proposed in `CURRENCY_DRIVEN_CITY_PROGRESSION.md`.


- [PR #503](https://github.com/pasoooir/Mshin/pull/503) merged to `main` as `4c6b5be6a922b2a3a483f5af7f52db7c9690d5c5`.
- Currency progression adds the Simoleons material market, SimCash time acceleration for active production/construction/upgrades, and SimCash commercial queue-slot expansion. New Mshin pricing rules are explicitly distinguished from EA-confirmed behavior and community reference data in `docs/CURRENCY_DRIVEN_CITY_PROGRESSION.md`.
- Godot Validation run [43700782340](https://github.com/pasoooir/Mshin/actions/runs/43700782340) passed: static validation, icon validation, import/parse, headless startup, GameplaySmoke, VisualPresentationSmoke, CurrencyEconomySmoke and Android Debug APK export/signature verification.
- Mshin Playable Web run [43700782353](https://github.com/pasoooir/Mshin/actions/runs/43700782353) passed: Web export, desktop and mobile-landscape Chromium launch and website artifact upload.
- No physical Android install/touch acceptance or final economy balancing is claimed. Direct SimCash bypass of land/storage Special Item gates, live multiplayer trade and real payment-provider validation remain separate work.


- [PR #504](https://github.com/pasoooir/Mshin/pull/504) merged as `9e697df0778d7640fff44f3d9e64b516f56b05f9`: commercial queue-slot purchases now call `EconomyManager.spend_sim_cash()`, ensuring the HUD receives `sim_cash_changed`; smoke test covers debit, slot growth and save-array restore. Godot Validation and Android APK export passed in run `43701024651`; Web/Chromium passed in run `43701024643`.
- [PR #505](https://github.com/pasoooir/Mshin/pull/505) merged as `84329766109cab4760317d37c2f645337f0b616e`: the Simoleons panel no longer bypasses the reference market progression with a direct item catalog. It reuses rotating `TradeManager.market_offers` and `buy_global_offer()`, and displays the market only when Global Trade HQ is operational. Godot Validation and Android APK export passed in run `43701281318`; Web/Chromium desktop and mobile-landscape plus artifact upload passed in run `43701281319`.
- This keeps the user choice meaningful: produce the item chain and wait, or buy a currently offered item through the unlocked trade system. It does not grant unrestricted early-game purchasing.


- [PR #506](https://github.com/pasoooir/Mshin/pull/506) merged to `main` as `8735b7b6f8491c0f385548ad2846d03ccaf29e09`: SimCash can buy Dozer Wheel, Dozer Blade and Dozer Exhaust for the Fandom reference price of 24 SimCash each. Items enter City Storage and the normal land expansion transaction still enforces Mayor Level 10, adjacency and the full three-item BOM. Godot Validation run [43701669455](https://github.com/pasoooir/Mshin/actions/runs/43701669455) and Web/Chromium run [43701669452](https://github.com/pasoooir/Mshin/actions/runs/43701669452) passed.
- Remaining currency progression gap: SimCash purchase of Storage Bars/Locks/Cameras and the full escalating three-item City Storage capacity upgrade table are not implemented. Do not replace that item gate with direct SimCash capacity bypass.


## Production capacity simulator and macro cashflow integration — PR #509 Godot Validation passed

Implementation branch: `feat/production-capacity-cashflow-model`

- [x] Deterministic production replay engine added in `scripts/economy/ProductionCapacitySimulator.gd`; CI has not yet validated the parser/runtime.
- [x] Factory slots execute independently using explicit facility slot counts; no hidden factory waiting queue is invented.
- [x] Commercial stores serialize one active order per building while retaining other slots as slot-order queue entries.
- [x] Manual store queue admission atomically consumes the full recipe input set, matching `ProductionComponent.start_craft`.
- [x] Ready output remains in its production slot until explicit collection; full warehouse rejects collection without discarding the item.
- [x] Trade Depot listing removes stock at listing time; up to four active listings are modeled; cash is credited only by explicit collection after the real 120-second wait.
- [x] Collected production sales are appended as `production_sale` events and flow into the macro `production_sales` source bucket.
- [x] Live-city snapshot captures ordinary and AUTO CHAIN production slots, remaining timers, exact FIFO cost batches, current warehouse and Depot listings; deterministic replay of the captured dependency graph is being validated in the follow-up PR.
- [x] Smoke tests added for parallel factory slots, two queued store jobs, atomic material consumption, full-warehouse retention and production-to-cashflow integration.
- [x] Godot Validation / Android APK export / Web Chromium CI on the final PR SHA.
- [ ] Automatic-chain dependency replay, shared intermediate reservations and multiple concurrent roots (follow-up PR implementation is awaiting CI).
- [x] Scenario-level FIFO inventory cost batches, COGS and gross-margin accounting with explicit acquisition costs; unknown costs remain unknown and catalog values are not substituted. Verified by MacroEconomySmoke.
- [ ] Persisted live StorageManager cost-batch ledger, production cost propagation through live manual/AUTO CHAIN jobs, Depot realized-margin ledger and save/load integration.
- [ ] Coupling delivery-order item consumption to production inventory and explicit market-demand modeling.

**Godot evidence:** [Godot City BuildIt Validation run 43708045317 — success](https://github.com/pasoooir/Mshin/actions/runs/43708045317). It passed Import/Parse, headless startup, GameplaySmoke (including the live-city snapshot), VisualPresentationSmoke, CurrencyEconomySmoke, MacroEconomySmoke and Android Debug APK export/signature validation. Web/Chromium desktop and mobile launch plus artifact upload passed: [run 43708045318](https://github.com/pasoooir/Mshin/actions/runs/43708045318). The later commits only updated README/docs, not runtime code. PR #509 is merged to main as `dd7967dc10857b317386353d7366b42cb972569e`. Web/Chromium acceptance passed. The independent CI run on the squash merge commit remains a separate unchecked gate.


- First PR CI exposed two real compile-time integration defects: static functions could not resolve autoload singleton identifiers, and a static type check pulled `ProductionComponent.gd` into standalone script compilation. Both were corrected by resolving autoload nodes through `SceneTree.root` and using the production group membership contract instead of a static class reference.
- Final Godot Validation on PR SHA `bb24eb193804e38e8095b63409931095846572ed` passed: [run 43708045317](https://github.com/pasoooir/Mshin/actions/runs/43708045317).


- [x] PR #509 merged to `main`: `dd7967dc10857b317386353d7366b42cb972569e`.
- [x] PR Godot Validation: [43708045317](https://github.com/pasoooir/Mshin/actions/runs/43708045317).
- [x] PR Web/Chromium desktop and mobile: [43708045318](https://github.com/pasoooir/Mshin/actions/runs/43708045318).
- [ ] Independent workflow evidence on the squash merge commit has not yet been verified.


## FIFO cost basis and gross margin — PR #510

- [x] Initial inventory cost batches are accepted only from explicit `initial_unit_costs`; missing cost data stays unknown.
- [x] FIFO material cost is carried from store inputs into crafted output at queue admission.
- [x] Depot listing reservation carries the sold batch's cost basis; gross revenue, known COGS and gross margin are reported at explicit sale collection.
- [x] Unknown-cost sales expose null gross margin and increment `unknown_cost_sale_quantity`; no catalog reference value is used as acquisition cost.
- [x] COGS is kept out of the Simoleons cash balance to prevent double counting.
- [x] Regression case: revenue 80, COGS 30, gross margin 50; unknown-cost sale correctly marks gross margin incomplete.
- [x] Godot Validation + MacroEconomySmoke + Android Debug APK: [run 43709273987](https://github.com/pasoooir/Mshin/actions/runs/43709273987).
- [x] Web/Chromium desktop and mobile: [run 43709273970](https://github.com/pasoooir/Mshin/actions/runs/43709273970).
- [ ] Live inventory cost-batch persistence in StorageManager and save/load.
- [ ] Live manual/automatic production input-cost propagation and Trade Depot realized gross-margin ledger.
- [ ] Scenario simulator replay of complete AUTO CHAIN graphs, shared dependencies and critical-path timing.


## Live FIFO cost ledger — PR #511 merged; PR CI passed

- [x] StorageManager stores per-item FIFO cost batches and keeps legacy inventory without a known acquisition cost marked unknown.
- [x] Manual ProductionComponent store jobs capture FIFO input cost at queue admission and transfer it to collected output.
- [x] Factory output carries known zero direct Simoleon input cost under current mechanics; no labor, capital depreciation or opportunity cost is inferred.
- [x] AUTO CHAIN store dependencies capture and transfer cost through recursive raw/store dependencies.
- [x] Global Trade HQ purchases add the actual paid Simoleon amount as inventory acquisition cost.
- [x] Trade Depot listing reservation stores FIFO cost; cancellation returns the same cost; sale collection records revenue, COGS and gross margin in EconomyManager's transaction ledger.
- [x] MacroEconomySimulator live snapshot summarizes realized sales from the transaction ledger and marks incomplete history when the 300-entry ledger has rolled over.
- [x] GameplaySmoke covers live production cost transfer, nested AUTO CHAIN, Depot cancel/collect, HQ purchase cost, Storage save/load and live ledger reporting.
- [x] Godot Validation, Android Debug APK export and Web/Chromium on the final PR SHA: [Godot + APK 43710111735](https://github.com/pasoooir/Mshin/actions/runs/43710111735), [Web 43710111759](https://github.com/pasoooir/Mshin/actions/runs/43710111759).

**Acceptance boundary:** no unknown legacy cost is replaced with catalog value. No COGS is deducted from Simoleons a second time. Historical realized margin is only complete if both all sold batches have known costs and the transaction ledger has not truncated earlier events. PR #511 is merged to main as `72d54bd28741320a5376fc58fbd0c89e52d5326c`.

- [ ] Independent CI on merge commit `72d54bd28741320a5376fc58fbd0c89e52d5326c` and the README update is not yet verified.


## Delivery-order COGS and macro cashflow — PR #512 merged; PR CI passed

- [x] Live TradeManager rejects invalid/understocked orders atomically and records actual consumed FIFO COGS plus reward/gross margin.
- [x] Live macro snapshot includes `delivery_order_completed` alongside `trade_sale_collected` when summarizing realized cash revenue and COGS.
- [x] Production scenario action `delivery_order` consumes stock and its FIFO cost batches, then emits a cash event with the explicit reward.
- [x] MacroEconomySimulator books the explicit delivery-order reward under `delivery_orders` source bucket.
- [x] Unknown acquisition cost stays unknown and prevents complete gross-margin claims.
- [x] GameplaySmoke validates insufficient-stock rejection, live order cost metadata, ledger aggregation and completion state.
- [x] MacroEconomySmoke validates inventory consumption, reward cashflow, FIFO COGS and unknown-cost handling.
- [x] Godot Validation and Android Debug APK: [43710739261](https://github.com/pasoooir/Mshin/actions/runs/43710739261); Web/Chromium: [43710739262](https://github.com/pasoooir/Mshin/actions/runs/43710739262).

**Open:** Cargo Ship crate consumption and Golden Key reward are not cash sales; they need separate non-cash contribution accounting before inclusion in wider economic profitability. PR #512 is merged as `2ed1cc42c8eb9e5a1eb1d6e85dc09600fd7ae09b`.

- [ ] Independent CI on the PR #512 merge commit and README follow-up is not yet verified.


## Cargo Ship non-cash contribution ledger — PR #513 merged; PR CI passed

- [x] Each delivered crate records FIFO COGS and its item quantity in the EconomyManager transaction ledger.
- [ ] Completed ship manifest records the Golden Key as a non-cash reward with no invented Simoleon value.
- [x] Live macro summary exposes Cargo Ship crates, known COGS, unknown-cost quantity, Golden Keys earned and cost-history completeness separately from cash gross margin.
- [x] GameplaySmoke validates three costed crates, manifest completion and separation of non-cash reward from Simoleon gross revenue.
- [x] Godot Validation and Android Debug APK: [43711118973](https://github.com/pasoooir/Mshin/actions/runs/43711118973); Web/Chromium: [43711118954](https://github.com/pasoooir/Mshin/actions/runs/43711118954).

PR #513 merged to main as `7bdfd777d22ff0f2eb415d713718801117ed395b`. Golden Key has no assigned Simoleon value; non-cash COGS is deliberately kept outside cash gross margin.
- [ ] Independent CI on the PR #513 merge commit and README follow-up is not yet verified.


## AUTO CHAIN scenario replay and exact live FIFO snapshot — PR #514 merged

- [x] Explicit `auto_chain` scenario action reserves a root store slot only when the recursive supplier graph is resolvable.
- [x] Raw material dependencies are scheduled across independent factory slots and automatically collected when warehouse capacity permits.
- [x] Crafted intermediate dependencies are recursively queued in the matching stores; automatic jobs are excluded from the manual store queue starter.
- [x] Each store serializes its active production timer while retaining queued automatic dependencies.
- [x] The complete target BOM is consumed atomically only after all dependencies are in City Storage.
- [x] Active live AUTO CHAIN slots are preserved in the city snapshot with chain identity and remaining timer rather than rejecting capture.
- [x] Exact live FIFO batches (`quantity`, `total_cost`, `known`) are copied into scenario replay; proportional batch consumption mirrors StorageManager.
- [x] MacroEconomySmoke covers nested Hammer → Nails → Metal dependency replay, parallel raw-material production, exact input use, output collection and Depot-to-Simoleon cashflow.
- [x] MacroEconomySmoke covers exact per-batch FIFO cost inputs.
- [x] GameplaySmoke covers live snapshot preservation of AUTO CHAIN root slots and FIFO batch state.
- [x] Godot Validation and Android Debug APK: [43712308645](https://github.com/pasoooir/Mshin/actions/runs/43712308645); Web/Chromium: [43712308649](https://github.com/pasoooir/Mshin/actions/runs/43712308649).

**Merged:** PR #514, commit `96d4dd806945929be8e57201aa4a11c1b2172517`.

**Open:** cross-root shared intermediate reservation/merging and explicit critical-path analytics are not implemented. This replay follows the current per-chain live scheduler and can schedule duplicate intermediate work across independent roots.

- [x] Independent main CI after PR #514 on commit `a6d1dcc867bb96972a546f82aa97b59a5ae3c536`: Godot + Android APK [43712594820](https://github.com/pasoooir/Mshin/actions/runs/43712594820), Web/Chromium [43712594809](https://github.com/pasoooir/Mshin/actions/runs/43712594809), Pages deploy [43712595064](https://github.com/pasoooir/Mshin/actions/runs/43712595064).


---

## SimCity-style production interaction — implementation branch

- [x] Six independent production slots configured for every standard factory tier; GameplaySmoke tier assertions updated.
- [x] Product controls now provide drag data scoped to the selected building and item.
- [x] Queue slot controls validate same-building source, recipe ownership/material identity, unlock state and empty target slot before accepting a drop.
- [x] Drop submits the order through existing factory start / store craft / automatic dependency-chain APIs; existing collection and warehouse rules remain authoritative.
- [ ] Radial/floating product layout around the selected building.
- [ ] Six compact queue tiles and touch-layout acceptance across mobile landscape profiles.
- [x] Product-specific 3D billboard thumbnail for ready factory/store goods; multiple ready outputs show a count label.
- [x] World-space markers cover ready production, full-storage blocking and actionable residential upgrade readiness; auto-completed construction/non-residential upgrades do not show false claim badges.
- [ ] Additional service/city-system markers where a genuine player action is pending.
- [x] GameplaySmoke covers production start/ready/Collect, full-storage blocking without loss, and Save/Load restoration.
- [ ] Automated pointer/touch drag gesture and production continuity after closing the panel.
- [ ] CI and physical Android touch acceptance for this branch.

No recipe, production duration, expansion price, or item provenance was added or inferred by this UI change.

 
---

## SimCity-style production interaction — compact radial UI phase

- [x] Full-screen white modal replaced by compact bottom dock.
- [x] Product catalogue moved to a floating orbit around the selected building's projected screen position.
- [x] Compact queue cards preserve per-slot timer, ready and Collect states.
- [x] Touch fallback: select product then tap an empty queue slot; native drag forwarding remains enabled.
- [ ] Physical Android visual spacing review; CI confirms mobile landscape canvas launch, not a screenshot review of the production panel.
- [x] World-space markers cover ready production, storage-full blocking and actionable residential upgrade readiness; no false badge is shown for auto-completed construction/non-residential upgrades.
- [ ] Extend markers to any other activity only after confirming a real pending player action exists.
- [x] Godot Validation + GameplaySmoke + storage-full Collect + save/load + visual presentation + Android Debug APK: [run 43722788626](https://github.com/pasoooir/Mshin/actions/runs/43722788626).
- [x] Web export + gameplay integration + desktop/mobile landscape Chromium + Pages artifact: [run 43722788624](https://github.com/pasoooir/Mshin/actions/runs/43722788624).

- [x] Unify actionable world-space markers: ready production shows the actual product thumbnail; blocked collection shows a warning marker; residential upgrades show an upgrade marker only while an upgrade can genuinely start.
- [x] Avoid false completion/collect notifications for construction and non-residential upgrades because those state transitions complete automatically in the current game model.


## 2026-11-15 — Building-surface production interaction (PR #518)

- [x] Add a visible drop target projected over the selected factory/store building.
- [x] Route building-surface drops to the first free slot through the existing production-drop validation and acceptance functions; recipe ownership, level unlocks, storage reservation and automatic-chain rules remain authoritative.
- [x] Add touch fallback: select a catalog item, then tap the building target.
- [x] Broaden the floating product orbit around the selected building while keeping the production queue dock below.
- [x] Extend GameplaySmoke.gd to assert the building target, validate the surface-drop path and start a factory order through it.
- [ ] CI run for PR #518 — no passing run has been observed yet.
- [ ] Physical Android landscape screenshot and touch acceptance.
- [ ] Visual confirmation that the projected target aligns with the actual building on supported mobile aspect ratios.

**Acceptance note:** code and regression assertions are committed on feat/building-surface-production-drop; PR #518 is open. The implementation is not yet declared complete because CI and physical Android verification remain pending.


## 2026-11-15 — Production modal and true building drop surface

- [x] Full-screen black backdrop at exactly 50% opacity.
- [x] Backdrop and overlay consume pointer input so the city cannot be selected while ordering.
- [x] CityInput and CameraController explicitly guard against city/camera gestures while the production modal is active.
- [x] Replace the floating decorative drop button with a polygon hit area derived from the selected building's rotated world-space footprint projected into screen coordinates.
- [x] Keep the existing recipe, level, queue-capacity, stock-reservation and automatic-chain validation path for accepted drops.
- [x] Preserve touch fallback: select a honeycomb item, then tap the selected building's actual footprint.
- [x] Support Escape/Backspace dismissal and the existing close button.
- [x] Godot 4.3 import/parse, headless startup, GameplaySmoke, visual geometry, currency/sandbox and macro-economy validation passed.
- [x] Android Debug APK export and package signature/identity verification passed.
- [ ] Android landscape drag/drop and visual alignment acceptance on a physical device.

**Acceptance status:** implementation committed to feat/production-modal-building-drop; pending CI and real-device validation. No completion claim is made yet.

- [ ] Web Chromium mobile/desktop smoke and Pages deployment — workflow still running at last check.


## 2026-11-15 — Production Studio visual redesign

- [x] Honeycomb catalogue now uses two stable side clusters rather than the previous radial scatter; more products extend the same two-column lattice.
- [x] Responsive hex tile and icon sizing for landscape viewports.
- [x] Top-centered factory/store nameplate is separated from the queue dock.
- [x] Selected item details are constrained to a compact capsule; the oversized pale/white bottom sheet is removed.
- [x] Bottom queue dock uses a dark translucent surface and high-contrast slots; existing production timers, collect actions, store queue capacity and drag/drop handlers remain in place.
- [x] 50% dimmed city modal, modal input lock and building-footprint drop target are retained.
- [x] GameplaySmoke covers compact panel height, nameplate placement, compact details and first honeycomb cluster.
- [x] Godot 4.3 import/parse, headless startup, GameplaySmoke, visual geometry, currency/sandbox and macro-economy checks passed in CI run `43738099078`.
- [x] Android Debug APK exported and signature/package identity verified in CI; artifact produced (available until 2026-11-29).
- [x] Web export and desktop/mobile Chromium launch smoke passed in CI run `43738099073`.
- [ ] Production GitHub Pages deployment is not verified by this PR run: its deploy job was skipped.
- [ ] Validate 16:9 and Android landscape sizes; physically test touch select-then-tap and drag/drop.
- [ ] Capture and review final Android gameplay screenshot before accepting visual completion.

**PR #520 merged into `main` at `5fbac0e3aaef34d4fb4aa96ce802c8d51a8afdd5`. CI acceptance is green, but visual acceptance is not yet claimed. Figma and Canva boards are design references; only the Godot build and device screenshots can prove the in-game result.


## 2026-11-15 — Direct product drag into production queue

- [x] Pointer-captured touch drag continues globally after the finger leaves a hexagon tile.
- [x] Floating product ghost follows the touch point and queue slots highlight only when empty and unlocked.
- [x] Release over an empty queue slot immediately submits the factory batch or store craft/automatic supply-chain order.
- [x] Invalid, occupied and locked slots reject the drop without creating an order.
- [x] Tap-only selection opens item details and no longer exposes a START or AUTO CHAIN action.
- [x] Product clusters are centered around the selected building; larger tiles/icons improve touch precision and legibility.
- [x] GameplaySmoke updated for direct touch drag/release and queue-based factory/store order acceptance.
- [x] Godot 4.3 static validation, import/parse, headless startup, GameplaySmoke, visual geometry, currency/sandbox and macro-economy checks passed in run `43741503047`.
- [x] Android Debug APK exported; signature and package identity verified; artifact upload succeeded in run `43741503047`.
- [x] Web export, desktop/mobile Chromium smoke, Pages configuration and website artifact upload passed in run `43741621986`; PR #521 merged to `main` at `fc603ee42468b60cfacb4144fed6b274e218b3d2`; post-merge production Pages deployment remains unverified.
- [ ] Validate Android landscape touch drag/drop and review actual in-game screenshot.
- [ ] Confirm production Pages deployment after merge.

**No CI or device acceptance is claimed until those checks pass.**


## 2026-11-15 — Production touch gesture hardening

- [x] Product drag is bound to the originating touch index; unrelated fingers cannot move or release the active drag.
- [x] Full-screen product-orbit containers ignore pointer events so they do not intercept taps intended for queue slots beneath them.
- [x] Tap-only selection persists until a subsequent tap on an unlocked queue slot or the selected building, making the non-drag fallback operational.
- [x] Production labels consistently identify the empty queue slot as the primary drop target and the building footprint as an additional target.
- [x] GameplaySmoke now exercises multi-touch isolation and tap-to-queue fallback.
- [x] Godot 4.3 static validation, import/parse, headless startup, GameplaySmoke, visual geometry, currency/sandbox and macro-economy checks passed in run `43742618056`.
- [x] Android Debug APK exported; signature/package identity verified and artifact uploaded in run `43742618056` (artifact expires 2026-11-29).
- [x] Web export and desktop/mobile Chromium checks passed in PR runs `43742723982` and `43743663912`; PR-event deploy jobs were skipped as designed. Post-merge push deployment remains to be verified.
- [ ] Physical Android landscape drag/drop acceptance and final screenshot review.

**Do not mark this hardening complete until the new CI run passes.**


## 2026-11-15 — Mobile shoreline rendering optimization

- [x] Replace 38 standalone shoreline pebble MeshInstance3D nodes/materials with one low-poly MultiMeshInstance3D batch.
- [x] Preserve per-stone transform and color variation, full shoreline distribution and the original pebble radius palette.
- [x] Disable shadow casting on tiny shoreline stones to remove unnecessary shadow work.
- [x] Add visual smoke assertions for the 38-instance batch, color support, shadow policy, distribution and variation.
- [x] Godot import/parse, VisualPresentationSmoke, GameplaySmoke, Web/Chromium and Android APK CI passed in runs `43743663936` and `43743663912`.
- [ ] Measure actual draw calls/frame times on Android before claiming measured gains.

**Expected structural improvement:** 38 shoreline render nodes/material instances become one MultiMeshInstance3D and one shared material. This is a draw-submission/node-count reduction by construction; actual FPS impact remains unmeasured until device profiling.


## 2026-11-15 — Shoreline draw-submission optimization (PR #523)

- [x] Replace 38 standalone shoreline pebble MeshInstance3D nodes/materials with one MultiMeshInstance3D and one shared material.
- [x] Preserve pebble positions, varied scale/yaw and the three-color palette with per-instance transforms/colors.
- [x] Disable shadow casting for small shoreline stones.
- [x] VisualPresentationSmoke verifies the 38-instance batch, per-instance color support, shadow policy, coast distribution and color variation.
- [x] Godot 4.3 import/parse, startup, GameplaySmoke, VisualPresentationSmoke, visual geometry, economy and progression checks passed (run `43743663936`).
- [x] Android Debug APK export/signature/package identity/artifact upload passed (run `43743663936`).
- [x] Web export, GameplaySmoke, desktop/mobile Chromium launch, Pages configuration and artifact upload passed (run `43743663912`).
- [x] PR #523 merged to `main` at `d997c695f9826039e9418998ae67d8d157880d63`.
- [ ] Confirm actual post-merge Pages deployment; PR-triggered deployment was skipped by workflow design.
- [ ] Capture on-device frame-time/draw-call report and compare against a baseline; do not infer FPS from node count alone.
- [ ] Physical Android landscape visual/touch acceptance.

**Structural expectation:** 38 render nodes/material instances are reduced to one batched render node and one shared material. Measured performance gain remains unverified until device profiling.


## 2026-11-15 — Single directional shadow source

- [x] Keep the main scene key DirectionalLight3D as the only shadow-map owner.
- [x] Keep the WorldPresentation warm secondary sun as a non-shadowing fill light, removing duplicate directional shadow work and conflicting shadow direction.
- [x] Add VisualPresentationSmoke coverage for the secondary fill light's shadow policy and retained light energy.
- [ ] Godot import/parse, VisualPresentationSmoke, GameplaySmoke, Web/Chromium and Android APK CI.
- [ ] Android hardware screenshot/lighting review and frame-time profiling.

**Expected structural improvement:** one directional shadow source instead of two; no numeric FPS claim until on-device measurement.

- [x] Preserve the original soft-shadow settings on the main scene key light and update static validation to assert the single-shadow-source architecture.
- [x] After correcting the stale static-validator expectation and test indentation, Godot 4.3 import/parse, GameplaySmoke, VisualPresentationSmoke, static validation, Android APK export/signature and Web/Chromium CI all passed in runs `43744225839` and `43744225717`.


## 2026-11-15 — Single directional shadow source (PR #524)

- [x] Main scene key DirectionalLight3D is the only directional shadow-map owner.
- [x] WorldPresentation warm secondary sun remains a non-shadowing fill light.
- [x] Preserve soft shadow opacity, blur, bias, normal bias and shadow distance on the main key light.
- [x] Static validator now checks the main key-light contract and the non-shadowing secondary fill light.
- [x] VisualPresentationSmoke verifies the secondary fill light policy and retained energy.
- [x] Godot 4.3 static validation, import/parse, startup, GameplaySmoke, VisualPresentationSmoke, visual geometry and economy checks passed (run `43744225839`).
- [x] Android Debug APK export, signature/package identity and artifact upload passed (run `43744225839`).
- [x] Web export, GameplaySmoke, desktop/mobile Chromium, Pages configuration and artifact upload passed (run `43744225717`).
- [x] PR #524 merged to `main` at `58ca5449dd038b8d2ca39c76b00393ce2a2a8ebd`.
- [ ] Verify post-merge push-triggered Pages deployment.
- [ ] Physical Android lighting review and draw-call/frame-time measurement.

**No numeric FPS gain is claimed until measured on device.**


## On-device performance diagnostics — per-frame render metrics — 2026-11-15

- [x] Sample draw calls, rendered objects, rendered primitives, video memory and node count throughout the full device benchmark instead of reading only the final frame.
- [x] Report average, p95, maximum and last sampled values for each render metric; preserve legacy last-frame keys for older report consumers.
- [x] Record active graphics quality preset alongside device, viewport and frame-time metadata.
- [x] Extend the in-game benchmark completion message with average/p95 draw-call counts.
- [x] Add GameplaySmoke coverage for numeric metric aggregation, nearest-rank p95, maximum/last sample and empty input handling.
- [x] Godot static validation, import/parse, GameplaySmoke, Web/Chromium and Android APK CI passed in runs `43745050332` and `43745050339`.
- [ ] Run the benchmark on physical Android hardware and capture a real report; CI cannot substitute for device measurements.

**Measurement rule:** this change improves report sampling and transparency; it does not claim a performance gain by itself.

- [x] PR #525 merged to `main` at `b8c0ccbf04af6fb71d5670a14c0baf20d6f39a74`.
- [ ] Run the 30-second benchmark on a physical Android device and review the generated `user://performance_benchmark_latest.json` report; no measured FPS gain is claimed by this diagnostics change.

## Production drag-to-building and strict ingredient availability — 2026-11-15

- [x] Touch drag release now hit-tests the selected building's projected footprint polygon and submits the order to that building; it is no longer limited to queue-slot hit areas.
- [x] Native drag-and-drop and touch drag use the same building identity, product compatibility, recipe unlock and free-slot validation.
- [x] Store products with missing ingredients cannot be dragged or accepted; automatic dependency-chain start is not invoked by a manual drop.
- [x] Product hexes remain tappable for explanation while showing a red shortage state and exact missing ingredient quantities in their tooltip/detail panel.
- [x] A rejected under-stocked order leaves the queue slot and inventory unchanged; GameplaySmoke regression coverage added for Nails requiring 2 Metal.
- [x] Godot static validation, import/parse, GameplaySmoke, Web/Chromium desktop+mobile launch and Android Debug APK export passed after the direct-drop fix: validation run `43747094170` (all jobs success; APK artifact uploaded) and Web run `43747094158` (build/Chromium success; Pages artifact built, deploy skipped for pull_request event).
- [x] Regression tests exercise touch release on the projected building-footprint polygon, exact missing ingredient name/quantity, blocked drag/acceptance, unchanged inventory/queue, and successful production after stock is added.
- [x] Root cause fixed: the touch handler searched inside `ProductionPanel`, while the projected `ProductionBuildingDropTarget` is a sibling under `ProductionOverlay`; it now resolves the target from the correct overlay and converts viewport coordinates through the full canvas transform.
- [x] PR #526 merged at `45338f417033d4ad5222a2e0af4637121440147e`; PR #527 merged at `1934b564b31b1717b5fdb8a9c670b12840914468`.
- [x] Post-merge GitHub Pages push/deploy succeeded: run `43747315546` for main commit `40ee792c940b73f609b54ffb770c07cbbc8e791c` (build + deploy success).
- [ ] Physical Android touch test: drag a raw factory material onto the factory surface and drag a store product onto its store surface.

**Acceptance rule:** a store order starts only when all declared recipe inputs are already present in City Storage. Automatic supply-chain production remains an explicit separate workflow, not an implicit side effect of dragging.


## Tap-to-produce 3D building orbit — 2026-11-15

This interaction replaces drag/drop as the primary production action. Earlier drag/drop notes above describe the previous interaction and are superseded for the live catalog by this section.

- [x] Tapping a completed building focuses the camera on its world position and smoothly zooms from the current view to the production inspection distance.
- [x] Factory materials and store products receive individual six-sided 3D hexagonal platforms in world space, with a white raised face and metallic rim, arranged around the selected building.
- [x] Transparent touch targets are projected over the 3D platforms every frame, so their positions track the camera while it eases into focus.
- [x] A single tap on an unlocked factory material or stocked store product immediately accepts it into the first available production slot; no drag gesture or second queue-slot tap is required.
- [x] The existing ProductionComponent starts real Unix-timestamp countdowns; the queue dock immediately shows the timer/progress and keeps existing completion/Collect behavior.
- [x] Tapping a store product with missing ingredients opens the existing detail capsule and reports the exact missing City Storage items; no inventory is consumed and no order is queued.
- [x] Added GameplaySmoke coverage for smooth camera zoom, real 3D six-sided white hex meshes, immediate factory taps, immediate sequential store taps, and the missing-input rejection path.
- [x] Godot 4.3 import/parse, GameplaySmoke, Android Debug APK export/signature, Web export and desktop/mobile Chromium passed: validation run `43750094145`; Web run `43750094150`.
- [x] Post-merge GitHub Pages build/deploy passed on main commit `c6409688df5c57fc0a0420cc2cb191a72242785b` (run `43750279948`).
- [ ] Physical Android landscape review of camera zoom, 3D orbit spacing, and tap targets.

No recipe inputs, item durations, storage rules, queue capacity, or collection semantics were changed.


## Residential material orbit — 2026-11-15

- [x] Selecting a completed home focuses and smoothly zooms the camera to the house (shared building-focus behavior).
- [x] Current residential upgrade requirements are rendered as raised white six-sided 3D platforms around the selected home, with projected tap targets showing stored/required quantities.
- [x] Tapping a missing material token locates its registered supplier; when a completed supplier exists, the game opens that supplier and submits the material/product directly if its real production prerequisites and queue capacity allow it.
- [x] If no completed supplier exists, the player receives the supplier/building requirement instead of a fake order.
- [x] GameplaySmoke verifies one 3D hex and tap target per home material, then taps the missing Metal token end-to-end, confirms the real factory receives the order, and restores test queue/storage state (PR #530 merged; validation run `43751114166`, Web/Chromium run `43751114061`).
- [x] Godot 4.3 import/parse, GameplaySmoke, Android Debug APK export/signature, Web export and desktop/mobile Chromium passed: validation run `43750729685`; Web run `43750729686` (APK artifact uploaded).
- [x] GitHub Pages build/deploy succeeded for the final main documentation/code state `88af9a125d9c569af40c7697208fb42636f2b480` (run `43751322394`).
- [ ] Physical Android landscape inspection of house-material orbit placement and tap target reachability.



## Projected production touch hitbox regression — 2026-11-15 (PR #531)

- [x] Root cause isolated: projected Button children of plain Control parents had `custom_minimum_size` but no actual allocated `size`, so their GUI hit rectangles could be empty.
- [x] Allocate explicit non-zero sizes for factory material, store product, and residential material buttons.
- [x] Explicitly set these projected touch targets to `MOUSE_FILTER_STOP`.
- [x] Extend GameplaySmoke to assert real non-zero hitbox dimensions and pointer handling for all three target classes.
- [x] Godot validation + GameplaySmoke + Android Debug APK CI passed (run `43755633708`).
- [x] Web export + desktop/mobile Chromium smoke passed (run `43755633706`).
- [ ] Merge and verify post-merge Pages deployment.
- [ ] Physical Android touch validation (must not be inferred from CI).

**Acceptance rule:** direct programmatic `pressed.emit()` is not evidence of a working screen tap. The projected target must have a non-zero global hit rectangle at its camera-projected screen position, and the production queue must change only after a valid user interaction.


## Product orbit visibility and mobile sizing — 2026-11-15

- [x] Raise projected product-orbit layers above the building backdrop, production dock and shade.
- [x] Give product/material buttons opaque white card surfaces, border and shadow so their hit areas remain visually apparent over 3D buildings.
- [x] Increase factory/store card dimensions to at least 100 px wide on mobile before UI scaling; increase icon and text sizes.
- [x] Increase residential material token dimensions and icon/text sizes.
- [x] Position world-space hex platforms in a camera-facing orbit plane to avoid placing selectable products on the hidden far side of the building.
- [x] Add regression assertions for card hitbox size, z-order, opaque style and visibility.
- [ ] Godot validation + GameplaySmoke + Android Debug APK CI.
- [ ] Web export + desktop/mobile Chromium smoke.
- [ ] Merge and verify post-merge Pages deployment.
- [ ] Physical Android touch validation.

**Acceptance:** a selected building must show all available product cards above its model; each card must be clearly visible, at least 90×100 px in the actual UI, and tappable without dragging. CI signal emission alone is not sufficient proof of device touch.
