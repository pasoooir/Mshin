# Unique Realistic City-Building Asset Matrix

Status: **planning and inventory only**. No model in this document is claimed to exist until its source asset, license, import, in-game assignment, and visual evidence are checked.

## Non-negotiable visual target

Every player-placeable building type must resolve to its own recognizable 3D asset (or a documented, deliberately shared architectural family only where the gameplay item is genuinely the same building). A generic category model, white box, untextured fallback, or recolored copy does **not** satisfy this requirement.

Each asset must be attractive at the normal mobile isometric camera distance and remain legible when zoomed in. It needs a distinct silhouette, use-specific architecture, coherent scale, authored material palette, roof treatment, facade openings, entrance, signage/equipment, ground contact, and appropriate surroundings where footprint allows. Color variation must be designed per asset, not applied as a single category tint.

## Inventory verified from BuildManager.gd on main

The inventory below is based on `building_types` in `scripts/autoload/BuildManager.gd`. It lists player-facing entries and marks legacy entries separately. Names are current in-code names, not a claim that all have final localized labels.

### Residential

| Type ID | Required distinct visual |
|---|---|
| `residential_1` | Compact starter detached home; pitched roof, porch, garden and driveway |
| `residential_villa` | Premium villa; different footprint composition, roofline, glazing and landscaped yard |
| `residential_2` | Mid-rise apartment block; multiple balconies, repeated but varied windows, lobby |
| `residential_apartment` | Distinct contemporary apartment building; different facade rhythm and roof silhouette |
| `residential_farm` | Farmstead; farmhouse, barn/shed, crop rows and rural yard |

### Commercial / shops

Every shop below must be identifiable by its actual trade, not by a generic shop shell with a changed sign.

| Type ID | Required distinct visual identity |
|---|---|
| `building_supplies` | Building-materials retailer; lumber/brick display, loading bay and industrial shelving visible through glazing |
| `shop_chain` | Modern chain convenience store; branded canopy, broad storefront glazing and parking |
| `restaurant_traditional` | Traditional restaurant; warm materials, dining frontage, terrace and kitchen exhaust |
| `fast_food` | Fast-food outlet; bold contemporary frontage, drive-through lane/window where footprint permits |
| `art_supplies` | Art-supplies shop; creative colorful facade, display windows and art motifs |
| `hardware_store` | Hardware store; workshop-style frontage, tool displays and loading access |
| `farmers_market` | Open-air / covered farmers market; stalls, awnings, produce colors and canopy |
| `furniture_store` | Furniture showroom; large display windows, modern showroom massing and delivery access |
| `gardening_supplies` | Garden center; greenhouse glazing, plant racks, pots and green roof accents |
| `donut_shop` | Small bakery/donut shop; distinctive shopfront, display glazing and warm bakery palette |
| `home_appliances` | Appliance showroom; large glazed display bays and clean modern facade |
| `fashion_store` | Fashion boutique; elegant storefront, mannequins/display glazing and tailored facade |
| `sports_shop` | Sports retailer; energetic facade, equipment display and athletic graphic elements |
| `toy_store` | Toy store; playful but polished color blocking, display windows and playful roof/sign silhouette |
| `restoration_office` | Restoration/conservation office; professional civic-commercial architecture and workshop annex |
| `farmers_store` | Country store; rural timber/stone details, porch and agricultural goods display |
| `dessert_shop` | Dessert/patisserie; refined pastel facade, display windows and distinctive canopy |

### Industrial / factories

Each production tier is a different facility design. Do not use the same factory mesh scaled or tinted for all tiers.

| Type ID | Required distinct visual identity |
|---|---|
| `factory_small` | Small local workshop; low industrial shed, compact chimney/vent and loading door |
| `factory_basic` | Standard factory; larger production hall, office block and loading dock |
| `factory_mass` | Mass-production plant; multiple halls, service pipes, loading yard and machinery |
| `factory_hightech` | High-tech campus; clean modular buildings, glass/metal facade and rooftop equipment |
| `factory_nano` | Nano-tech facility; precision cleanroom campus, controlled access and advanced roof plant |

Legacy save-compatible types `industrial_1`, `industrial_2`, and `industrial_3` must continue loading. They may resolve to their closest canonical factory asset only if the save compatibility mapping is explicit and tested; they are not new player-facing catalog items.

### Services / civic infrastructure

Each service facility needs a building form that communicates its function at a glance. Variants in the same service family must still have visibly different scale and design.

