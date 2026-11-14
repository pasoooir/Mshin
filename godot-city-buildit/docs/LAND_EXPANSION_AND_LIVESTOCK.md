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
