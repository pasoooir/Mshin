# MSHIN — Production Economy, Residential Upgrade & City Needs Specification

**Document status:** Research-backed design specification (documentation milestone)  
**Target project:** `godot-city-buildit` / Pasoo City BuildIt  
**Reference game:** SimCity BuildIt (SCBI)  
**Research snapshot:** 2026-11-12  
**Implementation status:** Design reference plus active implementation contract. Current code status and remaining data gaps are tracked in [Production Economy Implementation Tracker](PRODUCTION_ECONOMY_IMPLEMENTATION_TRACKER.md).

> **Purpose.** Establish one authoritative, detailed design contract for factories, commercial stores, item recipes, residential upgrade plans, citywide demand visibility, and the visual/UI language used by all related panels. The player must be able to understand and manage the city's production economy without opening every factory, store, or home individually.

---

## 0. Evidence, scope, and rules for interpreting the reference

### 0.1 Evidence hierarchy

Use sources in this order when validating SCBI behaviour:

1. **EA Help — official beginner guide:** authoritative for the high-level interaction loop, factory and store drag-to-produce behaviour, residential building plans, inventory, trading, city services, regions, roads, and offline limitations.
2. **SCBI item/building community databases:** useful for detailed item names, recipes, production times, unlock levels, and commercial building catalogues. These are secondary references and may lag game updates.
3. **Deconstructor of Fun (2015) analysis:** historical game-design analysis for the economy loop, retention/progression, trade, city growth, and design weaknesses. Treat it as a design lens, not a current data table.
4. **Mshin source code and automated tests:** authoritative for what Mshin currently does, not proof of what SCBI does.

### 0.2 Important distinctions

- SCBI's factory/store/residential interaction pattern is the reference experience; Mshin must implement its own data and balance in a traceable way.
- Do not copy EA artwork, screenshots, proprietary fonts, or game assets. Reproduce interaction hierarchy and visual grammar with original local assets.
- Do not label a community-wiki value as an EA-confirmed fact.
- Exact residential construction plans in SCBI are presented as contractor plans and can vary. The official guide confirms the plan/drag interaction, but does **not** publish a universal fixed six-stage recipe table. Therefore, the fixed six-stage Mshin recipe table is an existing Mshin rule, not a claim about SCBI.
- Preserve the already accepted Mshin starter chain: **Factory → Metal → Building Supplies → Nails → Residential upgrade**, including the existing first-upgrade cost of **1 Nail + 1 Metal**. Do not silently replace or delete it.
- The article by Deconstructor of Fun is from 2015. Its design observations remain useful, but its numerical details and feature inventory must be revalidated against current references.

### 0.3 Reference links

- EA official beginner guide: https://help.ea.com/en/articles/simcity/simcity-buildit/beginner-guide/
- Deconstructor of Fun (2015): https://www.deconstructoroffun.com/blog//2015/02/simcity-buildit-nice-town-but-would-you.html
- SCBI commercial buildings list: https://simcity.fandom.com/wiki/List_of_commercial_buildings_in_SimCity_BuildIt
- SCBI items list: https://simcity.fandom.com/wiki/List_of_items_in_SimCity_BuildIt
- SCBI industrial buildings: https://simcity-buildit.fandom.com/wiki/Industrial_Buildings
- SCBI building materials: https://simcity-buildit.fandom.com/wiki/Building_Materials
- SCBI residential buildings: https://simcity-buildit.fandom.com/wiki/Residential_Buildings
- Supplementary item reference (community-maintained): https://simcitymanager.com/guides/items-reference

---

# Part A — Reference catalogue: factories, stores, and items

## 1. Factory system

### 1.1 Factory tiers

The standard SCBI factory progression is represented by five tiers:

| Tier | SCBI-style name | Role | Mshin target slots | Mshin current-code note |
|---|---|---|---:|---|
| 1 | Small Factory | Starter raw-material production | 2 | Current code has 2 |
| 2 | Basic Factory | More parallel raw-material jobs | 3 | Current code has 3 |
| 3 | Mass Production Factory | Higher throughput | 4 | Current code has 4 |
| 4 | High-tech Factory | High throughput, reduced footprint/pollution target | 5 | Current code has 5 |
| 5 | Nano-tech Factory | Late-game efficient production | 5 | Current code has 5 |

Mshin's shared factory-count limit must remain level-driven, while the number of parallel production slots is tier-driven. A tier upgrade must not accidentally create an independent extra factory quota.

**Open discrepancy to resolve before implementation:** open PR #377 describes Nano-tech population requirement as **1,500,000**, while the currently inspected `BuildManager.gd` default-branch search excerpt showed **150,000**. The PR description is not proof of a merged value. Reconcile the actual target branch and accepted design decision before changing this threshold.

### 1.2 Standard raw materials

The following table reflects the standard factory materials and the commonly documented SCBI unlock levels/times. Times are production duration for one item, not a claim about Mshin's current timer implementation.