| Type ID | Required distinct visual identity |
|---|---|
| `power_wind` | Wind turbine installation with tower, blades, transformer pad and access |
| `power_coal` | Coal power station; boiler hall, stacks, coal handling and service yard |
| `power_wind_deluxe` | Larger wind farm / substation compound, not a scaled copy of the single turbine |
| `power_solar` | Solar farm; visible panel arrays, inverter structures and maintenance paths |
| `power_oil` | Oil-fired power plant; fuel tanks, pipework, stacks and turbine hall |
| `power_nuclear` | Nuclear station; iconic containment structure, turbine hall, cooling infrastructure and secured perimeter |
| `water_tower` | Elevated water tower with tank, legs, ladder and pipe connections |
| `water_pump` | Water pumping station; low utility building, pump hall, pipes and settling infrastructure |
| `fire_station_small` | Compact fire station; one-bay garage, red identity, apron and visible fire engine |
| `fire_station` | Full fire station; multiple apparatus bays, tower/training feature and forecourt |
| `fire_station_deluxe` | Large emergency response campus; multiple bays, training yard and support wing |
| `police_small` | Neighborhood police post; compact secure entrance and marked patrol vehicle |
| `police_station` | Police station; public entrance, secure vehicle bays and civic signage |
| `police_basic` | Mid-size police facility; distinct massing and larger vehicle court |
| `police_precinct` | Large precinct; multi-wing civic complex, secure yard and parking |
| `clinic_small` | Small neighborhood clinic; welcoming entrance, medical signage and compact parking |
| `clinic` | Larger clinic; reception wing, treatment wing and ambulance access |
| `hospital` | Full hospital; multi-storey medical massing, emergency entrance, ambulance bay and rooftop helipad only if scale supports it |
| `sewage_small` | Small wastewater outflow facility; settling tank, pipes and compact service shed |
| `sewage_basic` | Standard wastewater treatment plant; clarifier tanks, channels and operations building |
| `sewage_deluxe` | Advanced wastewater treatment campus; multiple treatment basins, covered process halls and clean landscaping |
| `waste_dump_small` | Small managed waste depot; bins, sorting pad and service shed |
| `waste_dump` | Larger landfill/transfer site; earth berms, tipping area, machinery and access road |
| `waste_incinerator` | Waste incineration plant; furnace hall, tall stack, conveyors and emission-control equipment |
| `waste_recycling` | Recycling center; sorting hall, colored material bays, conveyors and public drop-off |
| `town_hall` | Town hall; civic landmark architecture, public steps/plaza, flagpoles and clock/signage |

### Parks and recreation

| Type ID | Required distinct visual identity |
|---|---|
| `park_small` | Designed neighborhood pocket park; paths, lawn, trees, seating, play/ornamental feature and varied planting |

As new park, recreation, entertainment, education, transport, beach, mountain, or landmark types are added to the catalog, each must be added to this matrix before being marked visually complete. The current BuildManager inventory only confirms `park_small`; it does not establish that a larger park catalog already exists.

## Current verified gap

The current runtime mapping in `BuildManager._ready()` assigns shared category-level models to residential, commercial, and industrial definitions. The commercial entries therefore share one generic shop model and the industrial entries share one generic factory model; the service and park categories are not covered by that mapping. Some showcase entries are explicitly skipped and Farm uses a procedural visual. The five GLTF files in the current manifest are not evidence that every listed type has its own model.

## Asset production and integration rules

1. Create a per-type asset registry keyed by the exact `building_types` ID. Do not select a model solely from `category`.
2. Produce original or openly licensed assets. For third-party assets record source URL, creator, exact license/version, attribution obligations, modifications, and local file path. Prefer CC0 / permissive sources; never assume a license from a download page.
3. Keep all runtime assets local and offline. No CDN or runtime download dependency.
4. Use GLB/GLTF with PBR materials. Preserve meaningful material separation (glass, painted metal, brick, concrete, roof, vegetation, signage) rather than one white material or a single flat tint.
5. Keep dimensions and pivots grounded in each building's footprint and stated real-world scale. A 1x1 utility structure must not be stretched into a 4x2 facility; use an asset designed for its actual footprint.
6. Provide LOD / mesh simplification and texture budgets appropriate to mobile GL Compatibility. Use atlases/instancing where practical without making different buildings look identical.
7. Preserve gameplay data, save IDs, production recipes, service values, costs, unlock levels and placement footprints unless a separately scoped gameplay change is required.
8. A missing/invalid model must be visible in validation and must not silently present as a white cube. In development builds show a clear diagnostic placeholder; do not mark the asset complete.
9. Add automated checks for registry coverage, local file existence, GLTF import, non-empty meshes, material assignments, dimensions, and per-type uniqueness (with explicit allowlist only for legacy aliases).
10. Add visual regression evidence from the actual game camera: one gallery/contact sheet covering every catalog item, plus mobile-sized screenshots at normal gameplay zoom. Automated import tests alone do not pass visual acceptance.
11. Verify representative and then full catalog rendering on Web/Chromium mobile and desktop; benchmark draw calls, triangles, texture memory and frame time before expanding the city population.

## Acceptance checklist

- [ ] Every current player-placeable catalog ID has an explicit asset-registry entry.
- [ ] Every distinct player-facing building type has a unique, use-appropriate model and palette.
- [ ] No player-placeable building renders as a white cube or generic category fallback.
- [ ] Every asset has recorded provenance/license and is packaged locally.
- [ ] All models import in Godot and have valid meshes, materials, bounds, pivots and scale.
- [ ] All catalog models are reviewed together in an in-game gallery/contact sheet.
- [ ] Normal mobile gameplay camera shows recognizable silhouettes and readable color/material variation.
- [ ] Mobile Web performance budget is measured and passes on the agreed target device.
- [ ] README and implementation audit are updated only with evidence-backed statuses.

## Delivery sequencing

1. Asset registry + automated catalog coverage audit; eliminate silent category-wide assignment.
2. Residential showcase pack and in-game gallery.
3. Commercial pack (each trade-specific shop).
4. Industrial pack (five distinct factory tiers).
5. Civic/service pack (each facility and tier).
6. Parks/recreation pack, then future specializations as they enter the catalog.
7. Full mobile visual/performance validation and evidence-backed README update.

This is a multi-stage asset production milestone. A planning document or successful importer test is not completion of the visual work.
