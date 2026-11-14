# Production Dependency System — Complete Item Chain Reference

**Generated from:** `godot-city-buildit/scripts/autoload/ProductionManager.gd` on `main`  
**Snapshot:** 2026-11-14  
**Raw materials:** 16 | **Crafted recipes:** 73 | **Store families:** 14  
**Purpose:** every producible item must have an explicit, inspectable input dependency; no recipe may be treated as an unexplained free output.

## 1. Non-negotiable design rules

1. **No unexplained output.** Every crafted product has one or more explicit ingredients with positive integer quantities. The only zero-input nodes are factory raw materials, which are extracted/produced by factories through their own production process.
2. **Complete chain visibility.** For any selected output, the player can expand all levels down to raw factory materials, with quantities multiplied and aggregated correctly.
3. **One source of truth.** Recipe UI, production validation, residential requirements, trade, city demand and dependency planning must read the same item/recipe identifiers and quantities. No duplicated hard-coded recipe tables.
4. **No silent substitution.** If a recipe is disputed, disabled or unverified, show that status and the reason; do not silently substitute an ingredient or allow crafting.
5. **Availability is explicit.** Each ingredient shows required, in City Storage, reserved by active orders, and still missing. Available amount = stored amount − reserved amount. Starting an order atomically reserves/deducts all ingredients or none.
6. **Order is not the same as inventory.** Queueing an order must clearly say whether ingredients are consumed immediately (Mshin current model) or on start. The current model consumes at order acceptance; UI must reflect this.
7. **Time and capacity are visible.** Show base duration, store-star modifier, remaining time, queue position, slot count, storage capacity impact and any upstream production still required.
8. **No dead ends.** Every item must be classified as raw material, intermediate, final/leaf product, special/event item, or non-craftable catalog identity. A leaf product is allowed; an item with no recipe and no valid raw/source classification is not.
9. **No circular recipes.** Dependency graph must be acyclic. Any cycle blocks catalog validation.
10. **No inaccessible dependencies.** Every ingredient must exist, have an identified producer/source, and be unlockable before or at the output's unlock level. If a source has a different unlock model (region/event/store-star), encode that gate explicitly.
11. **Never fake parity.** EA official guides establish gameplay mechanics; detailed recipes and times from community references remain secondary evidence unless confirmed in-game.
12. **Player-facing transparency.** Display the immediate recipe first, then an expandable full chain, not a wall of unexplained icons. Use plain language, icons plus text, and exact counts.

## 2. Production dependency model

```text
Factory raw material (e.g. Metal)
        ↓
Commercial intermediate (e.g. Nails)
        ↓
Advanced intermediate (e.g. Hammer / Glue / Flour Bag)
        ↓
Finished product (e.g. Chair / Shoes / Burger)
        ↓
Residential upgrade / city order / trade / event
```

A product may consume several branches. The planner must merge duplicate requirements across branches. Example: if a recipe requires 2 items that each need Metal, the full raw-material total must add both branches, not show them independently as if one stock unit could satisfy both.

## 3. All raw materials

These are the current factory-produced roots; they are not commercial products and therefore do not have crafting ingredients. Their own factory queue, duration, unlock and regional source must be shown.

| ID | Material | Factory base time | Unlock | Source |
|---|---|---:|---:|---|
| `metal` | Metal | 1 min | 1 | Fandom |
| `wood` | Wood | 3 min | 2 | Fandom |
| `plastic` | Plastic | 9 min | 5 | Fandom |
| `seeds` | Seeds | 20 min | 7 | Fandom |
| `minerals` | Minerals | 30 min | 11 | Fandom |
| `chemicals` | Chemicals | 120 min | 13 | Fandom |
| `textiles` | Textiles | 180 min | 15 | Fandom |
| `sugar_spices` | Sugar and Spices | 240 min | 17 | Fandom |
| `glass` | Glass | 300 min | 19 | Fandom |
| `animal_feed` | Animal Feed | 360 min | 23 | Fandom |
| `electrical` | Electrical Components | 420 min | 29 | Fandom |
| `coconut` | Coconut | 120 min | 25 | Mshin Regional |
| `snowberry` | Snowberry | 180 min | 30 | Mshin Regional |
| `cactus_fruit` | Cactus Fruit | 240 min | 35 | Mshin Regional |
| `herbs` | Herbs | 300 min | 40 | Mshin Regional |
| `olives` | Olives | 360 min | 45 | Mshin Regional |

