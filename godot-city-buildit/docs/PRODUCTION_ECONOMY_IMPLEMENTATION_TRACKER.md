# Production Economy & City Needs — Implementation Tracker

**Snapshot:** 2026-11-13  
**Project:** godot-city-buildit  
**Branch:** main  
**Status:** Production-economy foundation from PR #394 and verified-recipe expansion PR #437 are merged. Godot validation, Web build/Chromium desktop+mobile, and GitHub Pages deployment passed on the post-merge main commit. Physical Android side-by-side visual acceptance remains open; do not claim pixel-identical SCBI UI until that review is complete.

**Baseline PR:** #394 — merge commit `06c3e2bd87435ddc3dce5df0d2c73ff37bff8fa8`.  
**Recipe expansion PR:** [#437](https://git## Six implementation slices

| Slice | Deliverable | Evidence | Status |
|---|---|---|---|
| 1 | Single authoritative product/factory/store catalog | `scripts/autoload/ProductionManager.gd`; 70 craftable recipes plus four unresolved catalog-only identities | 🟢 70/74 products; four intentionally disabled |
| 2 | Correct per-slot production and warehouse transfer | `scripts/production/ProductionComponent.gd`; `scripts/autoload/StorageManager.gd`; `scripts/buildings/Building.gd` | 🟢 Core |
| 3 | Residential upgrade plan and supplier details | `scripts/ui/HUD.gd`; `scripts/buildings/Building.gd`; ProductionManager upgrade requirements | 🟢 Core |
| 4 | City-wide needs dashboard and no-double-count allocation | `scripts/autoload/CityDemandManager.gd`; HUD City Needs shortcut | 🟢 Core |
| 5 | SCBI-inspired mobile production/residential panels | `scripts/ui/HUD.gd`; `scripts/ui/Icons.gd`; local crafted SVG icons | 🟡 Android screenshot comparison pending |
| 6 | Economy, construction timers, save/load and scores | `scripts/autoload/EconomyManager.gd`; `SaveManager.gd`; `BuildManager.gd`; `Building.gd` | 🟢 Code and CI passed; physical-device review remains separate |

## Current production catalog coverage

- Raw materials: 11; craftable commercial products: 70; unresolved catalog-only product identities: 4 (74 standard product identities across the 14 commercial store families).
- Building Supplies: 6 recipes.
- Hardware Store: 6 recipes.
- Farmer's Market: 7 recipes.
- Furniture Store: 5 recipes.
- Fast Food Restaurant: 6 recipes.
- Donut Shop: 6 recipes.
- Home Appliances: 5 recipes.
- Gardening Supplies: 6 recipes.
- Fashion Store: 5 recipes.
- Sports Shop: 4 recipes.
- Toy Shop: 2 recipes.
- Bureau of Restoration: 4 recipes.
- Country Store / Farmer's Store: 3 recipes.
- Dessert Shop: 5 recipes.
- The four unresolved products remain visible but disabled: Football Shoes (item unlock level unknown), Kite (item unlock level unknown), Teddy Bear (item unlock level and production time unresolved), and Tapestry (community references disagree on Textiles ×3 vs ×4).
- PR #437 added verified recipes for Backpack, Tennis Racket, Sports Drink, Protein Bar, Chiseled Stone and Stained Glass. Stained Glass requires the first store star; the recipe and production-time gate are tested.
- `store_catalog` now contains only unresolved product identities. Verified recipes remain in the authoritative `crafted_items` catalog and are not duplicated as unresolved placeholders.
- Traditional Restaurant and Art Supplies: Mshin-specific production panels open with an explicit empty/verification message.
- All recipe data from community-reference sources remains community-derived, not EA-confirmed. Do not silently turn disputed quantities into official balancing facts.

## Required invariants

1. First residential upgrade remains 1 Nail + 1 Metal.
2. Product inputs are checked as a complete set before any storage mutation.
3. A failed order never partially consumes inventory.
4. Collect adds exactly one output to City Storage.
5. A full warehouse leaves a ready output on its production slot.
6. Production and construction use persisted Unix finish timestamps.
7. Shared warehouse units are allocated to at most one home plan in a dashboard snapshot.
8. Per-home upgrade buttons require the full amount physically stored; in-production and ready-to-collect quantities are shown separately.
9. City Needs refreshes after inventory, production, construction, upgrade, XP, population, happiness and currency changes.
10. A recipe with unresolved source conflicts is visibly warned; an unverified recipe cannot start.

## Source-conflict register

The following community-reference inputs differ between available tables and must be checked against a current live-game capture before final balancing:

- Glue and Paint ingredient quantities.
- Cooking Utensils ingredient quantities.
- Flour Bag ingredient quantities.
- Corn seed quantity.
- Tapestry ingredient quantities: the product page and store-family tables differ on Textiles ×3 vs ×4. Tapestry remains catalog-only and cannot be produced.
- Football Shoes and Kite have unresolved item unlock levels; Teddy Bear has unresolved unlock level and production time. These remain disabled rather than receiving guessed values.

Do not convert these values into EA-confirmed facts.

## Automated test coverage added

- Raw material level and time catalogue.
- Factory-tier material permissions.
- Hardware product base times.
- Farmer's Market and Furniture Store recipe inputs/times.
- Central store catalog ownership.
- Storage multi-item atomic add/remove and rejection of negative inputs.
- City Needs aggregation and first-home Nails requirement.
- City Needs HUD shortcut and residential plan panel.
- Complete City Storage inventory display and live per-slot production queue with one-second ETA refresh.
- Local product icon catalog coverage.
- Construction finish timestamp creation.
- Fast Food catalog visibility, five enabled recipes and one disabled store-star recipe.
- All 14 SCBI commercial store types and product-family catalog counts.
- Existing gameplay smoke continues to cover production, collection, first home upgrade, save and load.

## Final acceptance

- [x] PR #394 production-economy foundation merged to main.
- [x] PR #437 verified commercial-recipe expansion merged to main.
- [x] Godot 4.3 import, startup and end-to-end GameplaySmoke passed on post-merge main (run 43486114412).
- [x] Web export and Chromium desktop/mobile launch checks passed on post-merge main (run 43486114191).
- [x] GitHub Pages build and deployment completed successfully (run 43486112974).
- [x] 70 of 74 standard commercial product identities have enabled, source-backed recipes; four unresolved identities remain visible but disabled.
- [ ] Android landscape screenshots still need side-by-side comparison with current SimCity BuildIt production and residential panels.
- [ ] Touch scroll, tap, collect, close and upgrade actions still need a final check on a physical Android device.
- Do not call the UI pixel-identical until the Android comparison is completed.
