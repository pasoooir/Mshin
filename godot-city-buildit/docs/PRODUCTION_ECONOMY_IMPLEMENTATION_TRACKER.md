# Production Economy & City Needs — Implementation Tracker

**Snapshot:** 2026-11-12  
**Project:** godot-city-buildit  
**Branch:** docs/scbi-production-economy-city-needs  
**Status:** Merged to main and deployed to GitHub Pages on 2026-11-12. Automated CI and desktop/mobile Chromium checks passed. Physical Android side-by-side visual acceptance remains open; do not claim pixel-identical SCBI UI until that review is complete.

**PR:** #394 — merge commit 06c3e2bd87435ddc3dce5df0d2c73ff37bff8fa8.
**Godot validation:** run 43208197179 — success.
**Web build / Chromium / Pages deploy:** run 43208197118 — success.

## Six implementation slices

| Slice | Deliverable | Evidence | Status |
|---|---|---|---|
| 1 | Single authoritative product/factory/store catalog | scripts/autoload/ProductionManager.gd; StorageManager registers display metadata from ProductionManager | 🟢 Core |
| 2 | Correct per-slot production and warehouse transfer | scripts/production/ProductionComponent.gd; scripts/autoload/StorageManager.gd; scripts/buildings/Building.gd | 🟢 Core |
| 3 | Residential upgrade plan and supplier details | scripts/ui/HUD.gd; scripts/buildings/Building.gd; ProductionManager upgrade requirements | 🟢 Core |
| 4 | City-wide needs dashboard and no-double-count allocation | scripts/autoload/CityDemandManager.gd; HUD City Needs shortcut | 🟢 Core |
| 5 | SCBI-inspired mobile production/residential panels | scripts/ui/HUD.gd; scripts/ui/Icons.gd; local crafted SVG icons | 🟡 Android screenshot comparison pending |
| 6 | Economy, construction timers, save/load and scores | scripts/autoload/EconomyManager.gd; SaveManager.gd; BuildManager.gd; Building.gd | 🟢 Code; CI pending |

## Current production catalog coverage

- Raw materials: 11; craftable products: 32; catalog-only product identities: 42.
- Building Supplies: 6 verified recipe entries.
- Hardware Store: 6 recipe entries.
- Farmer's Market: 7 recipe entries.
- Furniture Store: 5 recipe entries.
- Fast Food Restaurant: 5 craftable products; Popcorn remains visible but disabled until the store-star recipe is verified.
- Donut Shop: Bread Roll recipe; Home Appliances: BBQ Grill and Microwave Oven recipes; Gardening Supplies: six visible products with unverified recipes.
- Fashion Store, Sports Shop, Toy Store, Restoration Office, Farmer's Store and Dessert Shop: all six store families are selectable with their product identities visible; recipes remain disabled until exact inputs/times are sourced.
- Traditional Restaurant and Art Supplies: Mshin-specific production panels open with an explicit empty/verification message.

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

- [x] GitHub Actions CI passed on the merged main commit.
- [x] Godot 4.3 import, startup and end-to-end GameplaySmoke passed.
- [x] Web export passed.
- [x] Desktop and mobile-landscape Chromium launch checks passed.
- [x] GitHub Pages deployment completed successfully.
- [ ] Android landscape screenshots still need side-by-side comparison with current SimCity BuildIt production and residential panels.
- [ ] Touch scroll, tap, collect, close and upgrade actions still need a final check on a physical Android device.
- Do not call the UI pixel-identical until the Android comparison is completed.