## 4. Full recipe catalogue — immediate and fully expanded requirements

Quantities are for **one output unit**. Full-chain raw quantities recursively multiply every branch and aggregate duplicate raw materials.

### Building Supplies Store

| Product | Direct recipe | Full raw-material requirement | Base time | Unlock / gate | Evidence |
|---|---|---|---:|---|---|
| **Nails** (`nails`) | 2 × Metal | 2 × Metal | 5 min | Level 1 | Fandom |
| **Planks** (`planks`) | 2 × Wood | 2 × Wood | 30 min | Level 3 | Fandom |
| **Bricks** (`bricks`) | 2 × Minerals | 2 × Minerals | 20 min | Level 13 | Fandom |
| **Cement** (`cement`) | 2 × Minerals + 1 × Chemicals | 2 × Minerals + 1 × Chemicals | 50 min | Level 14 | Fandom |
| **Glue** (`glue`) | 1 × Plastic + 2 × Chemicals | 1 × Plastic + 2 × Chemicals | 60 min | Level 15 | Fandom |
| **Paint** (`paint`) | 2 × Metal + 1 × Minerals + 2 × Chemicals | 2 × Metal + 1 × Minerals + 2 × Chemicals | 60 min | Level 16; 1 store star | Fandom |

### Hardware Store

| Product | Direct recipe | Full raw-material requirement | Base time | Unlock / gate | Evidence |
|---|---|---|---:|---|---|
| **Hammer** (`hammer`) | 1 × Metal + 1 × Wood | 1 × Metal + 1 × Wood | 14 min | Level 4 | Fandom |
| **Measuring Tape** (`measuring_tape`) | 1 × Metal + 1 × Plastic | 1 × Metal + 1 × Plastic | 20 min | Level 6 | Fandom |
| **Shovel** (`shovel`) | 1 × Metal + 1 × Wood + 1 × Plastic | 1 × Metal + 1 × Wood + 1 × Plastic | 30 min | Level 9 | Fandom |
| **Cooking Utensils** (`cooking_utensils`) | 2 × Metal + 2 × Wood + 2 × Plastic | 2 × Metal + 2 × Wood + 2 × Plastic | 45 min | Level 17 | Fandom |
| **Ladder** (`ladder`) | 2 × Planks + 2 × Metal | 4 × Wood + 2 × Metal | 60 min | Level 20; 1 store star | Fandom |
| **Drill** (`drill`) | 2 × Metal + 2 × Plastic + 1 × Electrical Components | 2 × Metal + 2 × Plastic + 1 × Electrical Components | 120 min | Level 30 | Fandom |

### Furniture Store

| Product | Direct recipe | Full raw-material requirement | Base time | Unlock / gate | Evidence |
|---|---|---|---:|---|---|
| **Chair** (`chair`) | 2 × Wood + 1 × Nails + 1 × Hammer | 3 × Wood + 3 × Metal | 20 min | Level 10 | Fandom |
| **Home Textiles** (`home_textiles`) | 2 × Textiles + 1 × Measuring Tape | 2 × Textiles + 1 × Metal + 1 × Plastic | 75 min | Level 25 | Fandom |
| **Cupboard** (`cupboard`) | 2 × Planks + 2 × Glass + 1 × Paint | 4 × Wood + 2 × Glass + 2 × Metal + 1 × Minerals + 2 × Chemicals | 45 min | Level 26; 1 store star | Fandom |
| **Couch** (`couch`) | 3 × Textiles + 1 × Drill + 1 × Glue | 3 × Textiles + 2 × Metal + 3 × Plastic + 1 × Electrical Components + 2 × Chemicals | 150 min | Level 33 | Fandom |
| **Table** (`table`) | 1 × Planks + 2 × Nails + 1 × Hammer | 3 × Wood + 5 × Metal | 30 min | Level 16 | Fandom |

