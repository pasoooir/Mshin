# Land expansion and desert livestock

## Land expansion behavior

- The playable land grid is divided into 8×8-cell plots.
- A 6×6 block of plots is owned at the start; the remaining grid is shaded darker and outlined when directly adjacent to owned land.
- Expansion follows the SimCity BuildIt interaction pattern: select a connected adjacent plot, inspect its item requirements, then confirm the claim.
- The three special items are Dozer Wheel, Dozer Blade and Dozer Exhaust. A claim checks all requirements first and removes them atomically from City Storage.
- Mayor Level 10 is required to claim land. Requirement counts vary by plot distance and a deterministic plot variation; this is Mshin balancing, not a claim that EA uses these exact numbers.
- Happy citizen opinion bubbles can award one expansion item from Mayor Level 8. Global Trade market refreshes surface all three expansion item types from Mayor Level 10.
- A claimed plot immediately becomes buildable for buildings and roads. Ownership is stored per region in the existing region snapshot and survives save/load.

## Livestock boundaries

- The existing sheep and cattle MultiMeshes are retained; they are no longer static.
- Animals wander within two sandy pasture strips at the far north and south map edges.
- Every movement step validates pasture bounds, asphalt exclusion, unlocked land exclusion and nearby road cells. Invalid steps are rejected and the animal turns back.
- Sheep and cattle parts are moved as linked MultiMesh instances, avoiding one scene node per body part/animal.

## Reference

The interaction model is based on EA's official SimCity BuildIt beginner guide: expansion plots must connect to current city limits, each plot displays its required bulldozer special items, and the player confirms after collecting them.

https://help.ea.com/en/articles/simcity/simcity-buildit/beginner-guide/

The special-item set (Dozer Wheel, Dozer Blade, Dozer Exhaust) follows the established SimCity BuildIt land-expansion mechanic. Plot size, initial ownership, level gate and exact Mshin item counts are implementation choices for this project.


## Backward-compatible saves

- Save version 3 predates land ownership. During load, every plot containing an already-saved road or building footprint is migrated to owned land before restoration. This prevents existing cities from losing placed objects or failing to load.
- New version 4 saves store the complete owned-plot set per region.


Expansion items are special inventory goods, not factory raw materials. They are collectible from eligible happy-citizen bubbles and tradeable through the existing Global Trade system; factories do not manufacture them.


## Map geography guard

- Expansion plots are generated only in the connected north/south land corridor. The western motorway asphalt reserve and eastern ocean/coastline tiles are excluded from purchase, so no expansion offer places buildable land over the highway or sea.


The camera pan boundary now reaches the map edge (90 world units), so players can actually view the newly expanded plots and both desert grazing strips.


The visible build grid is generated from owned plots rather than a fixed starter rectangle. When a plot is purchased, its build grid appears immediately; locked plots remain shaded and do not receive build-grid lines.


## City expansion equipment presentation

The land-expansion economy uses the three SimCity BuildIt-style bulldozer Special Items:
- `dozer_wheel` — Dozer Wheel
- `dozer_blade` — Dozer Blade
- `dozer_exhaust` — Dozer Exhaust

Mshin ships original, locally bundled transparent PNG artwork for these three items in `assets/icons/special/`. The images are authored for this project and are not copied from EA artwork. They are imported as local Godot resources so the Web build does not depend on a runtime CDN request or network availability.

The expansion plot picker shows all three quantities on every adjacent available plot. Selecting a plot shows each required quantity beside the player's current City Storage quantity. The SimCash shop uses the same icon catalog, and purchases still add the real Special Item to City Storage; they never bypass the normal expansion transaction.

The existing progression contract remains authoritative: Mayor Level 10, adjacency to owned land, the curved-coast/highway exclusions, each plot's own item requirements, atomic item consumption, ownership update, and save/load persistence.


## Complete visible plot-ownership layer

- The expansion preview now shades every valid inland parcel, not only the next purchasable ring.
- Owned parcels use a restrained green overlay, adjacent purchasable parcels use a high-contrast gold fill/border, and non-adjacent future parcels remain visibly locked with a muted dark overlay.
- All parcel overlays and borders are batched into two mesh surfaces; no per-plot scene nodes are created. The permanent highway corridor and coastal reserve remain excluded.
- Each parcel represents 8×8 cells at 2 m per cell (256 m²). The panel shows coordinates and expansion ring, and the selected plot shows its area and live Dozer Wheel/Blade/Exhaust stock-versus-cost.
- Equipment requirements remain location-based: the ring distance from the free starter district drives the item counts. The player can only claim a plot adjacent to currently owned land, so the city grows as a connected network.
- Plot ownership, expansion purchases, legacy migration, and build/road placement validation continue to use the same authoritative LandExpansionManager state. The overlay is a view of that state, not a second ownership database.
- Automated regression coverage now checks owned/available/locked classification, the 256 m² parcel size, and the presence of the batched ownership overlay.
