# Sims City — Performance Strategy

## 1. Performance is a product requirement

The current repository has an observed browser-smoke failure caused by a single 5,321.6 ms draw/loop frame. This must be profiled and corrected before city-scale rendering is layered on top. Do not weaken the existing performance assertion without evidence.

## 2. Measurement baseline

Collect on fixed representative devices and browsers:
- frame time p50/p95/p99 and max;
- update phase time and simulation tick backlog;
- draw/render time, draw calls and triangles;
- memory and asset residency;
- visible/active NPC and vehicle counts;
- pathfinding queue length and cache hit rate;
- startup and scene transition time;
- save/load duration and serialized save size.

Separate warm-up frames, asset decode, shader compilation and steady-state measurements. Report outliers and repeat runs rather than hiding a stall in an average.

## 3. CPU architecture

- Fixed-tick deterministic simulation; render interpolation.
- Stagger low-priority work across ticks.
- Event-driven recomputation for road connectivity, parcel access, land value and service coverage.
- Cache routes and invalidate only changed graph regions.
- Spatial partitioning for collision, visibility and nearby queries.
- Pool short-lived entities/effects.
- Near/mid/far simulation tiers for citizens and vehicles.
- Avoid per-frame allocation in hot loops and avoid repeated whole-city scans.

## 4. GPU/rendering

- Frustum culling and distance-based LOD.
- Instance/batch repeated props and building modules where supported.
- Limit unique materials and transparent overdraw.
- Use shadow distance/cascade limits; disable small-object shadow casting.
- Atlas UI/prop textures when appropriate.
- Use impostors or simplified far representations for dense districts.
- Stream district assets and release unused resources.
- Avoid expensive blur/filter passes and excessive particles.
- Keep UI and city rendering on a clear layer/camera strategy.

## 5. Simulation scale tiers

- Near: full steering, collision, lane following, citizen animation and interaction.
- Mid: simplified movement and decisions at reduced frequency.
- Far: aggregate trip flows, employment, consumption and service demand statistically.
- Preserve population/economy totals across tier changes; transitions must be deterministic and tested.

## 6. Adaptive quality

Quality scaling may change shadows, LOD, visible NPC count, particles, reflection and render resolution. It must not arbitrarily change tax, population, production, service capacity or mission outcomes.

## 7. Budget-setting procedure

Do not invent final device budgets before profiling. Establish baseline on low/mid/high reference devices, then set budgets with headroom. Track CPU/GPU, RAM, draw calls, NPCs, vehicles, buildings, texture memory, asset size and load time in the feature matrix.

## 8. Performance acceptance

- No multi-second frame stalls in the browser smoke scenario.
- Stable p95 frame budget on declared reference devices after warm-up.
- Simulation tick backlog bounded under target city load.
- Save/load and route recomputation remain responsive.
- Low-quality mode remains functionally equivalent.
- Every renderer-sensitive PR includes before/after benchmark data and screenshots.
