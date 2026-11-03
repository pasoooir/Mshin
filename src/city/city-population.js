export const CITY_MAX_CITIZEN_AGENTS = 64;
export const CITY_RESIDENTS_PER_AGENT = 3;
const DIRECTIONS = Object.freeze([
  Object.freeze({ x: 1, y: 0 }),
  Object.freeze({ x: 0, y: 1 }),
  Object.freeze({ x: -1, y: 0 }),
  Object.freeze({ x: 0, y: -1 })
]);

const inside = (x, y, size) => Number.isInteger(x) && Number.isInteger(y)
  && x >= 0 && y >= 0 && x < size && y < size;
const isRoad = (city, x, y) => inside(x, y, city.grid.length) && city.grid[y]?.[x] === "road";

function deterministicIndex(seed, id, step, length) {
  let value = (seed ^ Math.imul(id + 1, 0x9e3779b1) ^ Math.imul(step + 1, 0x85ebca6b)) >>> 0;
  value ^= value >>> 16;
  value = Math.imul(value, 0x7feb352d) >>> 0;
  value = (value ^ (value >>> 15)) >>> 0;
  return length ? value % length : 0;
}

function roadNeighbors(city, x, y) {
  return DIRECTIONS
    .map(direction => ({ x: x + direction.x, y: y + direction.y }))
    .filter(point => isRoad(city, point.x, point.y));
}

function chooseNextRoad(city, citizen) {
  const options = roadNeighbors(city, citizen.roadX, citizen.roadY);
  if (!options.length) {
    citizen.targetX = null;
    citizen.targetY = null;
    citizen.heading = 0;
    return false;
  }
  const forward = options.filter(point => point.x !== citizen.previousX || point.y !== citizen.previousY);
  const candidates = forward.length ? forward : options;
  const next = candidates[deterministicIndex(city.seed >>> 0, citizen.id, citizen.routeStep, candidates.length)];
  citizen.targetX = next.x;
  citizen.targetY = next.y;
  citizen.heading = Math.atan2(next.y - citizen.roadY, next.x - citizen.roadX);
  return true;
}

function relocateCitizen(city, citizen) {
  const home = city.buildings.find(building => building.id === citizen.homeId && building.type === "home");
  if (!home) return false;
  const access = roadNeighbors(city, home.x, home.y);
  if (!access.length) return false;
  const road = access[deterministicIndex(city.seed >>> 0, citizen.id, citizen.routeStep, access.length)];
  citizen.roadX = road.x;
  citizen.roadY = road.y;
  citizen.x = road.x;
  citizen.y = road.y;
  citizen.previousX = null;
  citizen.previousY = null;
  citizen.targetX = null;
  citizen.targetY = null;
  return chooseNextRoad(city, citizen);
}

function mapCommuteAgents(city, assignments) {
  const flowsByHome = new Map();
  for (const flow of assignments || []) {
    if (!flow || !Number.isSafeInteger(flow.homeId) || !Number.isSafeInteger(flow.workplaceId)
      || !Number.isSafeInteger(flow.workers) || flow.workers <= 0 || !Array.isArray(flow.route) || !flow.route.length) continue;
    if (!flowsByHome.has(flow.homeId)) flowsByHome.set(flow.homeId, []);
    flowsByHome.get(flow.homeId).push(flow);
  }
  const citizensByHome = new Map();
  for (const citizen of city.citizens) {
    if (!citizensByHome.has(citizen.homeId)) citizensByHome.set(citizen.homeId, []);
    citizensByHome.get(citizen.homeId).push(citizen);
  }
  const homeById = new Map(city.buildings.filter(building => building.type === "home").map(home => [home.id, home]));
  const result = new Map();
  for (const [homeId, citizens] of citizensByHome) {
    const flows = flowsByHome.get(homeId) || [];
    const totalWorkers = flows.reduce((sum, flow) => sum + flow.workers, 0);
    const residents = Math.max(0, Number(homeById.get(homeId)?.residents) || 0);
    if (!totalWorkers || !residents) continue;
    citizens.sort((a, b) => a.id - b.id);
    const workerAgents = Math.min(citizens.length, Math.max(1, Math.round(citizens.length * totalWorkers / residents)));
    for (let i = 0; i < workerAgents; i++) {
      const workerSlot = Math.floor(i * totalWorkers / workerAgents);
      let cumulative = 0;
      const flow = flows.find(item => {
        cumulative += item.workers;
        return workerSlot < cumulative;
      });
      if (flow) result.set(citizens[i].id, flow);
    }
  }
  return result;
}

