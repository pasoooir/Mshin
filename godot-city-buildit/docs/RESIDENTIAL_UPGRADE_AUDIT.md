# Residential Upgrade Audit — 2026-11-12

## Reference behaviour

- EA beginner guide: tap the hard-hat icon to inspect the building plan, collect the listed materials, then drag the materials onto the building; the plan exposes required items and upgrade rewards. EA also describes the yellow hard-hat indicator for a home ready to upgrade.
  - https://help.ea.com/en/articles/simcity/simcity-buildit/beginner-guide/
- SimCity BuildIt Fandom residential-building guide: the plan shows required items and rewards; plans can be refreshed or the hard hat transferred to another building, with a 30-minute change period; after materials are delivered, scaffolding appears for a few seconds; population does not decrease and new residents are added immediately after completion.
  - https://simcity-buildit.fandom.com/wiki/Residential_Buildings
- Game Developer analysis, “Progression Control in Sim City BuildIt” (17 April 2015): residential requirements are generated across slots; slot count, material type, and quantity vary. It reports up to six requirement slots by level 15 and describes increasingly complex unlocked product pools.
  - https://www.gamedeveloper.com/design/progression-control-in-sim-city-buildit

## Implemented in this branch

- Residential upgrade now consumes the listed materials when accepted and enters a short scaffold phase instead of increasing the level instantly.
- The scaffold phase lasts 4 seconds in Mshin. This is a project timing choice; the Fandom reference only says “a few seconds.”
- Population remains unchanged during the scaffold phase. At completion, population is increased (never reduced), XP and Simoleons are awarded, and the upgraded building visual is rebuilt.
- The upgrade finish timestamp and in-progress state are saved and restored. If the timer elapsed while the game was closed, completion is deferred until after the saved resident count is restored.
- The selected home shows a blue hard-hat marker; closing the plan panel hides it.
- The panel displays required materials, current stock/shortage, rewards, and the current upgrade state.

## Important unresolved differences

- The current six-stage material table, population tiers, XP formula, and Simoleon reward formula are **Mshin fallback values**, not verified SCBI data. The UI now labels the material plan and reward values as unverified. Only the starter Nails + Metal pattern follows the user-provided example; exact quantities, later-stage plans, population progression, and reward ranges still need authoritative in-game captures or a complete reference dataset.
- The 30-minute refresh-plan and hard-hat-transfer actions are not implemented yet. The plan generator/verified alternate-plan pool must exist before refresh can change material requirements without inventing data.
- The blue marker is a deliberate Mshin UI choice; EA's beginner guide describes a yellow ready-to-upgrade hard hat.

## Follow-up UI and production pass — 2026-11-12

### Production UI
- Commercial queue expansion now uses the published SimCash slot price schedule: Building Supplies / Hardware use the lower schedule; other standard commercial stores use the general schedule. No Vu Generator pricing is implemented.
- The queue shows explicit Producing / In Queue / Collect / Storage Full states. A full warehouse disables Collect but the ready item remains in its production slot.
- Store star timing and star purchase UI are enabled only for Building Supplies and Hardware, where the referenced pages provide the level gates and Simoleon costs. Their 10%, 15%, and 20% reductions are applied to new production orders.
- Paint now requires one Building Supplies star, as specified by its item reference.
- Star level is stored in the building's save data. Queue capacity remains persisted through the saved slot array.
- Other stores continue using base production times until their own star progression requirements and costs are verified.

### Residential UI
- The plan panel now has an explicit readiness state: missing materials, all materials ready, maximum level, or temporary construction in progress.
- Shortage rows continue to show owned / required quantities and the missing amount.
- The in-progress label explicitly identifies the four-second construction phase as temporary Mshin behavior; it is not represented as an SCBI duration.

### Sources for the production pass
- Commercial building slot prices, default 2 slots, max 11 slots, and general star reductions: https://simcity-buildit.fandom.com/wiki/Commercial_Buildings
- Building Supplies star level gates, Simoleon costs, product unlock and per-star production times: https://simcity-buildit.fandom.com/wiki/Building_Supplies_Store
- Hardware Store star level gates, costs, and production-time table: https://simcity-buildit.fandom.com/wiki/Hardware_Store
- Paint one-star requirement: https://simcity-buildit.fandom.com/wiki/Paint
- Commercial store catalog / store-wide improvement summaries: https://scbuildit.hubsinfo.net/database/?ISubCateg=Store


