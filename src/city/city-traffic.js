const DIRECTIONS = Object.freeze([
  Object.freeze({ x: 1, y: 0 }),
  Object.freeze({ x: 0, y: 1 }),
  Object.freeze({ x: -1, y: 0 }),
  Object.freeze({ x: 0, y: -1 })
]);
const COLORS = Object.freeze(["#f2bd4d", "#65c8dc", "#d77e8b", "#a8c98a", "#b69be8", "#e5e9ef"]);
const MAX_TRAFFIC = 12;
const SPAWN_INTERVAL = 8;
const MIN_SPAWN_GAP = 2.5;

const inside = (grid, x, y) => Number.isInteger(x) && Number.isInteger(y)
  && y >= 0 && y < grid.length && x >= 0 && x < (grid[y]?.length || 0);
const isRoad = (grid, x, y) => inside(grid, x, y) && grid[y][x] === "road";

function roadNeighbors(grid, x, y) {
  return DIRECTIONS
    .map(direction => ({ x: x + direction.x, y: y + direction.y }))
    .filter(point => isRoad(grid, point.x, point.y));
}

function deterministicIndex(seed, id, step, length) {
  let value = (seed ^ Math.imul(id + 1, 0x9e3779b1) ^ Math.imul(step + 1, 0x85ebca6b)) >>> 0;
  value ^= value >>> 16;
  value = Math.imul(value, 0x7feb352d) >>> 0;
  value = (value ^ (value >>> 15)) >>> 0;
  return length ? value % length : 0;
}

function chooseNextRoad(city, vehicle) {
  const options = roadNeighbors(city.grid, vehicle.x, vehicle.y);
  if (!options.length) return null;

  const forward = options.filter(point => point.x !== vehicle.previousX || point.y !== vehicle.previousY);
  const candidates = forward.length ? forward : options;
  if (candidates.length === 1) return candidates[0];

  const headingX = Number.isFinite(vehicle.headingX) ? vehicle.headingX : 0;
  const headingY = Number.isFinite(vehicle.headingY) ? vehicle.headingY : 0;
  let best = -Infinity;
  let preferred = [];
  for (const point of candidates) {
    const dx = point.x - vehicle.x;
    const dy = point.y - vehicle.y;
    const score = dx * headingX + dy * headingY;
    if (score > best + 1e-9) {
      best = score;
      preferred = [point];
    } else if (Math.abs(score - best) <= 1e-9) {
      preferred.push(point);
    }
  }
  return preferred[deterministicIndex(city.seed >>> 0, vehicle.id, vehicle.routeStep || 0, preferred.length)];
}

function setNextRoad(city, vehicle) {
  const next = chooseNextRoad(city, vehicle);
  if (!next) {
    vehicle.targetX = null;
    vehicle.targetY = null;
    return false;
  }
  vehicle.targetX = next.x;
  vehicle.targetY = next.y;
  const dx = next.x - vehicle.x;
  const dy = next.y - vehicle.y;
  vehicle.headingX = dx;
  vehicle.headingY = dy;
  vehicle.heading = Math.atan2(dy, dx);
  return true;
}

function spawnVehicle(city) {
  if (city.traffic.length >= MAX_TRAFFIC || city.tick % SPAWN_INTERVAL !== 0) return;
  const roads = [];
  for (let y = 0; y < city.grid.length; y++) {
    for (let x = 0; x < city.grid[y].length; x++) {
      if (isRoad(city.grid, x, y) && roadNeighbors(city.grid, x, y).length >= 2) roads.push({ x, y });
    }
  }
  const available = roads.filter(point => city.traffic.every(vehicle =>
    Math.hypot(vehicle.x - point.x, vehicle.y - point.y) >= MIN_SPAWN_GAP
  ));
  if (!available.length) return;

  city.nextTrafficId = Number.isSafeInteger(city.nextTrafficId) && city.nextTrafficId > 0
    ? city.nextTrafficId : Math.max(0, ...city.traffic.map(vehicle => vehicle.id || 0)) + 1;
  const id = city.nextTrafficId++;
  const start = available[deterministicIndex(city.seed >>> 0, id, city.tick, available.length)];
  const vehicle = {
    id,
    x: start.x,
    y: start.y,
    previousX: null,
    previousY: null,
    targetX: null,
    targetY: null,
    headingX: 0,
    headingY: 0,
    heading: 0,
    routeStep: 0,
    speed: 0.34 + (id % 4) * 0.035,
    color: COLORS[(id - 1) % COLORS.length]
  };
  if (setNextRoad(city, vehicle)) city.traffic.push(vehicle);
}

function advanceVehicle(city, vehicle, distance) {
  let remaining = distance;
  let transitions = 0;
  while (remaining > 1e-8 && transitions < 8) {
    if (!isRoad(city.grid, vehicle.targetX, vehicle.targetY)) {
      if (!setNextRoad(city, vehicle)) return;
    }
    const dx = vehicle.targetX - vehicle.x;
    const dy = vehicle.targetY - vehicle.y;
    const length = Math.hypot(dx, dy);
    if (length <= 1e-8) {
      vehicle.previousX = vehicle.x;
      vehicle.previousY = vehicle.y;
      vehicle.x = vehicle.targetX;
      vehicle.y = vehicle.targetY;
      vehicle.routeStep = (vehicle.routeStep || 0) + 1;
      if (!setNextRoad(city, vehicle)) return;
      transitions++;
      continue;
    }
    if (remaining >= length) {
      vehicle.x = vehicle.targetX;
      vehicle.y = vehicle.targetY;
      remaining -= length;
      vehicle.previousX = Math.round(vehicle.x - dx);
      vehicle.previousY = Math.round(vehicle.y - dy);
      vehicle.routeStep = (vehicle.routeStep || 0) + 1;
      if (!setNextRoad(city, vehicle)) return;
      transitions++;
    } else {
      vehicle.x += dx / length * remaining;
      vehicle.y += dy / length * remaining;
      remaining = 0;
    }
  }
}

/** Move a bounded fleet along connected road tiles; no vehicle can drive over grass or buildings. */
export function stepCityTraffic(city, seconds = 1) {
  if (!city || !Array.isArray(city.grid) || !Array.isArray(city.traffic)
    || !Number.isFinite(seconds) || seconds <= 0) {
    throw new TypeError("A valid city traffic state and positive step are required");
  }
  // Road demolition may strand a car mid-segment; retire it before it can be saved off-road.
  city.traffic = city.traffic.filter(vehicle => isRoad(city.grid, Math.round(vehicle.x), Math.round(vehicle.y)));
  spawnVehicle(city);
  for (const vehicle of city.traffic) {
    if (!Number.isFinite(vehicle.speed) || vehicle.speed <= 0) vehicle.speed = 0.4;
    advanceVehicle(city, vehicle, vehicle.speed * seconds);
  }
  return city.traffic;
}

export const CITY_TRAFFIC_LIMIT = MAX_TRAFFIC;
