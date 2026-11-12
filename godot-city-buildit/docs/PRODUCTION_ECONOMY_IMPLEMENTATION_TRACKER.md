# Production Economy & City Needs — Implementation Tracker

**Snapshot:** 2026-11-12  
**Project:** godot-city-buildit  
**Branch:** docs/scbi-production-economy-city-needs  
**Status:** Implementation committed to the working PR branch; CI and Android visual acceptance are still required. This tracker does not imply merge or deployment.

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
- Local product icon catalog coverage.
- Construction finish timestamp creation.
- Fast Food catalog visibility, five enabled recipes and one disabled store-star recipe.
- All 14 SCBI commercial store types and product-family catalog counts.
- Existing gameplay smoke continues to cover production, collection, first home upgrade, save and load.

## Final acceptance still required

- GitHub Actions CI must pass on the PR head.
- Godot 4.3 headless GameplaySmoke must pass.
- Web export and Pages deployment must pass after merge.
- Android landscape screenshots must be compared side-by-side with current SimCity BuildIt production and residential panels.
- Touch scroll, tap, collect, close and upgrade actions must be checked on a real Android device.
- Do not call the UI pixel-identical until that comparison is completed.