## Verified commercial star expansion — 2026-11-12

### Newly enabled stores

The following store-specific tiers now use the referenced Mayor Level gates and Simoleon costs, with the documented 10% / 15% / 20% production reductions:

| Store | Star 1 | Star 2 | Star 3 |
|---|---:|---:|---:|
| Farmer's Market | L20 / 19,000 | L32 / 31,000 | L40 / 39,000 |
| Furniture Store | L22 / 21,000 | L34 / 33,000 | L42 / 41,000 |
| Gardening Supplies | L27 / 25,000 | L38 / 37,000 | L46 / 45,000 |
| Fashion Store | L31 / 30,000 | L43 / 42,000 | L51 / 50,000 |
| Home Appliances | L41 / 40,000 | L53 / 52,000 | L61 / 60,000 |
| Fast Food Restaurant | L37 / 36,000 | L49 / 48,000 | L57 / 56,000 |
| Donut Shop | L30 / 29,000 | L42 / 41,000 | L50 / 49,000 |

The Fast Food Restaurant level gates are cross-checked against HubsInfo's store database; the tier costs and level gates are taken from the Japanese commercial reference. Gardening Supplies level gates use HubsInfo/Japanese references rather than the conflicting lower first-star level on the Fandom page.

### Newly enforced item unlocks

- Coffee requires at least one Donut Shop star.
- Popcorn requires at least one Fast Food Restaurant star.
- Paint requires one Building Supplies star. Ladder, Corn, Cupboard, Lawn Mower, Coffee, Microwave Oven, and Popcorn enforce their respective store's one-star requirement as shown in the item unlock references.

### Queue-price boundary

- The standard commercial queue-price schedule is applied only to known SCBI commercial store IDs.
- Mshin-only custom stores do not inherit the SCBI schedule. Their queue-slot action is shown as unavailable until a real price source exists.
- Vu's Random Generator is not part of the current supported building catalog; its separate published slot-price schedule is not silently treated as a standard-store price.

### Explicit source gaps (not fabricated)

- Donut Shop's third-star cost has one conflicting Fandom entry (45,000), while the Japanese commercial table and SimCity Planning Guide both report 49,000. The implementation uses 49,000 because it is independently corroborated by those two references; this source discrepancy remains noted.
- Speed-Up Tokens are documented by EA as 2x / 4x / 12x for both shops and eligible factories. The current project has no verified token inventory, token-part conversion, or legitimate token-acquisition systems. No free token balance or acquisition path has been invented.
- EA confirms Factory Speed-Ups do not apply to the Ad-powered Factory. No token UI is activated until inventory and acquisition are represented in the game.
- The Japanese factory/commercial tables list item-specific SimCash costs at the full base production duration, while the Fandom industrial/commercial references state that the live SimCash quote varies with remaining time. The exact remaining-time pricing curve is not documented by the sources found, so the static base-duration price is not misused as a live quote and no SimCash speed-up button is shown.
- Residential plan refresh and hard-hat transfer both change the material plan and carry a 30-minute change period in the reference. They remain blocked because this branch deliberately does not introduce a randomized plan generator or an unverified alternate-plan pool.
- Residential material quantities, population tiers, XP and Simoleon rewards remain Mshin fallback data; they are not claimed as canonical SCBI values.

### Additional sources

