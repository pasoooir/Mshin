# SimCity BuildIt — Item & Recipe Reference for Mshin

**Snapshot:** 2026-11-14  
**Purpose:** source-traceable catalogue of raw materials, commercial products, direct ingredients, production durations, unlock gates and unresolved recipe questions.  
**Canonical Mshin data inspected:** `godot-city-buildit/scripts/autoload/ProductionManager.gd` on `main`.  
**Important:** this document records the current Mshin catalog and its recorded provenance. It does not assert that every value has been independently confirmed against a current live EA game build.

## 1. Evidence rules

1. **EA official guide** confirms the gameplay flow: factories make raw materials; commercial buildings combine materials into crafted items; players collect finished goods into City Storage; residential contractor plans show required items. EA's guide does not publish a complete numerical recipe database.
2. **Community databases** (Fandom/SimCity BuildIt Wiki, SimCityManager, HubsInfo and the Japanese reference noted in code provenance) supply detailed recipe, time and unlock data. These are secondary sources and can disagree or become stale.
3. **Mshin code** is the authoritative statement of what this build currently uses. It is not, by itself, proof of exact EA parity.
4. When sources disagree or an unlock gate is unknown, keep the item visibly marked as disputed/unverified and do not silently guess.

Official EA overview: https://help.ea.com/en/articles/simcity/simcity-buildit/beginner-guide/  
EA explains factories and commercial crafting at the building section, and City Storage at the inventory section.

## 2. How to read a recipe

- Quantities are **per one output item**.
- `Metal` means the game's raw material named **Metal**. Do not rename it to "rebar/steel bar" or imply a specific construction product unless the game itself does so.
- An ingredient may itself be a crafted product. Follow its own recipe recursively to calculate the complete raw-material shopping list.
- Production times below are base durations in seconds converted to minutes; shop-star speed reductions are not applied here.
- `Level` is the unlock level currently recorded in Mshin's recipe data and is secondary-reference provenance unless specifically confirmed by EA.
- `★` means the current Mshin record requires at least that store-star level.
- Items with unknown unlock levels or conflicting ingredients must not be treated as verified/craftable.

## 3. Raw materials made directly by factories

| ID | Material | Base factory time | Recorded unlock | Provenance |
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
| `coconut` | Coconut | 120 min | Regional Mshin | Mshin Regional |
| `snowberry` | Snowberry | 180 min | Regional Mshin | Mshin Regional |
| `cactus_fruit` | Cactus Fruit | 240 min | Regional Mshin | Mshin Regional |
| `herbs` | Herbs | 300 min | Regional Mshin | Mshin Regional |
| `olives` | Olives | 360 min | Regional Mshin | Mshin Regional |

The 11 standard capital-city materials are community-reference SCBI entries. The five entries labelled **Mshin Regional** are Mshin-specific placeholders/region materials, not a claim that these are the exact SCBI regional recipes.

## 4. Commercial recipes — direct inputs

### Building Supplies Store

| Product ID | Product | Required materials for 1 output | Base time | Unlock | Additional gate | Recorded provenance |
|---|---|---|---:|---:|---|---|
| `nails` | Nails | 2 × Metal | 5 min | 1 | — | Fandom |
| `planks` | Planks | 2 × Wood | 30 min | 3 | — | Fandom |
| `bricks` | Bricks | 2 × Minerals | 20 min | 13 | — | Fandom |
| `cement` | Cement | 2 × Minerals + 1 × Chemicals | 50 min | 14 | — | Fandom |
| `glue` | Glue | 1 × Plastic + 2 × Chemicals | 60 min | 15 | — | Fandom |
| `paint` | Paint | 2 × Metal + 1 × Minerals + 2 × Chemicals | 60 min | 16 | 1 store star | Fandom |

### Hardware Store

