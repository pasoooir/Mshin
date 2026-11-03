import { computeCityEmployment, JOBS_PER_BUILDING } from "./city-employment.js";

const SIZE = 32;
const DIRECTIONS = Object.freeze([[1,0],[0,1],[-1,0],[0,-1]]);
const SECTOR_ORDER = Object.freeze(["industrial","shop","administrative","service"]);
const inside = (x,y) => x >= 0 && y >= 0 && x < SIZE && y < SIZE;
const indexOf = (x,y) => y * SIZE + x;
const pointOf = index => ({ x: index % SIZE, y: Math.floor(index / SIZE) });

function roadAccess(city, building) {
  return DIRECTIONS
    .map(([dx,dy]) => ({ x: building.x + dx, y: building.y + dy }))
    .filter(point => inside(point.x,point.y) && city.grid[point.y]?.[point.x] === "road")
    .sort((a,b) => a.y - b.y || a.x - b.x);
}

function searchRoadNetwork(city, home) {
  const starts = roadAccess(city,home);
  if (!starts.length) return null;
  const parent = new Int16Array(SIZE * SIZE);
  const distance = new Int16Array(SIZE * SIZE);
  parent.fill(-2);
  distance.fill(-1);
  const queue = new Int16Array(SIZE * SIZE);
  let head = 0, tail = 0;
  for (const start of starts) {
    const index = indexOf(start.x,start.y);
    if (parent[index] !== -2) continue;
    parent[index] = -1;
    distance[index] = 0;
    queue[tail++] = index;
  }
  while (head < tail) {
    const current = queue[head++];
    const point = pointOf(current);
    for (const [dx,dy] of DIRECTIONS) {
      const x = point.x + dx, y = point.y + dy;
      if (!inside(x,y) || city.grid[y]?.[x] !== "road") continue;
      const next = indexOf(x,y);
      if (parent[next] !== -2) continue;
      parent[next] = current;
      distance[next] = distance[current] + 1;
      queue[tail++] = next;
    }
  }
  return { parent, distance };
}

function shortestWorkplaceRoute(city, search, workplace) {
  if (!search) return null;
  let target = -1, bestDistance = Infinity;
  for (const access of roadAccess(city,workplace)) {
    const index = indexOf(access.x,access.y);
    const distance = search.distance[index];
    if (distance >= 0 && (distance < bestDistance || (distance === bestDistance && index < target))) {
      target = index;
      bestDistance = distance;
    }
  }
  if (target < 0) return null;
  const route = [];
  for (let cursor = target; cursor >= 0; cursor = search.parent[cursor]) route.push(pointOf(cursor));
  route.reverse();
  return { distance: bestDistance, route };
}


function averageTrafficDelayPercent(city, assignments) {
  if (!Array.isArray(city.traffic) || city.traffic.length === 0 || !assignments.length) return 0;
  let weightedDelay = 0;
  let weightedSegments = 0;
  for (const flow of assignments) {
    const segments = Math.max(0, flow.route.length - 1);
    if (!segments || flow.workers <= 0) continue;
    let routeDelay = 0;
    for (let index = 0; index < flow.route.length; index++) {
      const point = flow.route[index];
      let nearbyVehicles = 0;
      for (const vehicle of city.traffic) {
        if (!Number.isFinite(vehicle.x) || !Number.isFinite(vehicle.y)) continue;
        if (Math.hypot(vehicle.x - point.x, vehicle.y - point.y) <= 1.15) nearbyVehicles++;
      }
      const speedFactor = Math.max(0.4, 1 - nearbyVehicles * 0.18);
      routeDelay += (1 / speedFactor) - 1;
    }
    weightedDelay += (routeDelay / flow.route.length) * flow.workers * segments;
    weightedSegments += flow.workers * segments;
  }
  return weightedSegments
    ? Math.round(Math.min(150, weightedDelay / weightedSegments * 100) * 10) / 10
    : 0;
}

function distributeLaborForce(homes, laborForce) {
  const residents = homes.reduce((sum,home) => sum + Math.max(0,Number(home.residents) || 0),0);
  if (!residents || !laborForce) return new Map(homes.map(home => [home.id,0]));
  const quotas = homes.map(home => {
    const exact = laborForce * Math.max(0,Number(home.residents) || 0) / residents;
    return { id: home.id, workers: Math.floor(exact), remainder: exact - Math.floor(exact) };
  });
  let left = laborForce - quotas.reduce((sum,item) => sum + item.workers,0);
  quotas.sort((a,b) => b.remainder - a.remainder || a.id - b.id);
  for (let i=0; i<quotas.length && left>0; i++,left--) quotas[i].workers++;
  return new Map(quotas.map(item => [item.id,item.workers]));
}