### Farmer's Market

| Product | Direct recipe | Full raw-material requirement | Base time | Unlock / gate | Evidence |
|---|---|---|---:|---|---|
| **Vegetables** (`vegetables`) | 2 × Seeds | 2 × Seeds | 20 min | Level 8 | Fandom |
| **Flour Bag** (`flour_bag`) | 2 × Seeds + 2 × Textiles | 2 × Seeds + 2 × Textiles | 30 min | Level 17 | Fandom |
| **Cream** (`cream`) | 1 × Animal Feed | 1 × Animal Feed | 75 min | Level 23 | Fandom |
| **Corn** (`corn`) | 1 × Minerals + 4 × Seeds | 1 × Minerals + 4 × Seeds | 60 min | Level 24; 1 store star | Fandom |
| **Cheese** (`cheese`) | 2 × Animal Feed | 2 × Animal Feed | 105 min | Level 26 | Fandom |
| **Beef** (`beef`) | 3 × Animal Feed | 3 × Animal Feed | 120 min | Level 27 | Fandom |
| **Fruit & Berries** (`fruit_berries`) | 2 × Seeds + 1 × Tree Saplings | 4 × Seeds + 1 × Metal + 1 × Wood + 1 × Plastic | 90 min | Level 18 | HubsInfo;Fandom |

### Donut Shop

| Product | Direct recipe | Full raw-material requirement | Base time | Unlock / gate | Evidence |
|---|---|---|---:|---|---|
| **Bread Roll** (`bread_roll`) | 2 × Flour Bag + 1 × Cream | 4 × Seeds + 4 × Textiles + 1 × Animal Feed | 60 min | Level 24 | Fandom |
| **Donuts** (`donuts`) | 1 × Sugar and Spices + 1 × Flour Bag | 1 × Sugar and Spices + 2 × Seeds + 2 × Textiles | 45 min | Level 18 | HubsInfo |
| **Green Smoothie** (`green_smoothie`) | 1 × Vegetables + 1 × Fruit & Berries | 6 × Seeds + 1 × Metal + 1 × Wood + 1 × Plastic | 30 min | Level 20 | HubsInfo |
| **Cherry Cheesecake** (`cherry_cheesecake`) | 1 × Flour Bag + 1 × Fruit & Berries + 1 × Cheese | 6 × Seeds + 2 × Textiles + 1 × Metal + 1 × Wood + 1 × Plastic + 2 × Animal Feed | 90 min | Level 27 | HubsInfo |
| **Frozen Yogurt** (`frozen_yogurt`) | 1 × Sugar and Spices + 1 × Fruit & Berries + 1 × Cream | 1 × Sugar and Spices + 4 × Seeds + 1 × Metal + 1 × Wood + 1 × Plastic + 1 × Animal Feed | 240 min | Level 28 | HubsInfo |
| **Coffee** (`coffee`) | 2 × Seeds + 1 × Sugar and Spices + 1 × Cream | 2 × Seeds + 1 × Sugar and Spices + 1 × Animal Feed | 60 min | Level 33; 1 store star | HubsInfo;Fandom |

### Home Appliances Store