| Product ID | Product | Required materials for 1 output | Base time | Unlock | Additional gate | Recorded provenance |
|---|---|---|---:|---:|---|---|
| `hammer` | Hammer | 1 × Metal + 1 × Wood | 14 min | 4 | — | Fandom |
| `measuring_tape` | Measuring Tape | 1 × Metal + 1 × Plastic | 20 min | 6 | — | Fandom |
| `shovel` | Shovel | 1 × Metal + 1 × Wood + 1 × Plastic | 30 min | 9 | — | Fandom |
| `cooking_utensils` | Cooking Utensils | 2 × Metal + 2 × Wood + 2 × Plastic | 45 min | 17 | — | Fandom |
| `ladder` | Ladder | 2 × Planks + 2 × Metal | 60 min | 20 | 1 store star | Fandom |
| `drill` | Drill | 2 × Metal + 2 × Plastic + 1 × Electrical Components | 120 min | 30 | — | Fandom |

### Furniture Store

| Product ID | Product | Required materials for 1 output | Base time | Unlock | Additional gate | Recorded provenance |
|---|---|---|---:|---:|---|---|
| `chair` | Chair | 2 × Wood + 1 × Nails + 1 × Hammer | 20 min | 10 | — | Fandom |
| `home_textiles` | Home Textiles | 2 × Textiles + 1 × Measuring Tape | 75 min | 25 | — | Fandom |
| `cupboard` | Cupboard | 2 × Planks + 2 × Glass + 1 × Paint | 45 min | 26 | 1 store star | Fandom |
| `couch` | Couch | 3 × Textiles + 1 × Drill + 1 × Glue | 150 min | 33 | — | Fandom |
| `table` | Table | 1 × Planks + 2 × Nails + 1 × Hammer | 30 min | 16 | — | Fandom |

### Farmer's Market

| Product ID | Product | Required materials for 1 output | Base time | Unlock | Additional gate | Recorded provenance |
|---|---|---|---:|---:|---|---|
| `vegetables` | Vegetables | 2 × Seeds | 20 min | 8 | — | Fandom |
| `flour_bag` | Flour Bag | 2 × Seeds + 2 × Textiles | 30 min | 17 | — | Fandom |
| `cream` | Cream | 1 × Animal Feed | 75 min | 23 | — | Fandom |
| `corn` | Corn | 1 × Minerals + 4 × Seeds | 60 min | 24 | 1 store star | Fandom |
| `cheese` | Cheese | 2 × Animal Feed | 105 min | 26 | — | Fandom |
| `beef` | Beef | 3 × Animal Feed | 120 min | 27 | — | Fandom |
| `fruit_berries` | Fruit & Berries | 2 × Seeds + 1 × Tree Saplings | 90 min | 18 | — | HubsInfo;Fandom |

### Donut Shop

| Product ID | Product | Required materials for 1 output | Base time | Unlock | Additional gate | Recorded provenance |
|---|---|---|---:|---:|---|---|
| `bread_roll` | Bread Roll | 2 × Flour Bag + 1 × Cream | 60 min | 24 | — | Fandom |
| `donuts` | Donuts | 1 × Sugar and Spices + 1 × Flour Bag | 45 min | 18 | — | HubsInfo |
| `green_smoothie` | Green Smoothie | 1 × Vegetables + 1 × Fruit & Berries | 30 min | 20 | — | HubsInfo |
| `cherry_cheesecake` | Cherry Cheesecake | 1 × Flour Bag + 1 × Fruit & Berries + 1 × Cheese | 90 min | 27 | — | HubsInfo |
| `frozen_yogurt` | Frozen Yogurt | 1 × Sugar and Spices + 1 × Fruit & Berries + 1 × Cream | 240 min | 28 | — | HubsInfo |
| `coffee` | Coffee | 2 × Seeds + 1 × Sugar and Spices + 1 × Cream | 60 min | 33 | 1 store star | HubsInfo;Fandom |

### Home Appliances Store

