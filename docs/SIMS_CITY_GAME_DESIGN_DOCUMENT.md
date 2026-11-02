# Sims City — Game Design Document

**Product:** Sims City (working title)  
**Repository:** pasoooir/Mshin  
**Target:** browser-first, mobile-friendly city simulation with Cocos Creator 3.8.6 as the native engine target  
**Status:** design baseline; no city gameplay is yet claimed implemented.

## 1. Product vision

Build an original, living city simulation where urban planning, citizen life, business, public services, transport and direct vehicle driving are parts of one connected simulation. The player is not only decorating a map: choices change access, travel time, land value, employment, service coverage, municipal finances and citizens' daily routines.

The existing Mshin racing game remains a supported game mode and becomes the technical foundation for player-controlled vehicles. It must not be deleted or silently replaced.

## 2. Design pillars

1. **Legible cause and effect:** every major city problem must have a visible cause, measurable impact and actionable remedy.
2. **A connected city:** roads, parcels, buildings, households, jobs, services and missions share one authoritative world model.
3. **Living but scalable simulation:** the simulated population is independent from the number of visible NPC models.
4. **Player agency at two scales:** strategic city planning and direct first-person/third-person driving missions.
5. **Offline-first ownership:** cities save locally with versioning and recovery; online features are optional and must not block core play.
6. **Visual quality with a budget:** high-quality, plugin-assisted authored assets are required, but each asset must pass runtime and performance gates.
7. **No fake completion:** a feature is accepted only after runtime and acceptance evidence.

## 3. Core play loop

Observe city indicators → identify a constraint → plan a road/zone/service/building intervention → preview cost and impact → commit construction → advance simulation time → citizens/businesses react → inspect outcomes → adjust budget/tax/service levels → take a driving or service mission → earn funds/reputation/resources → expand the city.

## 4. Player modes

### City management
- Isometric/oblique camera with pan, zoom and rotation.
- Select parcels, roads, buildings, citizens/households and service facilities.
- Build, upgrade and remove roads and structures with clear costs, range previews and rejection reasons.
- Inspect overlays for traffic, land value, population, employment, pollution and service coverage.
- Pause, normal, 2× and faster simulation speeds.

### Free driving
- Enter a player vehicle from a city location.
- Drive on the same road geometry and traffic rules used by NPC vehicles.
- Park, exit/enter, switch vehicles and accept city missions.
- Preserve Mshin steering, gyro and multi-touch behavior; use independent city/driving input contexts.

### Mission play
- Taxi, courier, freight, emergency response, tourism, patrol and race missions.
- Mission outcome must mutate the authoritative city state (e.g. delivery inventory, service response, citizen outcome, budget or tourism).
- No mission may award city benefits solely through a UI animation.

## 5. World and scale

The first vertical slice uses one compact, authored fictional district with a grid-compatible parcel map, a small road graph, a few road types, a limited building set and one functioning service. The world model must support expansion into multiple districts and maps without changing entity identity or save format.

World coordinates use a single documented metric convention. Grid coordinates are discrete planning coordinates; road geometry and vehicle motion use continuous world coordinates. Conversion must be centralized and tested.

## 6. Simulation rules

- Deterministic fixed simulation ticks; rendering frame rate must not alter economy or citizen outcomes.
- Stable IDs and seeded randomness for reproducible tests and saves.
- Citizens are grouped into households and assigned homes, jobs, needs and schedules.
- Buildings have explicit access, occupancy, utility/service demand and operating state.
- Economy is a ledger of income, upkeep, construction and operating costs; no hidden money creation.
- Roads form a directed graph with lane/turn restrictions and costs. Vehicle route choice considers legal access, travel time and congestion.
- Municipal services use capacity, coverage, response time and budget; a building outside coverage must not be treated as served.
- Environmental conditions modify defined variables only; weather is not a cosmetic-only toggle.

## 7. First playable vertical slice

The first city slice must include:
- One small terrain/map area with selectable parcels.
- Road drawing with preview, cost, connection validation and commit.
- Residential, commercial and public building placement.
- Basic household/population growth and home-to-work travel.
- One business inventory/production loop and city budget.
- One municipal service with coverage/capacity affecting buildings.
- NPC vehicles routed on the road graph.
- Player driving on the same road network.
- One mission whose result changes city state.
- Versioned city save/load and a usable mobile-first UI.