| Item ID | Display name | SCBI unlock level (community reference) | Base time | Notes |
|---|---|---:|---:|---|
| `metal` | Metal | 1 | 1 min | Starter material; preserve Mshin starter loop |
| `wood` | Wood | 2 | 3 min | Used by planks and crafted goods |
| `plastic` | Plastic | 5 | 9 min | Used by glue, measuring tape, etc. |
| `seeds` | Seeds | 7 | 20 min | Agricultural input |
| `minerals` | Minerals | 11 | 30 min | Bricks/cement and other goods |
| `chemicals` | Chemicals | 13 | 2 hr | Long-duration industrial input |
| `textiles` | Textiles | 15 | 3 hr | Fashion/fabric chain |
| `sugar_spices` | Sugar and Spices | 17 | 4 hr | Food chain |
| `glass` | Glass | 19 | 5 hr | Advanced construction/home goods |
| `animal_feed` | Animal Feed | 23 | 6 hr | Agricultural/food chain |
| `electrical` | Electrical Components | 29 | 7 hr | Advanced appliance/electronics chain |

Factory behaviour requirements:

- Multiple slots run independently and concurrently.
- A slot has exactly one job: queued, producing, ready-to-collect, or empty.
- Starting a job reserves/consumes any required inputs only for commercial recipes; raw factory jobs have no recipe inputs.
- Finished output remains on its slot/building until collected; collection is blocked, not destructive, when storage is full.
- Production uses persisted finish timestamps so progress continues correctly while the app/browser is closed.
- The player can choose a different raw material for each empty slot.
- Factory tier changes capacity/slot count and environmental impact; it must not silently change the raw-material recipe.
- Display exact unlock reason (Mayor Level, factory tier/quota, population requirement, affordability, or placement/road condition) instead of hiding locked catalogue entries.

### 1.3 Regional factories

EA confirms that regions have their own themed factories, crafting shops, materials, and residential zones, and that regions unlock from Capital City level 25 onward. The commonly documented regional material families include recycled fabric, coconut, oil, silk, and fish. These are **regional content**, not additions to the starter capital-city raw-material list.

Do not add regional factories to the capital city menu until the region system, regional inventory rules, regional currency, and region-specific recipes are specified and tested.

---

## 2. Commercial building catalogue

Commercial buildings transform raw materials and, in later chains, previously crafted items into higher-value goods. The catalogue below is the reference family list, not a statement that every store is currently implemented in Mshin.

| Store ID / reference family | Main product family | Known/reference product examples | Mshin status from inspected code |
|---|---|---|---|
| `building_supplies` — Building Supplies Store | Construction materials | Nails, Planks, Bricks, Cement, Glue, Paint | Partially implemented; six recipes exist |
| `hardware_store` — Hardware Store | Tools and hardware | Hammer, Measuring Tape, Shovel, Cooking Utensils, Ladder, Drill | Partially implemented; current recipe set is incomplete |
| `farmers_market` — Farmer's Market | Produce and food inputs | Vegetables, Flour Bag, Fruit & Berries, Cream, Corn, Cheese, Beef | Only Vegetables is currently in the inspected recipe table |
| `furniture_store` — Furniture Store | Furniture and home goods | Chair, Table, Home Textiles, Cupboard, Sofa | Only Chair and Table are currently in the inspected recipe table |
| Gardening Supplies Store | Garden goods | Grass, Tree Saplings, Garden Furniture, Fire Pit, Lawn Mower, Garden Gnome | Not present in inspected Mshin recipe data |
| Donut Shop | Bakery/drinks/desserts | Donuts, Green Smoothie, Bread Roll, Cherry Cheesecake, Frozen Yogurt, Coffee | Not present in inspected Mshin recipe data |
| Fashion Store | Clothing/accessories | Cap, Shoes, Watch, Business Suit, Backpack | Not present in inspected Mshin recipe data |
| Fast Food Restaurant | Fast food | Ice Cream Sandwich, Pizza, Burger, Cheese Fries, Lemonade, Popcorn | Building entry exists; recipe set empty in inspected BuildManager data |
| Home Appliances Store | Household appliances | BBQ Grill, Refrigerator, Lighting System, TV, Microwave | Not present in inspected Mshin recipe data |
| Sports Shop | Sports goods | Tennis Racket, Sports Drink, Soccer Shoes, Protein Bar, Ping-Pong Table | Not present in inspected Mshin recipe data |
| Toy Store | Toys/electronics | Block Letters, Kite, Teddy Bear, Game Console | Not present in inspected Mshin recipe data |
| Restoration / Restoration Office | Premium crafted/decorative goods | Forged Iron, Carved Wood, Cut Stone, Tapestries, Stained Glass | Not present in inspected Mshin recipe data |
| Farmer's Store | Regional/farm goods | Wool Shirt, Picnic Basket, Apple Jam | Not present in inspected Mshin recipe data |
| Dessert Shop | Desserts | Tiramisu, Churros, Profiterole, Mochi, Pavlova | Not present in inspected Mshin recipe data |