| Product ID | Product | Required materials for 1 output | Base time | Unlock | Additional gate | Recorded provenance |
|---|---|---|---:|---:|---|---|
| `bbq_grill` | BBQ Grill | 3 × Metal + 1 × Cooking Utensils | 165 min | 29 | — | Fandom |
| `microwave_oven` | Microwave Oven | 4 × Metal + 1 × Glass + 1 × Electrical Components | 120 min | 42 | 1 store star | Fandom |
| `refrigerator` | Refrigerator | 2 × Plastic + 2 × Chemicals + 2 × Electrical Components | 210 min | 35 | — | HubsInfo |
| `lighting_system` | Lighting System | 1 × Chemicals + 1 × Glass + 1 × Electrical Components | 105 min | 36 | — | HubsInfo |
| `tv` | TV | 2 × Plastic + 2 × Glass + 2 × Electrical Components | 150 min | 38 | — | HubsInfo |

### Fast Food Restaurant

| Product ID | Product | Required materials for 1 output | Base time | Unlock | Additional gate | Recorded provenance |
|---|---|---|---:|---:|---|---|
| `pizza` | Pizza | 1 × Flour Bag + 1 × Cheese + 1 × Beef | 24 min | 28 | — | Fandom |
| `cheese_fries` | Cheese Fries | 1 × Cheese + 1 × Vegetables | 20 min | 33 | — | Fandom |
| `ice_cream_sandwich` | Ice Cream Sandwich | 1 × Cream + 1 × Bread Roll | 14 min | 25 | — | Fandom |
| `burger` | Burger | 1 × Beef + 1 × Bread Roll + 1 × BBQ Grill | 35 min | 31 | — | Fandom |
| `lemonade_bottle` | Lemonade Bottle | 2 × Glass + 2 × Sugar and Spices + 1 × Fruit & Berries | 60 min | 37 | — | Fandom |
| `popcorn` | Popcorn | 2 × Corn + 1 × Microwave Oven | 30 min | 43 | 1 store star | Fandom |

### Gardening Supplies

| Product ID | Product | Required materials for 1 output | Base time | Unlock | Additional gate | Recorded provenance |
|---|---|---|---:|---:|---|---|
| `grass` | Grass | 1 × Seeds + 1 × Shovel | 30 min | 14 | — | HubsInfo |
| `tree_sapling` | Tree Saplings | 2 × Seeds + 1 × Shovel | 90 min | 16 | — | HubsInfo |
| `lawn_mower` | Lawn Mower | 3 × Metal + 1 × Electrical Components + 1 × Paint | 120 min | 30 | 1 store star | Fandom |
| `garden_furniture` | Garden Furniture | 2 × Plastic + 2 × Textiles + 2 × Planks | 135 min | 21 | — | HubsInfo |
| `fire_pit` | Fire Pit | 2 × Bricks + 2 × Cement + 1 × Shovel | 240 min | 28 | — | HubsInfo |
| `garden_gnome` | Garden Gnomes | 2 × Cement + 1 × Glue | 90 min | 34 | — | HubsInfo |

### Fashion Store

| Product ID | Product | Required materials for 1 output | Base time | Unlock | Additional gate | Recorded provenance |
|---|---|---|---:|---:|---|---|
| `cap` | Cap | 2 × Textiles + 1 × Measuring Tape | 60 min | 19 | — | HubsInfo |
| `shoes` | Shoes | 1 × Plastic + 2 × Textiles + 1 × Glue | 75 min | 21 | — | HubsInfo |
| `watch` | Watch | 2 × Plastic + 1 × Glass + 1 × Chemicals | 90 min | 22 | — | HubsInfo |
| `business_suit` | Business Suits | 3 × Textiles + 1 × Glue + 1 × Measuring Tape | 210 min | 32 | — | HubsInfo |
| `backpack` | Backpack | 2 × Textiles + 2 × Plastic + 1 × Measuring Tape | 120 min | 34 | — | Fandom |

### Sports Shop

| Product ID | Product | Required materials for 1 output | Base time | Unlock | Additional gate | Recorded provenance |
|---|---|---|---:|---:|---|---|
| `ping_pong_table` | Ping-Pong Table | 1 × Table + 4 × Minerals + 4 × Wood | 90 min | 55 | 1 store star | Fandom;Japanese |
| `tennis_racket` | Tennis Racket | 4 × Minerals + 2 × Hammer | 45 min | 35 | — | Fandom 2024 |
| `sports_drink` | Sports Drink | 2 × Fruit & Berries + 4 × Sugar and Spices | 35 min | 39 | — | Fandom 2024 |
| `protein_bar` | Protein Bar | 1 × Cherry Cheesecake + 2 × Sugar and Spices | 45 min | 35 | — | Fandom 2024 |
| `soccer_shoes` | Football Shoes | 1 × Shoes + 3 × Chemicals | 35 min | Unverified | — | Fandom 2024; unlock level unresolved |

