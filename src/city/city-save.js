import { CITY_ZONES, isCityZoneCell } from "./city-zoning.js";
import { CITY_SERVICE_TYPES } from "./city-services.js";
import { CITY_DEFAULT_TAX_RATES, CITY_TAX_RATE_LIMIT, normalizeCityTaxRates } from "./city-economy.js";
import { syncCityCitizens } from "./city-population.js";

const SIZE = 32;
const BUILDING_TYPES = new Set(["home","shop","industrial","administrative","service","park",...Object.keys(CITY_SERVICE_TYPES)]);
const isRecord = value => !!value && typeof value === "object" && !Array.isArray(value);
const validId = value => Number.isSafeInteger(value) && value > 0;
const validPoint = (x,y,integer=false) => Number.isFinite(x) && Number.isFinite(y)
  && x >= 0 && y >= 0 && x <= SIZE - 1 && y <= SIZE - 1
  && (!integer || (Number.isInteger(x) && Number.isInteger(y)));
const validOptionalPointPair = (x,y,allowNull=false) =>
  (x === undefined && y === undefined)
  || (allowNull && x === null && y === null)
  || validPoint(x,y,true);

export function isValidCitySave(v) {
  if (!isRecord(v) || v.schemaVersion !== 2
    || typeof v.cityId !== "string" || !v.cityId.trim() || v.cityId.length > 100
    || typeof v.name !== "string" || !v.name.trim() || v.name.length > 80
    || !Number.isSafeInteger(v.seed) || v.seed < 0 || v.seed > 0xffffffff
    || !Number.isSafeInteger(v.tick) || v.tick < 0
    || (v.minuteOfDay !== undefined && (!Number.isInteger(v.minuteOfDay) || v.minuteOfDay < 0 || v.minuteOfDay >= 1440))
    || !Number.isFinite(v.treasury) || Math.abs(v.treasury) > 1e12
    || !Number.isInteger(v.population) || v.population < 0 || v.population > 1e7
    || (v.happiness !== undefined && (!Number.isFinite(v.happiness) || v.happiness < 0 || v.happiness > 100))
    || !Array.isArray(v.grid) || v.grid.length !== SIZE
    || !v.grid.every(row => Array.isArray(row) && row.length === SIZE
      && row.every(tile => ["grass","road","building","water"].includes(tile) || isCityZoneCell(tile)))
    || !Array.isArray(v.buildings) || v.buildings.length > 1024
    || !Array.isArray(v.trees) || v.trees.length > 2048
    || !Array.isArray(v.citizens) || v.citizens.length > 10000
    || !Array.isArray(v.traffic) || v.traffic.length > 12
    || (v.zones !== undefined && (!Array.isArray(v.zones) || v.zones.length > 1024))
    || (v.animals !== undefined && (!Array.isArray(v.animals) || v.animals.length > 2048))
    || (v.stats !== undefined && !isRecord(v.stats))
    || (v.nextBuildingId !== undefined && !validId(v.nextBuildingId))
    || (v.nextTrafficId !== undefined && !validId(v.nextTrafficId))
    || (v.nextCitizenId !== undefined && !validId(v.nextCitizenId))
    || (v.taxRates !== undefined && (!isRecord(v.taxRates)
      || Object.keys(v.taxRates).some(key => !Object.hasOwn(CITY_DEFAULT_TAX_RATES,key))
      || Object.entries(v.taxRates).some(([key,rate]) => !Object.hasOwn(CITY_DEFAULT_TAX_RATES,key) || !Number.isInteger(rate) || rate < 0 || rate > CITY_TAX_RATE_LIMIT)))) return false;

  const buildings = new Set();
  const buildingIds = new Set();
  for (const building of v.buildings) {
    if (!isRecord(building) || !validId(building.id) || buildingIds.has(building.id)
      || !BUILDING_TYPES.has(building.type) || !validPoint(building.x,building.y,true)
      || v.grid[building.y][building.x] !== "building"
      || (building.level !== undefined && (!Number.isInteger(building.level) || building.level < 1 || building.level > 100))
      || (building.age !== undefined && (!Number.isFinite(building.age) || building.age < 0))
      || (building.residents !== undefined && (!Number.isInteger(building.residents) || building.residents < 0 || building.residents > 10000))
      || (building.zoneType !== undefined && !Object.hasOwn(CITY_ZONES,building.zoneType))) return false;
    const key = building.x + ":" + building.y;
    if (buildings.has(key)) return false;
    buildings.add(key);
    buildingIds.add(building.id);
  }

  const zones = new Set();
  for (const zone of v.zones || []) {
    if (!isRecord(zone) || !Object.hasOwn(CITY_ZONES,zone.type)
      || !validPoint(zone.x,zone.y,true)
      || v.grid[zone.y][zone.x] !== "zone-" + zone.type
      || (zone.createdAt !== undefined && (!Number.isSafeInteger(zone.createdAt) || zone.createdAt < 0 || zone.createdAt > v.tick))) return false;
    const key = zone.x + ":" + zone.y;
    if (zones.has(key) || buildings.has(key)) return false;
    zones.add(key);
  }

  for (let y=0;y<SIZE;y++) for (let x=0;x<SIZE;x++) {
    const tile=v.grid[y][x],key=x+":"+y;
    if (tile==="building" && !buildings.has(key)) return false;
    if (isCityZoneCell(tile) && Array.isArray(v.zones) && !zones.has(key)) return false;
  }

  for (const tree of v.trees) {
    if (!isRecord(tree) || !validPoint(tree.x,tree.y,true)
      || (tree.size !== undefined && (!Number.isFinite(tree.size) || tree.size <= 0 || tree.size > 20))) return false;
  }
  const residentialBuildingIds = new Set(v.buildings.filter(building => building.type === "home").map(building => building.id));
  for (const citizen of v.citizens) {
    if (!isRecord(citizen) || !validId(citizen.id) || !validPoint(citizen.x,citizen.y)
      || (citizen.homeId !== undefined && (!validId(citizen.homeId) || !residentialBuildingIds.has(citizen.homeId)))
      || !validOptionalPointPair(citizen.roadX,citizen.roadY)
      || !validOptionalPointPair(citizen.previousX,citizen.previousY,true)
      || !validOptionalPointPair(citizen.targetX,citizen.targetY,true)
      || (citizen.routeStep !== undefined && (!Number.isSafeInteger(citizen.routeStep) || citizen.routeStep < 0))
      || (citizen.heading !== undefined && !Number.isFinite(citizen.heading))
      || (citizen.phase !== undefined && !Number.isFinite(citizen.phase))
      || (citizen.pace !== undefined && (!Number.isFinite(citizen.pace) || citizen.pace < 0 || citizen.pace > 20))
      || (citizen.commuteWorkplaceId !== undefined && !validId(citizen.commuteWorkplaceId))
      || (citizen.commutePhase !== undefined && !["outbound","returning"].includes(citizen.commutePhase))
      || (citizen.commuteRouteStep !== undefined && (!Number.isSafeInteger(citizen.commuteRouteStep) || citizen.commuteRouteStep < 0 || citizen.commuteRouteStep >= SIZE * SIZE))
      || (citizen.commuteWait !== undefined && (!Number.isFinite(citizen.commuteWait) || citizen.commuteWait < 0 || citizen.commuteWait > 60))) return false;
  }
  for (const animal of v.animals || []) {
    if (!isRecord(animal) || !["cat","dog","bird"].includes(animal.type)
      || !validPoint(animal.x,animal.y)
      || (animal.phase !== undefined && !Number.isFinite(animal.phase))
      || (animal.pace !== undefined && (!Number.isFinite(animal.pace) || animal.pace < 0 || animal.pace > 20))) return false;
  }

  const trafficIds = new Set();
  for (const vehicle of v.traffic) {
    if (!isRecord(vehicle) || !validId(vehicle.id) || trafficIds.has(vehicle.id)
      || !validPoint(vehicle.x,vehicle.y)
      || v.grid[Math.round(vehicle.y)]?.[Math.round(vehicle.x)] !== "road"
      || !Number.isFinite(vehicle.speed) || vehicle.speed <= 0 || vehicle.speed > 5
      || !Number.isFinite(vehicle.heading) || !Number.isFinite(vehicle.headingX) || !Number.isFinite(vehicle.headingY)
      || !Number.isSafeInteger(vehicle.routeStep) || vehicle.routeStep < 0
      || typeof vehicle.color !== "string" || vehicle.color.length > 24
      || ((vehicle.targetX === null) !== (vehicle.targetY === null))
      || (vehicle.targetX !== null && (!validPoint(vehicle.targetX,vehicle.targetY,true) || v.grid[vehicle.targetY][vehicle.targetX] !== "road"))
      || ((vehicle.previousX === null) !== (vehicle.previousY === null))
      || (vehicle.previousX !== null && !validPoint(vehicle.previousX,vehicle.previousY,true))) return false;
    trafficIds.add(vehicle.id);
  }

  if (v.nextBuildingId !== undefined && buildingIds.size && v.nextBuildingId <= Math.max(...buildingIds)) return false;
  if (v.nextTrafficId !== undefined && trafficIds.size && v.nextTrafficId <= Math.max(...trafficIds)) return false;
  const citizenIds = new Set(v.citizens.map(citizen => citizen.id));
  if (citizenIds.size !== v.citizens.length) return false;
  if (v.nextCitizenId !== undefined && citizenIds.size && v.nextCitizenId <= Math.max(...citizenIds)) return false;
  if (v.stats) {
    for (const key of ["income","expenses","net","taxRevenue","maintenance","serviceUpkeep","jobs","traffic","utilityCoverage","publicServiceCoverage","overallCoverage","commutingWorkers","commuteCoverage","averageCommuteDistance","averageCongestionDelay","unreachableWorkers"]) {
      if (v.stats[key] !== undefined && !Number.isFinite(v.stats[key])) return false;
    }
    if (v.stats.serviceCoverage !== undefined
      && (!isRecord(v.stats.serviceCoverage) || !Object.values(v.stats.serviceCoverage).every(Number.isFinite))) return false;
    for (const key of ["commutingWorkers","unreachableWorkers"]) {
      if (v.stats[key] !== undefined && (!Number.isSafeInteger(v.stats[key]) || v.stats[key] < 0 || v.stats[key] > 1e7)) return false;
    }
    if (v.stats.commuteCoverage !== undefined && (v.stats.commuteCoverage < 0 || v.stats.commuteCoverage > 100)) return false;
    if (v.stats.averageCommuteDistance !== undefined && (v.stats.averageCommuteDistance < 0 || v.stats.averageCommuteDistance > SIZE * SIZE)) return false;
    if (v.stats.averageCongestionDelay !== undefined && (v.stats.averageCongestionDelay < 0 || v.stats.averageCongestionDelay > 150)) return false;
  }
  return true;
}