**Catalogue completeness rule:** this table is a family-level catalogue. It is not a complete 100+ item recipe dump. Each store's item list, exact ingredients, unlock level, production duration, sale value, and star-upgrade modifier must be transcribed into structured data from a current item reference and cross-checked before the store is marked data-complete. Never invent missing recipes to make a UI look populated.

### 2.1 Verified starter recipes — Building Supplies Store

| Product | Inputs | Base production time | SCBI unlock level (community reference) |
|---|---|---:|---:|
| Nails | 2 Metal | 5 min | 1 |
| Planks | 2 Wood | 30 min | 3 |
| Bricks | 2 Minerals | 20 min | 13 |
| Cement | 2 Minerals + 1 Chemicals | 50 min | 14 |
| Glue | 1 Plastic + 2 Chemicals | 60 min | 15 |
| Paint | 2 Metal + 1 Minerals + 2 Chemicals | 60 min | 16 / store star-upgrade gate in some references |

The item must show its ingredients, required quantity, current city-stock quantity, deficit, production duration, and whether the recipe is unlocked.

### 2.2 Verified Hardware Store starter recipes

| Product | Inputs | Commonly documented base time | SCBI unlock level |
|---|---|---:|---:|
| Hammer | 1 Metal + 1 Wood | 14 min | 4 |
| Measuring Tape | 1 Metal + 1 Plastic | 20 min | 6 |
| Shovel | 1 Metal + 1 Wood + 1 Plastic | 30 min | 9 |
| Cooking Utensils | 2 Metal + 2 Plastic + 2 Wood | 45 min | 17 |
| Ladder | 2 Planks + 1 Nails | 50 min | verify against current source |
| Drill | 2 Metal + 2 Plastic | 2 hr | verify against current source |

**Important Mshin data mismatch:** the currently inspected `ProductionManager.gd` uses 40 min for Hammer, 40 min for Measuring Tape, and 45 min for Shovel. Those values do not match the common SCBI reference values above. Do not silently overwrite them in a gameplay patch; record the source, decide whether the game is targeting SCBI timing or Mshin balancing, then update data and tests together.

### 2.3 Recipes that are currently implemented in Mshin

The inspected default-branch `ProductionManager.gd` contains:

- Raw: Metal, Wood, Plastic, Seeds, Minerals, Chemicals, Textiles, Sugar and Spices, Glass, Animal Feed, Electrical Components.
- Crafted: Nails, Planks, Bricks, Cement, Glue, Paint, Hammer, Measuring Tape, Shovel, Chair, Table, Vegetables.
- Current residential plan table: six stages with five transitions, described in Part C.

The current recipe data is a partial catalogue, not a complete SCBI economy. The code currently associates Chair/Table with Furniture Store and Vegetables with Farmer's Market, while many reference stores/items have no recipe entries yet.

---

# Part B — Production and inventory rules

## 3. One consistent state machine for every factory/store slot

Each production slot must use the same state model:

1. **Empty:** available for a new order.
2. **Selected:** item details are visible; no resources have been consumed yet.
3. **Queued/Producing:** player confirms; recipe inputs are deducted atomically; finish timestamp is saved.
4. **Ready:** timer has elapsed; output is visible and collectable.
5. **Blocked by storage:** output remains ready; collection is disabled until storage has room.
6. **Collected:** output is added to City Storage exactly once; slot becomes empty.

No product can be simultaneously in storage and still be collectable from a slot. No input may be consumed if the slot cannot start. A failed start must not partially deduct ingredients.

### 3.1 Different building behaviours

- **Industrial factory:** chooses from unlocked raw materials; no recipe-input panel; independent parallel slots.
- **Commercial store:** shows only its own recipes; each recipe lists all raw/crafted ingredients; inputs are consumed at order start; each slot has its own timer and collect action.
- **Residential building:** does not produce inventory items. It exposes its current contractor plan, missing quantities, reward, and an upgrade action when all required goods are available.
- **Trade Depot / Global Trade:** consume or grant inventory through explicit transactions; never bypass storage capacity or duplicate goods.

### 3.2 Shared City Storage

The warehouse is the single source of truth for available item quantities.

For every item:
- `stored`: quantity physically available in city inventory.
- `reserved`: quantity reserved by an accepted job/transaction (normally zero if inputs are consumed immediately).
- `required_now`: quantity required by all active residential plans and accepted contracts.
- `in_production`: expected output from currently active production slots.
- `deficit`: max(0, required_now - stored - usable_in_production).
- `surplus`: max(0, stored - required_now - safety_stock).

Never count a ready-but-uncollected output as warehouse stock. Show it separately as “Ready to collect”.

Storage capacity must be visible in all economy surfaces. When full, tell the player what is blocked and how much space is needed.

---

# Part C — Residential construction and upgrade requirements

## 4. What SCBI confirms about residential plans