### Toy Store

| Product ID | Product | Required materials for 1 output | Base time | Unlock | Additional gate | Recorded provenance |
|---|---|---|---:|---:|---|---|
| `block_letters` | Letter Blocks | 4 × Wood + 1 × Measuring Tape | 60 min | 40 | — | Fandom;Japanese |
| `game_console` | Game Console | 1 × Lighting System + 3 × Glass + 3 × Electrical Components | 75 min | 58 | 1 store star | Fandom;Japanese |
| `kite` | Kite | 2 × Home Textiles + 2 × Planks + 2 × Paint | 75 min | Unverified | — | Fandom 2024; unlock level unresolved |
| `teddy_bear` | Teddy Bear | 4 × Home Textiles + 2 × Plastic | 60 min | Unverified | — | Fandom 2024; unlock level unresolved |

### Bureau of Restoration

| Product ID | Product | Required materials for 1 output | Base time | Unlock | Additional gate | Recorded provenance |
|---|---|---|---:|---:|---|---|
| `forged_iron` | Wrought Iron | 4 × Metal + 2 × Hammer + 2 × Chemicals | 30 min | 45 | — | Fandom;Japanese |
| `carved_wood` | Carved Wood | 5 × Planks + 2 × Measuring Tape + 2 × Drill | 60 min | 54 | — | Fandom;Japanese |
| `cut_stone` | Chiseled Stone | 2 × Hammer + 6 × Minerals + 2 × Drill | 150 min | 59 | — | Fandom 2024 |
| `stained_glass` | Stained Glass | 5 × Metal + 6 × Glass + 2 × Glue | 240 min | 76 | 1 store star | Fandom 2024 |

### Farmer's Store

| Product ID | Product | Required materials for 1 output | Base time | Unlock | Additional gate | Recorded provenance |
|---|---|---|---:|---:|---|---|
| `wool_shirt` | Wool Shirt | 4 × Textiles + 2 × Measuring Tape + 2 × Paint | 75 min | 50 | — | Fandom;Japanese |
| `picnic_basket` | Picnic Basket | 4 × Fruit & Berries + 4 × Textiles + 2 × Glue | 60 min | 59 | — | Fandom;Japanese |
| `apple_jam` | Apple Jam | 4 × Seeds + 2 × Glass + 4 × Flour Bag | 60 min | 73 | 1 store star | Fandom;Japanese |

### Dessert Shop

| Product ID | Product | Required materials for 1 output | Base time | Unlock | Additional gate | Recorded provenance |
|---|---|---|---:|---:|---|---|
| `tiramisu` | Tiramisu | 1 × Sugar and Spices + 1 × Vegetables + 1 × Cream | 45 min | 55 | — | Fandom;Japanese |
| `churros` | Churros | 1 × Cooking Utensils + 2 × Flour Bag | 35 min | 63 | — | Fandom;Japanese |
| `profiterole` | Profiterole | 2 × Donuts + 2 × Bread Roll + 1 × Cream | 35 min | 71 | — | Fandom;Japanese |
| `mochi` | Mochi | 1 × Frozen Yogurt + 1 × Green Smoothie | 45 min | 79 | — | Fandom;Japanese |
| `pavlova` | Pavlova | 1 × Cooking Utensils + 2 × Fruit & Berries + 2 × Cream | 90 min | 87 | 1 store star | Fandom;Japanese |

## 5. Worked example — Nails

To produce **1 Nails**:

1. Have **2 Metal** in City Storage.
2. Select **Nails** in the **Building Supplies Store**.
3. The store consumes 2 Metal when the order is accepted.
4. Base production duration in the current catalog: **5 minutes**.
5. Collect 1 Nails from the store; it is then transferred to City Storage.

