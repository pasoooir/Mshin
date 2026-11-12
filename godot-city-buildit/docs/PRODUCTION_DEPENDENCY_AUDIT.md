# Production Dependency Audit — 2026-11-12

## Evidence sources

The following secondary references were used for the item and recipe checks in this change. They are community-maintained references, not EA-confirmed balance tables:

- Items, raw materials, commercial recipes, and total-time reference: https://simcity.fandom.com/wiki/List_of_items_in_SimCity_BuildIt
- Commercial store catalogues, unlock levels, base times, values, and store-star reductions: https://simcity.fandom.com/wiki/List_of_commercial_buildings_in_SimCity_BuildIt
- Cross-check for direct recipe inputs, including Popcorn and Home Appliances: https://simcity-buildit.fandom.com/wiki/Crafting_Recipes
- Tree Sapling production chain: https://simcity-buildit.fandom.com/wiki/Tree_Sapling

## Verified data corrections in this slice

| Item | Corrected reference data | Evidence |
|---|---|---|
| Measuring Tape | Max Value 110 | Items list |
| Bread Roll | Level 24, 60 min, Max Value 1,840 | Items list |
| BBQ Grill | Max Value 530; 165 min; 3 Metal + 1 Cooking Utensils | Items list + Crafting Recipes |
| Ice Cream Sandwich | Max Value 2,560; 14 min; 1 Cream + 1 Bread Roll | Items list + Crafting Recipes |
| Burger | Max Value 3,620; 35 min; 1 Beef + 1 Bread Roll + 1 BBQ Grill | Items list + Crafting Recipes |
| Lemonade Bottle | Max Value 1,690; 60 min | Items list + Crafting Recipes |
| Popcorn | Level 43, 30 min, Max Value 1,250; 2 Corn + 1 Microwave Oven | Items list + Crafting Recipes |
| Lawn Mower | Level 30, 120 min, Max Value 840; 3 Metal + 1 Electrical Components + 1 Paint | Items list |

Glue, Paint, Cooking Utensils, Flour Bag, and Corn were previously tagged as conflicting/variant community data. Their active ingredient rows are now aligned with the Fandom item list and no longer carry the old conflict marker. Their source remains secondary-reference provenance, not an EA guarantee.

## Dependency tree behaviour

- The dependency display now reports required quantity, current stock, and missing quantity at each level.
- Existing stock is consumed in the display calculation before expanding upstream requirements. If the required intermediate product is already in City Storage, its upstream recipe is not shown as a current need.
- Repeated ingredients share a remaining-stock ledger so the same inventory units are not counted twice.
- Unknown/catalog-only recipes stop at the item and explicitly report that the recipe is not verified.
- Cycles are detected and stopped instead of recursing indefinitely.
- The estimated remaining chain time is display-only and is never written into the canonical recipe data.

## Critical-path estimate limitations

The current estimate is intentionally labelled **APPROX.** It uses base production durations, treats raw-material production as parallel, and adds sequential batches for repeated commercial outputs. It does not apply store-star reductions or speedups. It also does not fully schedule competing sibling jobs that share the same commercial store queue; treat the value as a planning hint, not a guaranteed completion timestamp. If any required recipe is unverified, the estimate is suppressed.

## Factory/store behaviour notes

- Factory slots remain independent and parallel; raw materials have no recipe inputs.
- Commercial stores have a two-slot default queue in Mshin per the currently accepted project requirement, with an API to purchase up to eleven slots using a caller-supplied SimCash price. No price table is hardcoded.
- **Reference discrepancy:** the Fandom commercial-building page describes a default one-item queue, while the accepted Mshin requirement specifies two starting queue slots. Keep the accepted Mshin rule for this branch, but do not claim exact parity on this detail until the live-game reference is reconciled.
- The in-game queue-expansion purchase button and its price display are not part of this behaviour-only slice yet.

## Tests added/updated

- Inventory-aware Fruit & Berries dependency tree stops at an already-stocked Tree Sapling.
- Missing Seeds and intermediate Shovel requirements are exposed recursively.
- Nails estimate is tested as 1 minute parallel Metal + 5 minute Nails production.
- Unverified catalog-only products do not receive fabricated chain-time estimates.
- Popcorn and Lawn Mower recipe data are checked against the Fandom references.
- Commercial queue default capacity, SimCash expansion, and capacity persistence are covered in GameplaySmoke.