| Product | Direct recipe | Full raw-material requirement | Base time | Unlock / gate | Evidence |
|---|---|---|---:|---|---|
| **BBQ Grill** (`bbq_grill`) | 3 × Metal + 1 × Cooking Utensils | 5 × Metal + 2 × Wood + 2 × Plastic | 165 min | Level 29 | Fandom |
| **Microwave Oven** (`microwave_oven`) | 4 × Metal + 1 × Glass + 1 × Electrical Components | 4 × Metal + 1 × Glass + 1 × Electrical Components | 120 min | Level 42; 1 store star | Fandom |
| **Refrigerator** (`refrigerator`) | 2 × Plastic + 2 × Chemicals + 2 × Electrical Components | 2 × Plastic + 2 × Chemicals + 2 × Electrical Components | 210 min | Level 35 | HubsInfo |
| **Lighting System** (`lighting_system`) | 1 × Chemicals + 1 × Glass + 1 × Electrical Components | 1 × Chemicals + 1 × Glass + 1 × Electrical Components | 105 min | Level 36 | HubsInfo |
| **TV** (`tv`) | 2 × Plastic + 2 × Glass + 2 × Electrical Components | 2 × Plastic + 2 × Glass + 2 × Electrical Components | 150 min | Level 38 | HubsInfo |

### Fast Food Restaurant

| Product | Direct recipe | Full raw-material requirement | Base time | Unlock / gate | Evidence |
|---|---|---|---:|---|---|
| **Pizza** (`pizza`) | 1 × Flour Bag + 1 × Cheese + 1 × Beef | 2 × Seeds + 2 × Textiles + 5 × Animal Feed | 24 min | Level 28 | Fandom |
| **Cheese Fries** (`cheese_fries`) | 1 × Cheese + 1 × Vegetables | 2 × Animal Feed + 2 × Seeds | 20 min | Level 33 | Fandom |
| **Ice Cream Sandwich** (`ice_cream_sandwich`) | 1 × Cream + 1 × Bread Roll | 2 × Animal Feed + 4 × Seeds + 4 × Textiles | 14 min | Level 25 | Fandom |
| **Burger** (`burger`) | 1 × Beef + 1 × Bread Roll + 1 × BBQ Grill | 4 × Animal Feed + 4 × Seeds + 4 × Textiles + 5 × Metal + 2 × Wood + 2 × Plastic | 35 min | Level 31 | Fandom |
| **Lemonade Bottle** (`lemonade_bottle`) | 2 × Glass + 2 × Sugar and Spices + 1 × Fruit & Berries | 2 × Glass + 2 × Sugar and Spices + 4 × Seeds + 1 × Metal + 1 × Wood + 1 × Plastic | 60 min | Level 37 | Fandom |
| **Popcorn** (`popcorn`) | 2 × Corn + 1 × Microwave Oven | 2 × Minerals + 8 × Seeds + 4 × Metal + 1 × Glass + 1 × Electrical Components | 30 min | Level 43; 1 store star | Fandom |

### Gardening Supplies

| Product | Direct recipe | Full raw-material requirement | Base time | Unlock / gate | Evidence |
|---|---|---|---:|---|---|
| **Grass** (`grass`) | 1 × Seeds + 1 × Shovel | 1 × Seeds + 1 × Metal + 1 × Wood + 1 × Plastic | 30 min | Level 14 | HubsInfo |
| **Tree Saplings** (`tree_sapling`) | 2 × Seeds + 1 × Shovel | 2 × Seeds + 1 × Metal + 1 × Wood + 1 × Plastic | 90 min | Level 16 | HubsInfo |
| **Lawn Mower** (`lawn_mower`) | 3 × Metal + 1 × Electrical Components + 1 × Paint | 5 × Metal + 1 × Electrical Components + 1 × Minerals + 2 × Chemicals | 120 min | Level 30; 1 store star | Fandom |
| **Garden Furniture** (`garden_furniture`) | 2 × Plastic + 2 × Textiles + 2 × Planks | 2 × Plastic + 2 × Textiles + 4 × Wood | 135 min | Level 21 | HubsInfo |
| **Fire Pit** (`fire_pit`) | 2 × Bricks + 2 × Cement + 1 × Shovel | 8 × Minerals + 2 × Chemicals + 1 × Metal + 1 × Wood + 1 × Plastic | 240 min | Level 28 | HubsInfo |
| **Garden Gnomes** (`garden_gnome`) | 2 × Cement + 1 × Glue | 4 × Minerals + 4 × Chemicals + 1 × Plastic | 90 min | Level 34 | HubsInfo |