The Metal is a raw factory material and has no crafting inputs. Its recorded base factory time is 1 minute per Metal, so two Metals require two factory outputs. If two factory slots run in parallel, both can be made concurrently; the 5-minute store timer follows after the inputs are available. The official EA guide confirms the factory → commercial crafting → collect-to-inventory interaction; the exact quantities and times are from community-maintained recipe references.

## 6. Source discrepancies and unresolved data

| Item / topic | Current Mshin record | Discrepancy / limitation | Required handling |
|---|---|---|---|
| Tapestry | Textiles ×3 + Paint ×2 + Glue ×2 **or** Textiles ×4 + Paint ×2 + Glue ×2 | Bureau table and item page disagree; record is in `store_catalog`, not an enabled recipe | Keep disabled until verified |
| Football Shoes | Shoes ×1 + Chemicals ×3; 35 min | Exact Mayor Level unknown | Keep locked; do not infer unlock |
| Kite | Home Textiles ×2 + Planks ×2 + Paint ×2; 75 min | Exact Mayor Level unknown | Keep locked |
| Teddy Bear | Home Textiles ×4 + Plastic ×2; 60 min | Exact Mayor Level unknown | Keep locked |
| Ladder | Current Mshin: Planks ×2 + Metal ×2 | Some third-party summary pages list a different second ingredient; cross-check current in-game source before changing | Preserve current record but flag for verification |
| Flour Bag / Corn / Glue / Paint / Cooking Utensils | Current Mshin follows the Fandom-aligned ingredient rows | Older/alternate community tables have variant ingredient rows | Keep source attribution and recheck before balance changes |
| Residential contractor plans | EA says plans show required items | EA's public guide does not provide one universal fixed material recipe for every residential stage | Do not label Mshin's six-stage plan table as exact SCBI data |

## 7. Catalogue coverage snapshot

- Factory raw materials: **16** total (11 standard SCBI reference entries + 5 Mshin regional entries).
- Commercial recipe definitions in `ProductionManager.gd`: **73**.
- Products grouped under **14** store families.
- Three recipe definitions have known inputs/time/value but unknown exact Mayor Level and remain locked.
- Tapestry is a separate catalog identity with conflicting input candidates and remains disabled.
- These counts describe the current Mshin data, not the complete total number of items in every current SCBI update.

## 8. Source register

### Official
- EA Help — The SimCity BuildIt beginner guide: https://help.ea.com/en/articles/simcity/simcity-buildit/beginner-guide/

### Community-maintained recipe and item references
- Crafting Recipes: https://simcity-buildit.fandom.com/wiki/Crafting_Recipes
- List of items in SimCity BuildIt: https://simcity.fandom.com/wiki/List_of_items_in_SimCity_BuildIt
- Commercial buildings list: https://simcity.fandom.com/wiki/List_of_commercial_buildings_in_SimCity_BuildIt
- Building materials: https://simcity-buildit.fandom.com/wiki/Building_Materials
- SimCityManager — Complete Items Reference: https://simcitymanager.com/guides/items-reference
- Gamelytic — Crafting Recipe List: https://gamelytic.com/simcity-buildit-crafting-recipe-list/

### Existing Mshin audit
- `PRODUCTION_ECONOMY_AND_CITY_NEEDS_SPEC.md`
- `PRODUCTION_DEPENDENCY_AUDIT.md`
- `PRODUCTION_ECONOMY_IMPLEMENTATION_TRACKER.md`

## 9. Rules before implementing or changing recipes

- Never change an ingredient quantity, unlock level, duration, sale value or store-star gate solely to make the game feel more balanced.
- Add source/provenance and a regression test for each verified recipe change.
- If two references conflict, retain both candidates and disable crafting until resolved.
- If a product's direct ingredient is another crafted item, the UI should let the player expand that dependency and show the full upstream chain.
- At order start, validate and consume the entire input set atomically; never partially deduct materials.
- Show each ingredient's required amount, current City Storage amount and missing amount before the player starts production.
- Keep raw factory production separate from commercial recipes: raw materials do not consume other recipe inputs.