function advanceCommute(city, citizen, flow, seconds) {
  const route = flow.route;
  if (!route.length || route.some(point => !isRoad(city, point.x, point.y))) return false;
  if (citizen.commuteWorkplaceId !== flow.workplaceId
    || !["outbound", "returning"].includes(citizen.commutePhase)) {
    citizen.commuteWorkplaceId = flow.workplaceId;
    citizen.commutePhase = "outbound";
    citizen.commuteRouteStep = 0;
    citizen.commuteWait = 0;
    citizen.roadX = route[0].x;
    citizen.roadY = route[0].y;
    citizen.x = route[0].x;
    citizen.y = route[0].y;
    citizen.previousX = null;
    citizen.previousY = null;
  }
  if (citizen.commuteWait > 0) {
    citizen.commuteWait = Math.max(0, citizen.commuteWait - seconds);
    return true;
  }
  const forward = citizen.commutePhase !== "returning";
  const pointAt = index => route[forward ? index : route.length - 1 - index];
  let index = Math.max(0, Math.min(route.length - 1, citizen.commuteRouteStep || 0));
  const current = pointAt(index);
  if (citizen.roadX !== current.x || citizen.roadY !== current.y) {
    const recovered = route.findIndex(point => point.x === citizen.roadX && point.y === citizen.roadY);
    if (recovered >= 0) index = forward ? recovered : route.length - 1 - recovered;
    else {
      index = 0;
      const start = pointAt(index);
      citizen.roadX = start.x; citizen.roadY = start.y;
      citizen.x = start.x; citizen.y = start.y;
    }
  }
  let remaining = Math.min(0.5, Number.isFinite(citizen.pace) && citizen.pace > 0 ? citizen.pace : 0.15) * seconds;
  let transitions = 0;
  while (remaining > 1e-8 && transitions < 8) {
    if (index >= route.length - 1) {
      citizen.commutePhase = forward ? "returning" : "outbound";
      citizen.commuteRouteStep = 0;
      citizen.commuteWait = 3;
      citizen.targetX = null;
      citizen.targetY = null;
      return true;
    }
    const next = pointAt(index + 1);
    if (!isRoad(city, next.x, next.y)) return false;
    const dx = next.x - citizen.x, dy = next.y - citizen.y;
    const distance = Math.hypot(dx, dy);
    citizen.targetX = next.x; citizen.targetY = next.y;
    citizen.heading = Math.atan2(dy, dx);
    if (distance <= 1e-8) {
      citizen.previousX = citizen.roadX; citizen.previousY = citizen.roadY;
      citizen.roadX = next.x; citizen.roadY = next.y;
      index++; transitions++;
      continue;
    }
    if (remaining >= distance) {
      remaining -= distance;
      citizen.x = next.x; citizen.y = next.y;
      citizen.previousX = citizen.roadX; citizen.previousY = citizen.roadY;
      citizen.roadX = next.x; citizen.roadY = next.y;
      index++; transitions++;
    } else {
      citizen.x += dx / distance * remaining;
      citizen.y += dy / distance * remaining;
      remaining = 0;
    }
  }
  citizen.commuteRouteStep = index;
  return true;
}

/**
 * Keep a bounded, deterministic pedestrian population in sync with residential
 * occupancy. Each agent represents three residents and walks only on road tiles.
 */