### Fashion Store

| Product | Direct recipe | Full raw-material requirement | Base time | Unlock / gate | Evidence |
|---|---|---|---:|---|---|
| **Cap** (`cap`) | 2 × Textiles + 1 × Measuring Tape | 2 × Textiles + 1 × Metal + 1 × Plastic | 60 min | Level 19 | HubsInfo |
| **Shoes** (`shoes`) | 1 × Plastic + 2 × Textiles + 1 × Glue | 2 × Plastic + 2 × Textiles + 2 × Chemicals | 75 min | Level 21 | HubsInfo |
| **Watch** (`watch`) | 2 × Plastic + 1 × Glass + 1 × Chemicals | 2 × Plastic + 1 × Glass + 1 × Chemicals | 90 min | Level 22 | HubsInfo |
| **Business Suits** (`business_suit`) | 3 × Textiles + 1 × Glue + 1 × Measuring Tape | 3 × Textiles + 2 × Plastic + 2 × Chemicals + 1 × Metal | 210 min | Level 32 | HubsInfo |
| **Backpack** (`backpack`) | 2 × Textiles + 2 × Plastic + 1 × Measuring Tape | 2 × Textiles + 3 × Plastic + 1 × Metal | 120 min | Level 34 | Fandom |

### Sports Shop

| Product | Direct recipe | Full raw-material requirement | Base time | Unlock / gate | Evidence |
|---|---|---|---:|---|---|
| **Ping-Pong Table** (`ping_pong_table`) | 1 × Table + 4 × Minerals + 4 × Wood | 7 × Wood + 5 × Metal + 4 × Minerals | 90 min | Level 55; 1 store star | Fandom;Japanese |
| **Tennis Racket** (`tennis_racket`) | 4 × Minerals + 2 × Hammer | 4 × Minerals + 2 × Metal + 2 × Wood | 45 min | Level 35 | Fandom 2024 |
| **Sports Drink** (`sports_drink`) | 2 × Fruit & Berries + 4 × Sugar and Spices | 8 × Seeds + 2 × Metal + 2 × Wood + 2 × Plastic + 4 × Sugar and Spices | 35 min | Level 39 | Fandom 2024 |
| **Protein Bar** (`protein_bar`) | 1 × Cherry Cheesecake + 2 × Sugar and Spices | 6 × Seeds + 2 × Textiles + 1 × Metal + 1 × Wood + 1 × Plastic + 2 × Animal Feed + 2 × Sugar and Spices | 45 min | Level 35 | Fandom 2024 |
| **Football Shoes** (`soccer_shoes`) | 1 × Shoes + 3 × Chemicals | 2 × Plastic + 2 × Textiles + 5 × Chemicals | 35 min | Level unverified | Fandom 2024; unlock level unresolved |

### Toy Store

| Product | Direct recipe | Full raw-material requirement | Base time | Unlock / gate | Evidence |
|---|---|---|---:|---|---|
| **Letter Blocks** (`block_letters`) | 4 × Wood + 1 × Measuring Tape | 4 × Wood + 1 × Metal + 1 × Plastic | 60 min | Level 40 | Fandom;Japanese |
| **Game Console** (`game_console`) | 1 × Lighting System + 3 × Glass + 3 × Electrical Components | 1 × Chemicals + 4 × Glass + 4 × Electrical Components | 75 min | Level 58; 1 store star | Fandom;Japanese |
| **Kite** (`kite`) | 2 × Home Textiles + 2 × Planks + 2 × Paint | 4 × Textiles + 6 × Metal + 2 × Plastic + 4 × Wood + 2 × Minerals + 4 × Chemicals | 75 min | Level unverified | Fandom 2024; unlock level unresolved |
| **Teddy Bear** (`teddy_bear`) | 4 × Home Textiles + 2 × Plastic | 8 × Textiles + 4 × Metal + 6 × Plastic | 60 min | Level unverified | Fandom 2024; unlock level unresolved |

