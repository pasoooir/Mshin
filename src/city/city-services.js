export const CITY_SERVICE_TYPES = Object.freeze({
  power: Object.freeze({ label:"POWER", category:"utility", radius:10, capacity:120, cost:4600, upkeep:42, color:"#e8c65f" }),
  water: Object.freeze({ label:"WATER", category:"utility", radius:9, capacity:100, cost:3900, upkeep:34, color:"#68b9dc" }),
  sewage: Object.freeze({ label:"SEWAGE", category:"utility", radius:8, capacity:90, cost:4200, upkeep:38, color:"#9aab91" }),
  waste: Object.freeze({ label:"WASTE", category:"utility", radius:11, capacity:140, cost:3400, upkeep:46, color:"#b9b56d" }),
  police: Object.freeze({ label:"POLICE", category:"public", radius:8, capacity:100, cost:3700, upkeep:52, color:"#6d8ed1" }),
  fire: Object.freeze({ label:"FIRE", category:"public", radius:8, capacity:100, cost:3600, upkeep:48, color:"#d96e58" }),
  health: Object.freeze({ label:"HEALTHCARE", category:"public", radius:8, capacity:80, cost:4100, upkeep:54, color:"#e78c9c" }),
  education: Object.freeze({ label:"EDUCATION", category:"public", radius:9, capacity:100, cost:4300, upkeep:45, color:"#9a85c9" })
});
const distance=(a,b)=>Math.hypot(a.x-b.x,a.y-b.y);
const clamp=(v,min,max)=>Math.max(min,Math.min(max,v));
const demandFor=building=>{
  if(building.type==="home")return Number.isFinite(building.residents)?Math.max(0,building.residents):12;
  return ({shop:10,industrial:18,administrative:8,service:6,park:3})[building.type]??8;
};

/** Calculate geographic reach and finite service capacity in deterministic nearest-first order. */
export function computeCityServices(city) {
  const buildings=Array.isArray(city?.buildings)?city.buildings:[];
  const targets=buildings.filter(building=>!Object.hasOwn(CITY_SERVICE_TYPES,building.type));
  const providers=Object.fromEntries(Object.keys(CITY_SERVICE_TYPES).map(type=>[type,buildings.filter(building=>building.type===type)]));
  const coverage={},demandCoverage={},capacityUsage={};
  let upkeep=0;
  for(const [type,definition] of Object.entries(CITY_SERVICE_TYPES)){
    const stations=providers[type];upkeep+=stations.length*definition.upkeep;
    const geographicallyServed=targets.filter(target=>stations.some(station=>distance(target,station)<=definition.radius)).length;
    coverage[type]=targets.length?Math.round(geographicallyServed/targets.length*100):0;
    const remaining=new Map(stations.map(station=>[station,definition.capacity]));
    const demandByTarget=new Map(targets.map(target=>[target,demandFor(target)]));
    const servedByTarget=new Map(targets.map(target=>[target,0]));
    const totalDemand=[...demandByTarget.values()].reduce((sum,value)=>sum+value,0);
    const routes=targets.filter(target=>demandByTarget.get(target)>0).flatMap(target=>stations
      .filter(station=>distance(target,station)<=definition.radius)
      .map(station=>({target,station,distance:distance(target,station)})))
      .sort((a,b)=>a.distance-b.distance
        ||(Number(a.target.id)||0)-(Number(b.target.id)||0)
        ||(Number(a.station.id)||0)-(Number(b.station.id)||0));
    for(const {target,station} of routes){
      const unserved=demandByTarget.get(target)-servedByTarget.get(target);
      const available=remaining.get(station)||0;
      const allocated=Math.min(unserved,available);
      if(allocated<=0)continue;
      servedByTarget.set(target,servedByTarget.get(target)+allocated);
      remaining.set(station,available-allocated);
    }
    const servedDemand=[...servedByTarget.values()].reduce((sum,value)=>sum+value,0);
    for(const target of targets){
      if(!target.serviceSatisfaction)target.serviceSatisfaction={};
      const demand=demandByTarget.get(target);
      target.serviceSatisfaction[type]=demand>0?Math.round(servedByTarget.get(target)/demand*100):100;
    }
    demandCoverage[type]=totalDemand?Math.round(servedDemand/totalDemand*100):0;
    capacityUsage[type]=stations.reduce((sum,station)=>sum+definition.capacity-(remaining.get(station)||0),0);
  }
  for(const building of targets){
    building.serviceCoverage={};
    for(const [type,definition] of Object.entries(CITY_SERVICE_TYPES)){
      building.serviceCoverage[type]=providers[type].some(station=>distance(building,station)<=definition.radius);
    }
  }
  const utilityTypes=Object.entries(CITY_SERVICE_TYPES).filter(([,v])=>v.category==="utility").map(([k])=>k);
  const publicTypes=Object.entries(CITY_SERVICE_TYPES).filter(([,v])=>v.category==="public").map(([k])=>k);
  const average=types=>Math.round(types.reduce((sum,type)=>sum+demandCoverage[type],0)/types.length);
  return {coverage,demandCoverage,capacityUsage,utilityCoverage:average(utilityTypes),publicServiceCoverage:average(publicTypes),overallCoverage:Math.round((average(utilityTypes)+average(publicTypes))/2),upkeep};
}

/** Return resident-weighted satisfaction across all finite utility and public-service types. */
export function computeCityResidentServiceSatisfaction(city) {
  const homes = (Array.isArray(city?.buildings) ? city.buildings : [])
    .filter(building => building.type === "home" && Number.isFinite(building.residents) && building.residents > 0);
  const residentCount = homes.reduce((sum, home) => sum + home.residents, 0);
  if (!residentCount) return 0;
  const serviceTypes = Object.keys(CITY_SERVICE_TYPES);
  const satisfaction = homes.reduce((sum, home) => {
    const values = home.serviceSatisfaction || {};
    const average = serviceTypes.reduce((total, type) => total + clamp(Number(values[type]) || 0, 0, 100), 0) / serviceTypes.length;
    return sum + average * home.residents;
  }, 0);
  return Math.round(satisfaction / residentCount);
}

export function cityServiceStatus(city) {
  const result=computeCityServices(city);
  return Object.freeze({
    utilityCoverage:clamp(result.utilityCoverage,0,100),
    publicServiceCoverage:clamp(result.publicServiceCoverage,0,100),
    overallCoverage:clamp(result.overallCoverage,0,100),
    coverage:{...result.coverage},demandCoverage:{...result.demandCoverage},
    capacityUsage:{...result.capacityUsage},upkeep:result.upkeep
  });
}