EA's official guide confirms this interaction:

- Place a residential zone beside a road to start construction.
- The yellow hard-hat marker opens the building plan.
- The plan shows the items the contractor needs.
- The player supplies/drag-drops those items onto the building.
- Completing a plan starts the construction/upgrade result and grants the associated rewards.
- Upgrading increases population; services and specializations affect happiness and visual/value progression.

The official guide does **not** publish one fixed universal material recipe for every residential stage. SCBI community references describe changing contractor plans and refresh/transfer behaviour. Therefore, do not hardcode the current Mshin table as if it were an exact transcription of SCBI.

## 5. Existing Mshin residential rules that must be preserved until explicitly redesigned

Inspected `ProductionManager.gd` currently defines:

| Current Mshin transition | Current required goods | Current stage population table |
|---|---|---:|
| Stage 1 → 2 | 1 Nails + 1 Metal | Stage 1: 15; Stage 2: 30 |
| Stage 2 → 3 | 1 Planks + 1 Wood | Stage 3: 50 |
| Stage 3 → 4 | 1 Hammer + 2 Nails | Stage 4: 90 |
| Stage 4 → 5 | 1 Bricks + 1 Cement | Stage 5: 160 |
| Stage 5 → 6 | 1 Paint + 2 Planks + 1 Glass | Stage 6: 280 |

This is the current Mshin six-stage starter progression, not a claim about exact SCBI contractor plans. Existing saves and tests depend on it. Any later shift to dynamic plans must include a save migration and explicit acceptance tests.

## 6. Residential plan model for future data-driven expansion

Every residential building instance must expose a plan object with:

- `plan_id`, `building_id`, `from_stage`, `to_stage`
- `requirements[]`: item ID, display name, required quantity, stored quantity, in-production quantity, deficit, supplying store/factory
- `rewards`: population delta, XP, Simoleons, unlock progress, any milestone reward
- `plan_state`: hidden / available / partially supplied / ready / upgrading / completed
- `refresh_policy`: whether a plan can be refreshed/transferred, cooldown, cost, and limits (only if Mshin deliberately adopts this mechanic)
- `created_at`, `completed_at` for persistence and debugging

### 6.1 Requirement presentation

For each plan item show:

- product icon (original local PNG, transparent, 128×128 source artwork)
- item name
- `owned / required` count
- deficit badge
- supplier building type
- whether supplier is locked, absent, idle, producing, ready, or blocked by storage
- tap target that opens the relevant city overview/filter, not a mandatory trip to the supplier building

A plan with three requirements must remain readable at phone landscape size. Use compact product tiles with large quantity numerals; never compress item names into unreadable tiny text.

### 6.2 Upgrade action

- Keep the yellow hard-hat/upgrade affordance on eligible residential buildings.
- The citywide overview must also list every active plan; the user should not need to find the small hard hat in the 3D city.
- When all goods are available, enable the primary action and show the reward preview.
- When incomplete, show the missing items and their city-wide production routes.
- On confirmation, consume all required goods atomically, run the upgrade state, update stage/population/XP/economy/services, save, and refresh all demand summaries.
- If the inventory changes while the panel is open, recalculate the plan state before accepting the action.

---

# Part D — Citywide demand and production overview (no building-by-building clicking)

## 7. Core requirement

Add a persistent, easy-to-reach **City Needs / Production Overview** entry point to the HUD. It must aggregate information across every completed factory, commercial store, and residential building. The player must be able to answer “What does my city need now?” without opening individual buildings.

The overview is not just a warehouse list. It is a live dependency view linking residential plans → crafted products → commercial recipes → raw materials → factories.

## 8. Overview information architecture

### 8.1 Summary header

Show:
- City Storage: used / capacity.
- Active production jobs: running / total slots.
- Ready to collect: count of outputs.
- Residential plans: ready, waiting, and upgrading counts.
- Top shortage count and a clear “Resolve shortages” entry.

### 8.2 Demand tabs / filters

Recommended filters:
- **All Needs** — combined view.
- **Homes** — residential plans grouped by building/priority.
- **Raw Materials** — factory outputs.
- **Crafted Goods** — store outputs.
- **In Production** — running jobs and ETA.
- **Ready to Collect** — outputs waiting on collection.
- **Blocked** — missing supplier, locked recipe, no capacity, storage full, or no connected building.

### 8.3 Product demand row

Every row must include:

| Field | Meaning |
|---|---|
| Product icon + name | What is needed |
| Stored | Available in City Storage |
| Required | Total active plan demand |
| In production | Expected quantity from active jobs |
| Ready | Finished but uncollected quantity |
| Deficit | Remaining shortage after stored and usable in-production |
| Supplier | Store/factory family that makes it |
| ETA | Earliest time the deficit can be filled, where calculable |
| Action | Start/collect/open relevant production workflow |