### Bureau of Restoration

| Product | Direct recipe | Full raw-material requirement | Base time | Unlock / gate | Evidence |
|---|---|---|---:|---|---|
| **Wrought Iron** (`forged_iron`) | 4 × Metal + 2 × Hammer + 2 × Chemicals | 6 × Metal + 2 × Wood + 2 × Chemicals | 30 min | Level 45 | Fandom;Japanese |
| **Carved Wood** (`carved_wood`) | 5 × Planks + 2 × Measuring Tape + 2 × Drill | 10 × Wood + 6 × Metal + 6 × Plastic + 2 × Electrical Components | 60 min | Level 54 | Fandom;Japanese |
| **Chiseled Stone** (`cut_stone`) | 2 × Hammer + 6 × Minerals + 2 × Drill | 6 × Metal + 2 × Wood + 6 × Minerals + 4 × Plastic + 2 × Electrical Components | 150 min | Level 59 | Fandom 2024 |
| **Stained Glass** (`stained_glass`) | 5 × Metal + 6 × Glass + 2 × Glue | 5 × Metal + 6 × Glass + 2 × Plastic + 4 × Chemicals | 240 min | Level 76; 1 store star | Fandom 2024 |

### Farmer's Store

| Product | Direct recipe | Full raw-material requirement | Base time | Unlock / gate | Evidence |
|---|---|---|---:|---|---|
| **Wool Shirt** (`wool_shirt`) | 4 × Textiles + 2 × Measuring Tape + 2 × Paint | 4 × Textiles + 6 × Metal + 2 × Plastic + 2 × Minerals + 4 × Chemicals | 75 min | Level 50 | Fandom;Japanese |
| **Picnic Basket** (`picnic_basket`) | 4 × Fruit & Berries + 4 × Textiles + 2 × Glue | 16 × Seeds + 4 × Metal + 4 × Wood + 6 × Plastic + 4 × Textiles + 4 × Chemicals | 60 min | Level 59 | Fandom;Japanese |
| **Apple Jam** (`apple_jam`) | 4 × Seeds + 2 × Glass + 4 × Flour Bag | 12 × Seeds + 2 × Glass + 8 × Textiles | 60 min | Level 73; 1 store star | Fandom;Japanese |

### Dessert Shop

| Product | Direct recipe | Full raw-material requirement | Base time | Unlock / gate | Evidence |
|---|---|---|---:|---|---|
| **Tiramisu** (`tiramisu`) | 1 × Sugar and Spices + 1 × Vegetables + 1 × Cream | 1 × Sugar and Spices + 2 × Seeds + 1 × Animal Feed | 45 min | Level 55 | Fandom;Japanese |
| **Churros** (`churros`) | 1 × Cooking Utensils + 2 × Flour Bag | 2 × Metal + 2 × Wood + 2 × Plastic + 4 × Seeds + 4 × Textiles | 35 min | Level 63 | Fandom;Japanese |
| **Profiterole** (`profiterole`) | 2 × Donuts + 2 × Bread Roll + 1 × Cream | 2 × Sugar and Spices + 12 × Seeds + 12 × Textiles + 3 × Animal Feed | 35 min | Level 71 | Fandom;Japanese |
| **Mochi** (`mochi`) | 1 × Frozen Yogurt + 1 × Green Smoothie | 1 × Sugar and Spices + 10 × Seeds + 2 × Metal + 2 × Wood + 2 × Plastic + 1 × Animal Feed | 45 min | Level 79 | Fandom;Japanese |
| **Pavlova** (`pavlova`) | 1 × Cooking Utensils + 2 × Fruit & Berries + 2 × Cream | 4 × Metal + 4 × Wood + 4 × Plastic + 8 × Seeds + 2 × Animal Feed | 90 min | Level 87; 1 store star | Fandom;Japanese |