export function normalizeCitySaveData(value) {
  if (!isValidCitySave(value)) return null;
  const city = {
    ...value,
    zones: Array.isArray(value.zones) ? value.zones : value.grid.flatMap((row,y)=>row.flatMap((tile,x)=>isCityZoneCell(tile)?[{x,y,type:tile.slice(5),createdAt:0}]:[])),
    animals: Array.isArray(value.animals) ? value.animals : [],
    minuteOfDay: Number.isInteger(value.minuteOfDay) ? value.minuteOfDay : 495,
    happiness: Number.isFinite(value.happiness) ? value.happiness : 100,
    nextBuildingId: validId(value.nextBuildingId) ? value.nextBuildingId : Math.max(0,...value.buildings.map(item=>item.id))+1,
    nextTrafficId: validId(value.nextTrafficId) ? value.nextTrafficId : Math.max(0,...value.traffic.map(item=>item.id))+1,
    nextCitizenId: validId(value.nextCitizenId) ? value.nextCitizenId : Math.max(0,...value.citizens.map(item=>item.id))+1,
    taxRates: normalizeCityTaxRates(value.taxRates),
    stats: { income:0, expenses:0, jobs:0, traffic:0, ...(isRecord(value.stats) ? value.stats : {}) }
  };
  for (const building of city.buildings) {
    building.level ??= 1;
    building.age ??= 0;
    building.residents ??= 0;
  }
  for (const citizen of city.citizens) {
    citizen.phase ??= 0;
    citizen.pace ??= 0.1;
    citizen.homeId ??= city.buildings.find(building => building.type === "home")?.id;
    citizen.roadX ??= Math.round(citizen.x);
    citizen.roadY ??= Math.round(citizen.y);
    citizen.previousX ??= null;
    citizen.previousY ??= null;
    citizen.targetX ??= null;
    citizen.targetY ??= null;
    citizen.routeStep ??= 0;
    citizen.heading ??= 0;
  }
  for (const animal of city.animals) {
    animal.phase ??= 0;
    animal.pace ??= 0.1;
  }
  return city;
}