Use a stable shortage formula and explain it in code comments/tests:
`deficit = max(0, required_now - stored - in_production_usable)`.
Ready-to-collect is shown as a separate actionable amount; it must not be counted as stored until collected.

### 8.4 Home-first demand grouping

The default overview should be organized around homes, not only alphabetically by item:

- Residential building name / district / stage.
- Next upgrade stage.
- Required goods as icon tiles.
- Owned / required quantity.
- Missing count.
- “Can upgrade” / “Waiting for goods” state.
- A “Make missing items” shortcut that opens the relevant production queue.

If multiple homes need the same product, aggregate the city total but preserve the per-home breakdown. Do not accidentally allocate the same physical item to several homes in the UI.

### 8.5 Supplier route

For every shortage, provide a route:
- Raw item → list of available factories and empty slots.
- Crafted item → exact commercial store and recipe.
- Missing/locked supplier → show the unlock condition or build requirement.
- No supplier in city → show the relevant build menu entry, gated by level/population/currency.
- Supplier exists but disconnected/incomplete → show the exact operational reason.

The overview may open a production panel or highlight the building on the map, but the user must not be forced to click around the city to discover what is missing.

### 8.6 Priority and sorting

Default sort:
1. Goods that block an upgrade already fully supplied except for that item.
2. Goods needed by the largest number of active residential plans.
3. Goods with the shortest production time / easiest resolution.
4. Long-duration goods that should be started early.

Provide manual sorting by shortage, number of homes affected, ETA, and item name. Do not auto-start jobs without player confirmation.

### 8.7 Notifications and map indicators

- Subtle, non-blocking badges for ready outputs and upgrade-ready homes.
- Optional map overlay highlighting homes waiting for goods and suppliers that can resolve the shortage.
- No permanent floating labels over every building.
- Do not obscure the center city view or break the accepted separated HUD hierarchy (top-left and top-right independent layouts; preserve central space).
- Avoid a modal popup on every production completion. Use a consolidated notification queue.

---

# Part E — UI/UX visual specification aligned to SCBI

## 9. Shared visual language

The goal is close visual and interaction alignment, not pixel-copying copyrighted assets. All panels must look like parts of one coherent game.

### 9.1 Reference-driven visual tokens

Do not invent exact SCBI hex values from memory. Capture current in-game screenshots at the relevant states, sample the actual colours, and store the resulting Mshin tokens in a theme resource with a source screenshot reference.

Token groups to define:
- Primary panel surface (warm/light neutral).
- Secondary surface and card surface.
- Main text, secondary text, disabled text.
- Positive/available/ready state.
- Warning/shortage state.
- Locked/unavailable state.
- Production progress.
- Currency and premium-currency accents.
- Panel shadow, border, separator, and modal dimmer.

Mshin must use original colors/assets where needed, but preserve the hierarchy and contrast of the reference.

### 9.2 Typography

- Use one readable rounded sans-serif family for headings and body, bundled locally with the project and licensed for redistribution.
- Use a strong display weight for panel titles and product quantities.
- Product names: medium/semibold.
- Recipe ingredients and helper text: regular.
- Timers and quantities: tabular numerals where supported.
- Use consistent line height and baseline alignment.
- No emoji glyphs as production or status icons; use the project's local transparent PNG icon catalogue.
- Never use an external font CDN; game must work offline.

### 9.3 Panel geometry and hierarchy

All production and residential panels should follow the same component grammar:

1. A clear header with building/store identity and close button.
2. A scrollable product/plan region.
3. A selected-product detail card.
4. Ingredients/requirements row with quantities.
5. Production queue with independently readable slots.
6. One prominent primary action (Start / Collect / Upgrade).
7. Secondary actions with lower visual weight.

Factory panel:
- Show factory name/tier and slot count.
- Show raw-material product cards only.
- Selecting a material opens a detail card with item icon, name, production duration, and Start action.
- Do not show recipe ingredient rows for raw materials.
- Show per-slot progress, remaining time, and Collect.

Commercial store panel:
- Show only products made by that store.
- Show ingredients on selection, including icons and required quantities.
- Distinguish missing ingredients from locked recipes.
- Show the exact number of free production slots.
- Start consumes inputs; this must be clear before confirmation.
- Ready output exposes Collect.

Residential panel:
- Show building stage and next-stage preview.
- Show population/XP/currency rewards.
- Show all contractor-plan goods and owned/required counts.
- Explain shortages and supplier routes.
- Upgrade action is enabled only when all goods are present and the building is otherwise eligible.

### 9.4 Product card behaviour

- Product icon is the primary visual anchor.
- Product name must be readable at mobile landscape scale.
- Show lock/unlock state without hiding the item from the catalogue.
- Show production time on the card or detail view.
- Use consistent selected outline and pressed state.
- The current Mshin gameplay test already expects floating hexagonal item tiles and a separate white recipe detail card for commercial products. Preserve this accepted direction unless a reference screenshot review identifies a concrete improvement.
- The current test also expects a dimmed city backdrop, horizontally browsable product-card row, queue slots, countdown, progress bar, and Collect action. These are current Mshin acceptance contracts, not a claim that every pixel matches SCBI.