## 5. Worked dependency examples

### Nails

`1 Nails ← 2 Metal`

- Direct ingredients: 2 Metal.
- Full raw requirement: 2 Metal.
- Metal is factory-produced; Nails is crafted at the Building Supplies Store.
- No extra iron/steel/rebar is implied by the name. The game's material is named Metal.

### Chair

`1 Chair ← 2 Wood + 1 Nails + 1 Hammer`

Expand the intermediate items:

- 1 Nails ← 2 Metal.
- 1 Hammer ← 1 Metal + 1 Wood.

Therefore 1 Chair requires **3 Metal + 3 Wood** in total, and the intermediate Nails and Hammer must be produced before the Chair can be crafted (unless obtained through an explicitly supported trade/import path).

### Burger

The Burger chain includes the Bread Roll, Beef and BBQ Grill branches. Each branch must be expanded to its own ingredients; the BBQ Grill branch may itself depend on Cooking Utensils. The UI must show all branches and sum repeated raw ingredients, while respecting separate store queues and unlocks.

## 6. Dependency integrity audit

- Parsed current source definitions: **16 raw materials** and **73 crafted recipes**.
- Missing ingredient identifiers: **0**.
- Dependency cycles: **0** (depth-first traversal of every recipe).
- Crafted recipes with at least one crafted-product dependency: **51**.
- Leaf/final crafted products (not used as an ingredient by another recipe): **43**. A leaf is not an error; it is a valid final output candidate for residential orders, trade or events.
- All 73 crafted recipes have non-empty positive-quantity ingredient lists in the current catalog.

Leaf products: `ladder`, `chair`, `cupboard`, `couch`, `pizza`, `cheese_fries`, `ice_cream_sandwich`, `burger`, `lemonade_bottle`, `popcorn`, `grass`, `lawn_mower`, `garden_furniture`, `fire_pit`, `garden_gnome`, `coffee`, `cap`, `watch`, `business_suit`, `refrigerator`, `tv`, `ping_pong_table`, `block_letters`, `game_console`, `forged_iron`, `carved_wood`, `wool_shirt`, `picnic_basket`, `apple_jam`, `tiramisu`, `churros`, `profiterole`, `mochi`, `pavlova`, `backpack`, `tennis_racket`, `sports_drink`, `protein_bar`, `cut_stone`, `stained_glass`, `soccer_shoes`, `kite`, `teddy_bear`.

## 7. Player-facing product panel — required information architecture

When the player taps a factory or store product:

1. **Product identity:** clear icon, product name, producing building, output quantity and unlock status.
2. **Direct recipe panel:** every ingredient with icon, name, required quantity, stored quantity, reserved quantity and missing quantity.
3. **Dependency explorer:** expandable nested rows for crafted ingredients. Each nested row identifies its own producer, recipe, duration and gate. Include a “Full chain” summary with aggregated raw materials.
4. **Production readiness:** Ready / Missing materials / Locked / Recipe unavailable / Storage full / Queue full. Each state includes the exact reason.
5. **Production plan:** show what can start now, what must be produced upstream, which producer is needed, its queue/slots, and estimated completion. Do not promise a completion estimate if a producer/slot schedule is unknown.
6. **Queue and order status:** queued, producing, ready to collect, blocked by storage, collected. Show when inputs are deducted.
7. **No misleading buttons:** disable Start when any prerequisite is missing or locked; show the missing amount next to the exact ingredient. Never let the button fail with only a generic error.
8. **Accessible detail:** product names and quantities must remain readable on mobile landscape; tap targets must not depend on hover.

## 8. Player experience and planning improvements

These are design requirements derived from official mechanics and player-reported production planning patterns; they are not claims that every feature already exists in Mshin.