/** Import either a current v2 city snapshot, a v1 local save, or an exported backup envelope. */
export function migrateCitySave(value) {
  const isBackup = isRecord(value) && value.format === "mshin-city-save";
  if (isBackup && (value.version !== 2 || typeof value.exportedAt !== "string" || value.exportedAt.length > 40 || !Number.isFinite(Date.parse(value.exportedAt)))) return null;
  const snapshot = isBackup ? value.city : value;
  if (isValidCitySave(snapshot)) return normalizeCitySaveData(snapshot);
  if (!isRecord(snapshot) || snapshot.schemaVersion !== 1
    || typeof snapshot.cityId !== "string" || !snapshot.cityId.trim()
    || typeof snapshot.name !== "string" || !snapshot.name.trim()
    || !Number.isSafeInteger(snapshot.seed) || snapshot.seed < 0 || snapshot.seed > 0xffffffff
    || !Number.isSafeInteger(snapshot.tick) || snapshot.tick < 0
    || !Number.isFinite(snapshot.treasury) || Math.abs(snapshot.treasury) > 1e12
    || !Number.isInteger(snapshot.population) || snapshot.population < 0 || snapshot.population > 1e7
    || !Array.isArray(snapshot.grid) || snapshot.grid.length !== SIZE
    || !snapshot.grid.every(row => Array.isArray(row) && row.length === SIZE
      && row.every(tile => ["grass","road","building","water"].includes(tile)))
    || !Array.isArray(snapshot.buildings) || !Array.isArray(snapshot.trees)) return null;

  const buildings = snapshot.buildings.map(building => isRecord(building) ? {
    ...building,
    level: Number.isInteger(building.level) && building.level > 0 ? building.level : 1,
    age: Number.isFinite(building.age) && building.age >= 0 ? building.age : 0,
    residents: Number.isInteger(building.residents) && building.residents >= 0 ? building.residents : 0
  } : building);
  const migrated = {
    schemaVersion: 2,
    cityId: snapshot.cityId.slice(0,100),
    name: snapshot.name.slice(0,80),
    seed: snapshot.seed,
    tick: snapshot.tick,
    minuteOfDay: Number.isInteger(snapshot.minuteOfDay) && snapshot.minuteOfDay >= 0 && snapshot.minuteOfDay < 1440 ? snapshot.minuteOfDay : 495,
    treasury: snapshot.treasury,
    population: snapshot.population,
    happiness: Number.isFinite(snapshot.happiness) && snapshot.happiness >= 0 && snapshot.happiness <= 100 ? snapshot.happiness : 76,
    grid: snapshot.grid.map(row => [...row]),
    buildings,
    zones: [],
    trees: snapshot.trees.map(tree => isRecord(tree) ? {...tree,size:Number.isFinite(tree.size)&&tree.size>0?tree.size:1} : tree),
    citizens: [],
    traffic: [],
    nextTrafficId: 1,
    nextCitizenId: 1,
    animals: [],
    nextBuildingId: validId(snapshot.nextBuildingId) ? snapshot.nextBuildingId : Math.max(0,...buildings.map(item=>item?.id||0))+1,
    taxRates: {...CITY_DEFAULT_TAX_RATES},
    stats: {
      income: Number.isFinite(snapshot.stats?.income) ? snapshot.stats.income : 0,
      expenses: Number.isFinite(snapshot.stats?.expenses) ? snapshot.stats.expenses : 0,
      net: 0,
      taxRevenue: 0,
      maintenance: 0,
      serviceUpkeep: 0,
      jobs: Number.isFinite(snapshot.stats?.jobs) ? snapshot.stats.jobs : 0,
      traffic: 0
    }
  };
  if (!isValidCitySave(migrated)) return null;
  syncCityCitizens(migrated);
  return isValidCitySave(migrated) ? migrated : null;
}

export function createCitySaveBackup(city, exportedAt = new Date().toISOString()) {
  if (!isValidCitySave(city) || typeof exportedAt !== "string" || exportedAt.length > 40 || !Number.isFinite(Date.parse(exportedAt))) {
    throw new TypeError("A valid city snapshot is required for backup export");
  }
  return {
    format: "mshin-city-save",
    version: 2,
    exportedAt,
    city: JSON.parse(JSON.stringify(normalizeCitySaveData(city)))
  };
}