### 9.5 Responsive/mobile requirements

- Design first for mobile landscape; all key controls must fit without overlap.
- Touch targets must be comfortably tappable; no tiny close/collect buttons.
- Horizontal product carousel must support swipe without stealing taps on buttons.
- Vertical scrolling belongs to the panel content, not the city camera while the panel is open.
- Keep close action easy to reach.
- Preserve the center city view and the previously accepted independent top-left/top-right HUD composition.
- Respect safe areas and varying Android aspect ratios.
- Verify at minimum 720×360, 800×360, 854×393, and 915×412 logical viewport profiles, plus one physical Android device.

---

# Part F — Architecture and data contracts

## 10. Single source of truth

Do not scatter recipe and demand logic across `Building.gd`, `HUD.gd`, and individual store scripts.

Recommended logical data resources (names are proposed; adapt to existing project conventions before implementation):

- `ItemDefinition`: id, localized/display name, icon path, category, unlock level, stack/value metadata.
- `ProductionRecipe`: output item, quantity, input map, duration, unlock conditions, owning store ID.
- `ProductionBuildingDefinition`: building ID, category, tier, slot count, recipe/raw-material allowlist, pollution/operational metadata.
- `ResidentialUpgradePlan`: transition, requirements, rewards, refresh policy, plan state.
- `CityDemandSnapshot`: stored, reserved, active demand, running, ready, deficit, supplier routes, calculated ETA.
- `ProductionJob`: job ID, building ID, slot index, output, inputs snapshot, start/finish timestamps, state, save version.

Existing GDScript autoload responsibilities should remain separated:
- `ProductionManager`: catalogue/recipe lookup, unlock checks, plan definitions and production rules.
- `StorageManager`: inventory counts, capacity, atomic add/remove and change signals.
- `BuildManager`: building instances, type definitions, placement and operational status.
- `ProductionComponent`: per-building slot state, timers, start/collect.
- `HUD.gd`: presentation and user input only; no duplicated recipe tables.
- New city-demand service/manager: aggregate demand snapshots and supplier routing; subscribe to storage, building, plan, and job changes.

### 10.1 Required events/signals

At minimum, demand recalculation must respond to:
- inventory item added/removed;
- production job started/completed/collected/cancelled;
- building placed/removed/moved/completed;
- residential plan created/refreshed/supplied/completed;
- level/unlock changed;
- storage capacity changed;
- supplier becomes operational/non-operational.

Avoid recalculating every frame. Rebuild snapshots on relevant events and use a debounced refresh for rapid multi-item changes.

### 10.2 Save compatibility

- Add a save schema version before changing production/plan structures.
- Preserve existing single-job fields while migrating to slot arrays.
- Persist every active job finish timestamp and every residential plan ID/state.
- On load, recompute remaining time from Unix timestamps.
- Never grant duplicate outputs when a job is restored.
- Keep the current Metal/Nails/first-upgrade save path load-compatible.
- Add deterministic migration tests using a fixture from the previous save schema.

---

# Part G — Known implementation gaps found in the repository

## 11. Verified code/document gaps at research time

The following are based on inspected source files in the repository, not guesses:

1. `ProductionManager.gd` has 11 standard raw-material definitions and 12 crafted-item definitions; this is far smaller than the reference game's full item catalogue.
2. Current crafted entries are Nails, Planks, Bricks, Cement, Glue, Paint, Hammer, Measuring Tape, Shovel, Chair, Table, and Vegetables.
3. Current residential progression is a fixed six-stage table with five deterministic recipes. It must be labelled as Mshin's current design, not SCBI's exact dynamic contractor plans.
4. `BuildManager.gd` exposes multiple commercial menu entries, but inspected entries for Traditional Restaurant, Fast Food, and Art Supplies had empty recipe arrays; their presence in the build menu does not mean their production system is implemented.
5. Farmer's Market currently has only the Vegetables recipe in the inspected production data; Furniture Store currently has only Chair and Table.
6. The existing HUD/gameplay smoke contract includes a darkened production overlay, horizontal product cards, hexagonal product tiles, separate white recipe detail card, queue slots, timers, progress bars, and collect buttons.
7. The README roadmap still marks several factory/store/house-plan UI tasks as incomplete even though portions of the production panel and tests now exist. The roadmap must be reconciled with actual code/tests after this specification is accepted.
8. Current README's first-upgrade loop explicitly says 1 Nail + 1 Metal. Preserve it.

### 11.1 Do not misrepresent the state

- A catalogue entry is not a working recipe.
- An icon file is not proof that the item can be produced.
- A production panel is not proof that all store types have correct recipes.
- A fixed upgrade recipe is not proof of exact SCBI residential-plan parity.
- A green CI run is not proof of visual parity on a physical phone.

---

# Part H — Delivery sequence and acceptance criteria