- **Pre-production planner:** let players prepare common intermediates before accepting an upgrade/order, with a warning before collecting or consuming an item reserved for a different goal.
- **Storage-aware planning:** show the total storage footprint of the shopping list and suggest producing in batches only when capacity permits.
- **Bottleneck highlighting:** identify slow/rare inputs (for example Chemicals and Textiles in player discussions) so the player can start those factory jobs early.
- **Trade/import alternative:** if Mshin implements a Trade Depot/market, mark which items can be bought, their price/source and availability. Never assume market stock exists.
- **Parallel vs sequential scheduling:** factory slots may run concurrently; each commercial building's queue follows its own slot/queue rules. A plan should schedule upstream work first and avoid assuming all stores share one queue.
- **Offline continuity:** dependency planning must use persisted finish timestamps; on resume, completed upstream items must not be duplicated or lost.
- **Avoid storage hoarding:** suggest just-in-time production where useful, while allowing player-controlled stockpiles for long-lead items.
- **Explain speed modifiers:** base time, store-star reductions and any speed-up item must be separately visible so actual time is auditable.
- **Player control:** planner recommendations are advisory. Never automatically consume, sell, or queue materials without a deliberate player action.

## 9. Data validation and test gates before any recipe ships

A recipe catalogue validator must fail CI if:
- a crafted recipe has no ingredients, zero/negative/fractional quantities, duplicate ingredient keys or unknown item IDs;
- a recipe references itself directly or creates a dependency cycle;
- a crafted ingredient has no producer/store/source mapping;
- a required ingredient unlock is later than the output unlock with no explicit alternate gate;
- a product is marked craftable while its recipe or producer is unavailable;
- a final product is unclassified (no consumer category such as residential/trade/event/storage);
- the recursive raw requirement calculation differs from a known expected fixture;
- the UI's displayed required/current/reserved/missing quantities do not reconcile;
- the start-order transaction partially deducts ingredients or permits overspending across simultaneous queues;
- the full dependency tree is clipped or inaccessible on mobile landscape.

Required regression fixtures:
- Nails: 2 Metal.
- Chair: 2 Wood + 1 Nails + 1 Hammer → expanded 3 Metal + 3 Wood.
- Any multi-branch recipe with a shared raw material: verify aggregated quantities.
- Any locked/unverified/disputed recipe: verify visible blocked status and no production start.
- Storage full / partial stock / concurrent order reservation / offline completion cases.

## 10. Evidence and source hierarchy

### Official EA mechanics
- EA Beginner Guide — factories, commercial buildings, residential building plans and City Storage: https://help.ea.com/en/articles/simcity/simcity-buildit/beginner-guide/

### Community recipe and producer references (secondary)
- SimCity BuildIt Wiki — Crafting Recipes: https://simcity-buildit.fandom.com/wiki/Crafting_Recipes
- SimCity BuildIt Wiki — Commercial Buildings (queues, slots, offline production and store upgrades): https://simcity-buildit.fandom.com/wiki/Commercial_Buildings
- SimCity BuildIt community-maintained item database: https://simcitymanager.com/guides/production-chains
- Community optimization tool and dependency/scheduling model: https://github.com/daidodo/simcity-buildit
- EA Forums — player production planning, storage and bottlenecks: https://forums.ea.com/discussions/simcity-buildit-en/being-competetive-in-mayors-league-without-spending-real-money/10357365
- EA Forums — storage and store-slot planning: https://forums.ea.com/discussions/simcity-buildit-en/strategy-for-managing-storage/10429227

### Interpretation limits
- Official EA documentation validates the mechanics, not the full numeric recipe table.
- Community sources are useful but may be outdated, incomplete or inconsistent.
- Regional and special-event items need their own provenance and gate model.
- Before changing any disputed recipe, compare at least two independent references or verify it in a current game build and record the evidence.

## 11. Next implementation boundary

This document is a dependency-system specification and generated reference snapshot. It does **not** silently change live recipe values. The next implementation slice should build automated graph validation and expose the recursive dependency explorer in the existing production panel, using the same canonical catalog.