- Farmer's Market upgrade tiers: https://simcity-buildit.fandom.com/wiki/Farmer%27s_Market
- Furniture Store upgrade tiers: https://simcity-buildit.fandom.com/wiki/Furniture_Store
- Gardening Supplies tiers: https://simcity-buildit.fandom.com/wiki/Gardening_Supplies and https://scbuildit.hubsinfo.net/database/?ISubCateg=Store
- Fashion Store tiers: https://simcity-buildit.fandom.com/wiki/Fashion_Store
- Home Appliances tiers: https://simcity-buildit.fandom.com/wiki/Home_Appliances
- Fast Food Restaurant tiers: https://scbuildit.hubsinfo.net/database/?ISubCateg=Store and https://wikiwiki.jp/simcitybuild/%E5%95%86%E6%A5%AD
- Donut Shop third-star price cross-check: https://simcity-buildit.fandom.com/wiki/Donut_Shop, https://wikiwiki.jp/simcitybuild/%E5%95%86%E6%A5%AD, and https://www.simcityplanningguide.com/2015/08/simcity-buildit-commercial-build-times.html
- Star-gated items and store-level unlocks: https://simcity-buildit.fandom.com/wiki/Level_Up_Table, https://simcity-buildit.fandom.com/wiki/Ladder, https://simcity-buildit.fandom.com/wiki/Corn, https://simcity-buildit.fandom.com/wiki/Cupboard, https://simcity-buildit.fandom.com/wiki/Popcorn, and https://simcity-buildit.fandom.com/wiki/Microwave_Oven
- EA Speed-Up Tokens guide: https://help.ea.com/en/articles/simcity/simcity-buildit/speed-up-tokens/
- Japanese industrial item speed-up prices (full-duration reference only): https://wikiwiki.jp/simcitybuild/%E5%B7%A5%E6%A5%AD
- Japanese commercial item speed-up prices (full-duration reference only): https://wikiwiki.jp/simcitybuild/%E5%95%86%E6%A5%AD
- Variable SimCash speed-up reference: https://simcity.fandom.com/wiki/SimCash


## Later year-round commercial stores — 2026-11-12

### Corrected building unlock data

| Store | Mayor Level | Simoleon cost |
|---|---:|---:|
| Sports Shop | 35 | 80,000 |
| Toy Shop | 40 | 100,000 |
| Bureau of Restoration | 45 | 250,000 |
| Country Store (formerly Farmer's Store) | 50 | 300,000 |
| Dessert Shop | 55 | 350,000 |

These replace incorrect early placeholder levels/costs in the Mshin building catalog.

### Newly enabled sourced recipes

- Sports Shop: Ping-Pong Table (Level 55, 90 minutes, one-star requirement).
- Toy Shop: Letter Blocks (Level 40, 60 minutes); Game Console (Level 58, 75 minutes, one-star requirement).
- Bureau of Restoration: Wrought Iron (Level 45, 30 minutes); Carved Wood (Level 54, 60 minutes).
- Country Store: Wool Shirt (Level 50, 75 minutes); Picnic Basket (Level 59, 60 minutes); Apple Jam (Level 73, 60-minute base, one-star requirement; 54 minutes at one star).
- Dessert Shop: Tiramisu (Level 55, 45 minutes); Churros (Level 63, 35 minutes); Profiterole (Level 71, 35 minutes); Mochi (Level 79, 45 minutes); Pavlova (Level 87, 90-minute base, one-star requirement; 81 minutes at one star).

### Partially verified upgrade tiers

- Sports Shop: Level 55 / 250,000 and Level 60 / 350,000; third-star level is unknown.
- Toy Shop: Level 58 / 280,000; second-star level is unknown.
- Bureau of Restoration: Level 76 / 450,000 and Level 81 / 600,000; third-star level is unknown.
- Country Store: Level 73 / 310,000 and Level 85 / 400,000; third-star level is unknown.
- Dessert Shop: Level 87 / 450,000; second- and third-star levels are unknown.

The panel explicitly displays “NEXT STAR LEVEL UNVERIFIED” once it reaches the last sourced tier. Unknown tiers are not purchasable.

### Still-disabled catalog entries

Sports Shop items whose item unlock levels are absent from the source, Toy Shop Kite and Teddy Bear whose exact unlock levels are absent, and Bureau of Restoration products whose production time is not listed remain visible but disabled. No level, recipe, or timer has been inferred for them.

### Additional sources

- Sports Shop: https://simcity-buildit.fandom.com/wiki/Sports_Shop
- Toy Shop: https://simcity-buildit.fandom.com/wiki/Toy_Shop
- Bureau of Restoration: https://simcity-buildit.fandom.com/wiki/Bureau_of_Restoration
- Country Store: https://simcity-buildit.fandom.com/wiki/Country_Store
- Dessert Shop: https://simcity-buildit.fandom.com/wiki/Dessert_Shop
- Newer-store star tiers and production times: https://wikiwiki.jp/simcitybuild/%E5%95%86%E6%A5%AD
- Product unlock and star requirements: https://simcity-buildit.fandom.com/wiki/Level_Up_Table