export function syncCityCitizens(city) {
  if (!city || !Array.isArray(city.grid) || !Array.isArray(city.buildings)) {
    throw new TypeError("A valid city is required to synchronize citizens");
  }
  if (!Array.isArray(city.citizens)) city.citizens = [];
  const homes = city.buildings.filter(building => building.type === "home" && building.residents > 0);
  const homeIds = new Set(homes.map(home => home.id));
  let changed = false;

  // Reconcile agents whose home was demolished. Legacy agents without a home
  // assignment are deterministically attached to an existing residence.
  const reconciled = [];
  for (const citizen of city.citizens) {
    if (homeIds.has(citizen.homeId)) {
      reconciled.push(citizen);
    } else if (citizen.homeId === undefined && homes.length) {
      citizen.homeId = homes[(Math.max(1, citizen.id) - 1) % homes.length].id;
      reconciled.push(citizen);
    } else {
      changed = true;
    }
  }
  if (reconciled.length !== city.citizens.length) changed = true;
  city.citizens = reconciled;

  const desired = homes.length
    ? Math.min(CITY_MAX_CITIZEN_AGENTS, Math.ceil(Math.max(0, city.population || 0) / CITY_RESIDENTS_PER_AGENT), homes.length * 8)
    : 0;

  const nextAvailableCitizenId = Math.max(0, ...city.citizens.map(citizen => Number.isSafeInteger(citizen.id) ? citizen.id : 0)) + 1;
  if (!Number.isSafeInteger(city.nextCitizenId) || city.nextCitizenId < nextAvailableCitizenId) {
    city.nextCitizenId = nextAvailableCitizenId;
    changed = true;
  }

  if (city.citizens.length > desired) {
    city.citizens.sort((a, b) => a.id - b.id);
    city.citizens.length = desired;
    changed = true;
  }

  while (city.citizens.length < desired) {
    const id = city.nextCitizenId++;
    const home = homes[(id - 1) % homes.length];
    const access = roadNeighbors(city, home.x, home.y);
    if (!access.length) break;
    const road = access[deterministicIndex(city.seed >>> 0, id, 0, access.length)];
    const citizen = {
      id,
      homeId: home.id,
      x: road.x,
      y: road.y,
      roadX: road.x,
      roadY: road.y,
      previousX: null,
      previousY: null,
      targetX: null,
      targetY: null,
      routeStep: 0,
      heading: 0,
      phase: (id % 7) * 0.7,
      pace: 0.12 + (id % 5) * 0.018
    };
    chooseNextRoad(city, citizen);
    city.citizens.push(citizen);
    changed = true;
  }

  return changed;
}

/** Advance each pedestrian over connected road segments with a strict work bound. */
export function stepCityCitizens(city, seconds = 1, commuteAssignments = []) {
  if (!city || !Array.isArray(city.grid) || !Array.isArray(city.citizens)
    || !Number.isFinite(seconds) || seconds <= 0) {
    throw new TypeError("A valid city and positive pedestrian step are required");
  }

  city.citizens = city.citizens.filter(citizen => {
    if (!isRoad(city, citizen.roadX, citizen.roadY)) return relocateCitizen(city, citizen);
    return true;
  });

  const commuteByCitizen = mapCommuteAgents(city, commuteAssignments);
  for (const citizen of city.citizens) {
    const commute = commuteByCitizen.get(citizen.id);
    if (commute && advanceCommute(city, citizen, commute, seconds)) {
      citizen.phase = (citizen.phase || 0) + Math.min(0.5, citizen.pace || 0.15) * seconds;
      continue;
    }
    if (!commute) {
      delete citizen.commuteWorkplaceId;
      delete citizen.commutePhase;
      delete citizen.commuteRouteStep;
      delete citizen.commuteWait;
    }
    const pace = Number.isFinite(citizen.pace) && citizen.pace > 0 ? Math.min(0.5, citizen.pace) : 0.15;
    let remaining = pace * seconds;
    let transitions = 0;
    while (remaining > 1e-8 && transitions < 8) {
      if (!isRoad(city, citizen.targetX, citizen.targetY) && !chooseNextRoad(city, citizen)) break;
      const dx = citizen.targetX - citizen.x;
      const dy = citizen.targetY - citizen.y;
      const length = Math.hypot(dx, dy);
      if (length <= 1e-8) {
        citizen.previousX = citizen.roadX;
        citizen.previousY = citizen.roadY;
        citizen.roadX = citizen.targetX;
        citizen.roadY = citizen.targetY;
        citizen.routeStep += 1;
        if (!chooseNextRoad(city, citizen)) break;
        transitions += 1;
        continue;
      }
      if (remaining >= length) {
        remaining -= length;
        citizen.x = citizen.targetX;
        citizen.y = citizen.targetY;
        citizen.previousX = citizen.roadX;
        citizen.previousY = citizen.roadY;
        citizen.roadX = citizen.targetX;
        citizen.roadY = citizen.targetY;
        citizen.routeStep += 1;
        if (!chooseNextRoad(city, citizen)) break;
        transitions += 1;
      } else {
        citizen.x += dx / length * remaining;
        citizen.y += dy / length * remaining;
        remaining = 0;
      }
    }
    citizen.phase = (citizen.phase || 0) + pace * seconds;
  }
  return city.citizens;
}