## 12. Implementation slices (documentation defines the order)

### Slice 0 — Evidence and data audit
- Capture/record current SCBI references for each store and product family.
- Transcribe item IDs, recipes, base durations, unlock conditions, and source URLs.
- Mark every value as official, secondary-reference, or Mshin-specific.
- Compare the resulting catalogue against `ProductionManager.gd`, `BuildManager.gd`, icon catalogue, and tests.
- Acceptance: no unreferenced recipe values; every item has a provenance note.

### Slice 1 — Canonical data model
- Move raw materials, recipes, store allowlists, and residential plan definitions to one data source.
- Preserve legacy IDs and first-upgrade recipe.
- Add validation for missing item IDs, circular recipes, missing suppliers, invalid durations, and locked inputs.
- Acceptance: all catalogue entries validate and no recipe is duplicated in UI code.

### Slice 2 — Correct per-building production behaviour
- Factories choose only raw materials.
- Each commercial store displays only its own valid recipes.
- Per-slot job state and input consumption are atomic.
- Collection respects storage capacity.
- Acceptance: integration tests for every store family and at least one multi-input recipe per family.

### Slice 3 — Residential plan and upgrade parity
- Expose current Mshin six-stage plan in the UI.
- Add plan model abstraction so dynamic plans can be added later without breaking saves.
- Show requirements/rewards and ensure materials are consumed once.
- Acceptance: test each transition and save/load at every stage.

### Slice 4 — City Needs Overview
- Aggregate all residential plan demand.
- Show inventory, in-progress, ready-to-collect, and deficits separately.
- Route missing goods to suppliers and identify blocked/locked cases.
- Acceptance: a test city with several homes and multiple suppliers shows exact non-duplicated totals; dashboard updates after every inventory/job/building event.

### Slice 5 — SCBI-aligned UI pass
- Compare real reference screenshots for factory, store, and residential plan states.
- Tune panel proportions, surfaces, typography, card shape, item icon size, quantities, timers, queue and buttons.
- Use local assets and fonts only.
- Acceptance: documented side-by-side review at target mobile landscape resolutions; no clipping/overlap; touch actions pass.

### Slice 6 — Full economy integration
- Connect demand dashboard to Trade Depot, Global Trade, NPC deals, storage upgrades, cargo shipments, and future regional production.
- Ensure long-term goals and progression unlocks use the same canonical item IDs.
- Acceptance: no disconnected inventory path; every transaction updates city demand and storage correctly.

## 13. Required automated test matrix

- Raw item unlock level and duration.
- Factory tier slot counts and shared factory quota.
- Factory parallel production and independent timers.
- Store recipe ownership and product unlock gates.
- Multi-input recipe exact deductions.
- Failed job start does not consume any inputs.
- Output collected exactly once.
- Full storage blocks collection without losing ready output.
- Residential plan counts are exact and aggregated once.
- First upgrade still requires 1 Nail + 1 Metal.
- Every stage consumes only its own plan requirements.
- Demand dashboard distinguishes stored / producing / ready / deficit.
- A single stored item cannot be allocated to two separate homes in the summary.
- Supplier routing handles missing store, locked recipe, no empty slot, disconnected building, and full storage.
- Dashboard updates on item add/remove, production start/finish/collect, home add/remove/move, plan change, and load.
- Save/load restores production jobs, plans, and demand totals without duplication.
- Mobile panel tests verify scrolling, taps, close button, queue actions, and landscape layouts.

## 14. Definition of Done

This milestone is complete only when:

- The full store/factory family catalogue is documented with provenance.
- Every implemented recipe has correct inputs, output, duration, unlock conditions, and supplier.
- Every residential building exposes its next plan without relying only on tapping the building.
- The City Needs Overview shows the citywide picture accurately and updates live.
- Factory/store/residential panels share a coherent SCBI-inspired visual system.
- All current accepted Mshin rules, especially Metal → Nails → first house upgrade, remain intact.
- Automated validation and gameplay tests pass.
- Mobile browser and physical Android visual acceptance are recorded separately.
- The documentation and execution tracker are updated to reflect actual completion evidence.

---

## Appendix — Current Mshin file map inspected for this specification

| Responsibility | Current file |
|---|---|
| Main project roadmap | `README.md` |
| Godot project README | `godot-city-buildit/README.md` |
| Building catalogue and factory/store definitions | `godot-city-buildit/scripts/autoload/BuildManager.gd` |
| Raw materials, crafted items, residential plans | `godot-city-buildit/scripts/autoload/ProductionManager.gd` |
| Building state and interaction | `godot-city-buildit/scripts/buildings/Building.gd` |
| Production slot state | `godot-city-buildit/scripts/production/ProductionComponent.gd` |
| Inventory | `godot-city-buildit/scripts/autoload/StorageManager.gd` |
| Production/residential panels | `godot-city-buildit/scripts/ui/HUD.gd` |
| Gameplay acceptance | `godot-city-buildit/tests/GameplaySmoke.gd` |
| Local item/building icon IDs | `godot-city-buildit/scripts/ui/Icons.gd` |