/**
 * Match residents to actual workplaces using shortest paths over the road grid.
 * Aggregate worker counts are exact; the returned flows can also drive later
 * commute visualization without creating unbounded per-resident simulation agents.
 */
export function computeCityCommuting(city, employment = computeCityEmployment(city)) {
  if (!city || !Array.isArray(city.grid) || city.grid.length !== SIZE
    || !Array.isArray(city.buildings) || !city.grid.every(row => Array.isArray(row) && row.length === SIZE)
    || !employment || !Number.isSafeInteger(employment.laborForce) || employment.laborForce < 0
    || !Number.isSafeInteger(employment.employed) || employment.employed < 0) {
    throw new TypeError("A valid city and employment result are required");
  }
  const homes = city.buildings
    .filter(building => building.type === "home" && Number.isSafeInteger(building.id)
      && Number.isFinite(building.residents) && building.residents > 0)
    .sort((a,b) => a.id - b.id);
  const workplacesBySector = Object.fromEntries(SECTOR_ORDER.map(sector => [sector,[]]));

  for (const sector of SECTOR_ORDER) {
    let employedSlots = Math.max(0,Math.floor(employment.bySector?.[sector]?.employed || 0));
    const buildings = city.buildings.filter(building => building.type === sector)
      .sort((a,b) => a.id - b.id);
    for (const building of buildings) {
      const capacity = Math.min(JOBS_PER_BUILDING[sector],employedSlots);
      if (capacity <= 0) break;
      workplacesBySector[sector].push({ building, remaining: capacity });
      employedSlots -= capacity;
    }
  }

  const availableWorkplaces = SECTOR_ORDER.some(sector => workplacesBySector[sector].length > 0);
  if (!homes.length || !availableWorkplaces || employment.employed <= 0) {
    return Object.freeze({ laborForce: employment.laborForce, employed: employment.employed,
      assignedWorkers: 0, unreachableWorkers: Math.max(0,employment.employed),
      commuteCoverage: 0, averageCommuteDistance: 0, averageCongestionDelay: 0, assignments: Object.freeze([]) });
  }
  const workersByHome = distributeLaborForce(homes,employment.laborForce);
  const remainingByHome = new Map(workersByHome);
  // Cache one bounded BFS per residence, shared across all employment sectors.
  const searches = new Map(homes.map(home => [home.id,searchRoadNetwork(city,home)]));
  const assignments = [];
  let assignedWorkers = 0, weightedDistance = 0;
  for (const sector of SECTOR_ORDER) {
    const workplaces = workplacesBySector[sector];
    if (!workplaces.length) continue;
    const candidates = [];
    for (const home of homes) {
      const availableWorkers = remainingByHome.get(home.id) || 0;
      if (!availableWorkers) continue;
      const search = searches.get(home.id);
      const choices = [];
      for (const workplace of workplaces) {
        if (workplace.remaining <= 0) continue;
        const route = shortestWorkplaceRoute(city,search,workplace.building);
        if (route) choices.push({ workplace, ...route });
      }
      choices.sort((a,b) => a.distance - b.distance || a.workplace.building.id - b.workplace.building.id);
      candidates.push({ home, choices, bestDistance: choices[0]?.distance ?? Infinity });
    }
    // Serve the most road-constrained residences first, then nearest commutes.
    candidates.sort((a,b) => a.choices.length - b.choices.length
      || a.bestDistance - b.bestDistance || a.home.id - b.home.id);
    for (const candidate of candidates) {
      let remaining = remainingByHome.get(candidate.home.id) || 0;
      for (const choice of candidate.choices) {
        if (!remaining) break;
        const workers = Math.min(remaining,choice.workplace.remaining);
        if (!workers) continue;
        assignments.push({
          homeId: candidate.home.id,
          workplaceId: choice.workplace.building.id,
          sector,
          workers,
          distance: choice.distance,
          route: choice.route
        });
        remaining -= workers;
        choice.workplace.remaining -= workers;
        assignedWorkers += workers;
        weightedDistance += workers * choice.distance;
      }
      remainingByHome.set(candidate.home.id,remaining);
    }
  }

  const averageCommuteDistance = assignedWorkers
    ? Math.round(weightedDistance / assignedWorkers * 10) / 10 : 0;
  const averageCongestionDelay = averageTrafficDelayPercent(city, assignments);
  return Object.freeze({
    laborForce: employment.laborForce,
    employed: employment.employed,
    assignedWorkers,
    unreachableWorkers: Math.max(0,employment.employed - assignedWorkers),
    commuteCoverage: employment.employed ? Math.round(assignedWorkers / employment.employed * 100) : 0,
    averageCommuteDistance,
    averageCongestionDelay,
    assignments: Object.freeze(assignments.map(assignment => Object.freeze({
      ...assignment,
      route: Object.freeze(assignment.route.map(point => Object.freeze(point)))
    })))
  });
}
