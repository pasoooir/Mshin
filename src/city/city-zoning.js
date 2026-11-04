import { computeCityEmployment, JOBS_PER_BUILDING } from "./city-employment.js";

export const CITY_ZONES = Object.freeze({
  residential: Object.freeze({ label: "مسکونی", buildingType: "home", zoneCost: 160, constructionCost: 520, color: "#79b8e8" }),
  commercial: Object.freeze({ label: "تجاری", buildingType: "shop", zoneCost: 220, constructionCost: 880, color: "#e8bd69" }),
  industrial: Object.freeze({ label: "صنعتی", buildingType: "industrial", zoneCost: 280, constructionCost: 1350, color: "#a7aeb6" }),
  administrative: Object.freeze({ label: "اداری", buildingType: "administrative", zoneCost: 320, constructionCost: 1550, color: "#a995d6" }),
  recreational: Object.freeze({ label: "تفریحی", buildingType: "park", zoneCost: 180, constructionCost: 430, color: "#82c78a" })
});

const inside = (x, y, size) => Number.isInteger(x) && Number.isInteger(y) && x >= 0 && y >= 0 && x < size && y < size;
const roadNear = (grid, x, y) => [[1,0],[-1,0],[0,1],[0,-1]].some(([dx,dy]) =>
  inside(x+dx,y+dy,grid.length) && grid[y+dy][x+dx] === "road");

export function placeCityZone(city, x, y, type) {
  const definition = CITY_ZONES[type];
  if (!definition) return { ok:false, reason:"نوع منطقه‌بندی ناشناخته است" };
  if (!inside(x,y,city.grid.length)) return { ok:false, reason:"خارج از محدوده شهر" };
  if (city.grid[y][x] !== "grass") return { ok:false, reason:"این قطعه زمین اشغال شده است" };
  if (!roadNear(city.grid,x,y)) return { ok:false, reason:"منطقه باید به خیابان دسترسی داشته باشد" };
  if (city.treasury < definition.zoneCost) return { ok:false, reason:"بودجه کافی نیست" };
  city.treasury -= definition.zoneCost;
  city.grid[y][x] = "zone-" + type;
  city.zones ||= [];
  city.zones.push({ x, y, type, createdAt: city.tick || 0 });
  return { ok:true, item:{x,y,type}, cost:definition.zoneCost };
}

function demandAllows(city, type) {
  const activeCity = city.buildings.some(building => building.construction)
    ? { ...city, buildings: city.buildings.filter(building => !building.construction) }
    : city;
  // Reserve planned job capacity while a workplace is under construction, but do not activate it yet.
  const count = kind => city.buildings.filter(b => b.type === kind).length;
  const population = Math.max(0, city.population || 0);
  if (type === "residential") return population < count("home") * 25 + 60;
  if (type === "commercial" && count("shop") >= Math.max(3, Math.ceil(population / 18))) return false;
  if (type === "industrial" && count("industrial") >= Math.max(2, Math.ceil(population / 36))) return false;
  if (type === "administrative" && count("administrative") >= Math.max(2, Math.ceil(population / 180))) return false;
  if (type === "recreational") return count("park") < Math.max(10, Math.ceil(population / 85));
  const buildingType = CITY_ZONES[type]?.buildingType;
  const addedJobs = JOBS_PER_BUILDING[buildingType];
  if (!addedJobs) return false;
  const workforce = computeCityEmployment(activeCity);
  // Do not let job capacity outrun the resident workforce by more than one
  // small workplace (or 75% of the available labor force).
  const projectedShortage = Math.max(0, workforce.jobs + addedJobs - workforce.laborForce);
  const shortageAllowance = Math.max(18, Math.ceil(workforce.laborForce * 0.75));
  return projectedShortage <= shortageAllowance;
}

/** Grow at most one eligible zoned tile per call, keeping simulation work bounded. */
export function developCityZones(city, constructionDuration = 0) {
  if (!Array.isArray(city.zones) || city.zones.length === 0) return null;
  for (let index=0; index<city.zones.length; index++) {
    const zone = city.zones[index];
    const definition = CITY_ZONES[zone.type];
    if (!definition || !inside(zone.x,zone.y,city.grid.length)) continue;
    if (city.grid[zone.y][zone.x] !== "zone-" + zone.type) continue;
    if (!demandAllows(city,zone.type) || city.treasury < definition.constructionCost) continue;
    city.treasury -= definition.constructionCost;
    const residents = zone.type === "residential" ? 12 : 0;
    const building = {
      id: city.nextBuildingId++,
      type: definition.buildingType,
      x: zone.x,
      y: zone.y,
      level: 1,
      age: 0,
      residents,
      zoneType: zone.type
    };
    if (constructionDuration > 0 && zone.type !== "recreational") {
      building.construction = { duration: constructionDuration, remaining: constructionDuration };
    }
    city.grid[zone.y][zone.x] = "building";
    city.buildings.push(building);
    if (!building.construction) city.population += residents;
    city.zones.splice(index,1);
    return building;
  }
  return null;
}

export function isCityZoneCell(value) {
  return typeof value === "string" && value.startsWith("zone-") && Object.hasOwn(CITY_ZONES,value.slice(5));
}