The existing race mode must still launch and pass its regression suite.

## 8. Progression and scenarios

Unlocks are earned through measurable city outcomes: population served, balanced budget, reduced response time, improved mobility, employment, pollution targets and mission completion. Scenarios can introduce terrain, climate, resource or infrastructure constraints. Avoid arbitrary unlocks that do not teach or reward a meaningful system.

## 9. UX principles

- Every tool has a visible active state, clear touch target and contextual preview.
- Invalid actions explain why (budget, access, terrain, overlap, capacity or prerequisite).
- Every indicator can be inspected to reveal contributing factors.
- Use progressive disclosure: simple default actions first, advanced overlays and policy controls on demand.
- Support portrait and landscape layouts; preserve accessible keyboard navigation.
- Never expose a button that is only decorative.

## 10. Research synthesis and design lessons

The following are recurring themes in reviewed public sources, not claims of unanimous player opinion:

| Theme | Observed evidence | Design response |
|---|---|---|
| Traffic needs transparency and useful controls | SimCity 4: Rush Hour reviews praise transport options, direct vehicle play and traffic-query visibility. | Road/traffic overlays, trip diagnostics and player driving must be first-class systems. |
| Small build areas constrain planning | SimCity (2013) community discussion repeatedly criticized small city tiles and limited regional control. | Use expandable districts and connected regional maps; don't hard-cap the player to a tiny isolated tile. |
| Simulation must produce credible behavior | Cities: Skylines II community threads report illogical routes, broken economy feedback and citizens that can feel detailed but unconvincing. | Prefer fewer coherent, testable behaviors over high-volume but contradictory micro-simulation. |
| Performance is gameplay quality | Reviews and community discussions cite simulation slowdowns, high rendering cost and late-game stalls. | Budget CPU/GPU/memory early; simulation tiers and LOD are core architecture, not late polish. |
| Beautiful additions do not fix core systems | Cities of Tomorrow reviews praise its visual ideas but criticize unchanged city-size and underlying mechanics. | New art and content never substitute for working roads, economy, services and progression. |
| Offline access and durable saves matter | EA's BuildIt help documentation describes offline play limitations and save synchronization caveats. | Core single-player play and local save/load must work without network access. |

### Reference set
- [SimCity 4: Rush Hour review aggregation](https://www.mobygames.com/game/10518/simcity-4-rush-hour/reviews/)
- [SimCity 4 Rush Hour player/critic overview](https://www.metacritic.com/game/simcity-4-rush-hour/)
- [SimCity 2013 community discussion](https://community.simtropolis.com/forums/topic/53706-what-do-you-think-of-sc2013/)
- [SimCity 2013 review](https://kotaku.com/simcity-the-kotaku-review-5989115)
- [Cities: Skylines II community megathread (2025)](https://www.reddit.com/r/CitiesSkylines/comments/1paxna5/whats-cities-skylines-ii-like-now-megathread/)
- [Cities: Skylines II community megathread (2026)](https://www.reddit.com/r/CitiesSkylines/comments/1s9332r/whats-cities-skylines-ii-like-now-megathread/)
- [Cities: Skylines II performance and launch analysis](https://arstechnica.com/gaming/2023/11/the-sad-story-of-cities-skylines-2s-launch-and-how-the-game-hopes-to-get-better/)
- [Cities of Tomorrow review](https://www.gamespot.com/reviews/simcity-cities-of-tomorrow-review/1900-6415573/)
- [EA SimCity BuildIt beginner guide](https://help.ea.com/en/articles/simcity/simcity-buildit/beginner-guide/)

## 11. Scope exclusions for the first slice

No multiplayer economy, live-service dependency, real-money store, cloud account requirement, huge open world, full metro simulation, complex disasters or hundreds of individually rendered citizens in the first slice. These may be considered only after the core simulation is stable.

## 12. Acceptance

The vertical slice is accepted only when the full city-building → citizen/business response → traffic → player driving mission → city-state mutation → save → reload sequence passes in browser, with regression evidence for the original Mshin race mode.