**Source caution:** Community references are living documents and sometimes disagree on production time, unlock level, or regional content. Revalidate a value against at least one current item reference before converting it into an authoritative Mshin balance rule.


---

# 28. Implementation status — 2026-11-12

The six implementation slices now have corresponding code in the current Mshin implementation branch. This section distinguishes completed core behaviour from catalogues that remain intentionally disabled because their exact recipes are not verified.

| Slice | Current implementation evidence | Status |
|---|---|---|
| 1. Central data catalogue | ProductionManager.gd owns raw materials, factory-tier permissions, 32 craftable products and store recipes; StorageManager derives display metadata from it. | 🟢 Core |
| 2. Factory/store production | Tier-specific raw permissions; per-slot timestamp jobs; atomic input deduction; collect-to-warehouse; full-storage protection. | 🟢 Core |
| 3. Residential upgrade plans | Existing six-stage Mshin plan retained; 1 Nail + 1 Metal remains the first upgrade; residential detail panel shows material counts and suppliers. | 🟢 Core |
| 4. City Needs dashboard | CityDemandManager.gd aggregates home demand, production, ready jobs, supplier routes and shared-stock allocation; persistent HUD shortcut opens the dashboard. | 🟢 Core |
| 5. SCBI-inspired UI | Shared light production/residential surfaces, product tiles, input details, status warnings, timers, queue and mobile scroll behaviour. | 🟡 Visual comparison still required on Android against current in-game reference captures |
| 6. Economy/save integration | Build costs, upgrade rewards, XP, population, warehouse transactions, construction finish timestamps and save migration are connected. | 🟢 Code; CI/runtime validation pending |

## 28.1 Current SCBI commercial-store coverage

All 14 standard SCBI commercial families are selectable in Mshin and open a store-specific production/catalog panel.

| Store family | Craftable products | Visible but unverified products |
|---|---:|---:|
| Building Supplies | 6 | 0 |
| Hardware Store | 6 | 0 |
| Farmer's Market | 7 | 0 |
| Furniture Store | 5 | 0 |
| Fast Food Restaurant | 5 | 1 |
| Donut Shop | 1 | 5 |
| Home Appliances | 2 | 3 |
| Gardening Supplies | 0 | 6 |
| Fashion Store | 0 | 5 |
| Sports Shop | 0 | 5 |
| Toy Store | 0 | 4 |
| Restoration Office | 0 | 5 |
| Farmer's Store | 0 | 3 |
| Dessert Shop | 0 | 5 |

Current catalog totals: 11 raw materials, 32 craftable products and 42 visible catalog-only product identities. A catalog-only product remains visible but cannot start production; its detail card explicitly says that recipe inputs and time are not verified. No recipe or production time is fabricated.

Fast Food currently supports Ice Cream Sandwich, Pizza, Burger, Cheese Fries and Lemonade Bottle. Popcorn remains disabled because its default zero-star production recipe is not available in the current Mshin store-upgrade model. Bread Roll (Donut Shop), BBQ Grill and Microwave Oven (Home Appliances), and Fruit & Berries (Farmer's Market) are implemented as upstream recipe chains. Tree Sapling is visible in Gardening Supplies but its own recipe remains unverified.

Traditional Restaurant and Art Supplies are Mshin-specific custom stores; their production panels explicitly show that no verified product catalog is registered yet. The legacy Shop Chain routes to the Building Supplies recipe family.


## 28.2 Source conflicts retained visibly

Community references disagree on several recipe inputs, including Glue, Paint, Cooking Utensils, Flour Bag and Corn. The implementation records provenance and surfaces a warning in the product details for disputed entries. These values must be checked against a current live-game capture before final economy balancing. This avoids silently treating one community table as an EA-confirmed recipe.

## 28.3 Inventory and home allocation invariants

- A stored item is allocated to at most one residential plan in the dashboard snapshot.
- Ready-to-collect and in-production quantities are shown separately from stored inventory.
- An upgrade button is enabled only when that home's allocated stored quantities cover its entire plan.
- Starting a craft validates every input before mutating storage; failed starts do not partially consume items.
- Collect adds exactly one output to storage; a full warehouse leaves the slot ready.
- Construction and production finish timestamps survive save/load; version-1 saves remain accepted.

For exact test names and paths, see [Production Economy Implementation Tracker](PRODUCTION_ECONOMY_IMPLEMENTATION_TRACKER.md).


## 28.4 Live inventory and production queue in City Needs

City Needs includes every stored City Storage item with its local icon, name and count, plus a live list of every factory/store job: product, supplier building, slot, remaining time and Ready-to-Collect state. A queue action opens the relevant supplier panel; collection remains an explicit player action. Active ETAs refresh once per second while jobs exist, preserving the current City Needs scroll position.
