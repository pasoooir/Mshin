export const CITY_SERVICE_TYPES = Object.freeze({
  power: Object.freeze({ label:"برق", category:"utility", radius:10, capacity:120, cost:4600, upkeep:42, color:"#e8c65f" }),
  water: Object.freeze({ label:"آب", category:"utility", radius:9, capacity:100, cost:3900, upkeep:34, color:"#68b9dc" }),
  sewage: Object.freeze({ label:"فاضلاب", category:"utility", radius:8, capacity:90, cost:4200, upkeep:38, color:"#9aab91" }),
  waste: Object.freeze({ label:"پسماند", category:"utility", radius:11, capacity:140, cost:3400, upkeep:46, color:"#b9b56d" }),
  police: Object.freeze({ label:"پلیس", category:"public", radius:8, capacity:100, cost:3700, upkeep:52, color:"#6d8ed1" }),
  fire: Object.freeze({ label:"آتش‌نشانی", category:"public", radius:8, capacity:100, cost:3600, upkeep:48, color:"#d96e58" }),
  health: Object.freeze({ label:"درمان", category:"public", radius:8, capacity:80, cost:4100, upkeep:54, color:"#e78c9c" }),
  education: Object.freeze({ label:"آموزش", category:"public", radius:9, capacity:100, cost:4300, upkeep:45, color:"#9a85c9" })
});
const distance=(a,b)=>Math.hypot(a.x-b.x,a.y-b.y);
const clamp=(v,min,max)=>Math.max(min,Math.min(max,v));
const demandFor=building=>{
  if(building.type==="home")return Math.max(1,Number.isFinite(building.residents)?building.residents:12);
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
    let totalDemand=0,servedDemand=0;
    for(const target of targets){
      const demand=demandFor(target);totalDemand+=demand;let unserved=demand;
      const nearby=stations.filter(station=>distance(target,station)<=definition.radius)
        .map(station=>({station,distance:distance(target,station)}))
        .sort((a,b)=>a.distance-b.distance||(Number(a.station.id)||0)-(Number(b.station.id)||0));
      for(const {station} of nearby){
        if(unserved<=0)break;
        const available=remaining.get(station)||0,allocated=Math.min(available,unserved);
        remaining.set(station,available-allocated);unserved-=allocated;
      }
      const served=demand-unserved;servedDemand+=served;
      if(!target.serviceSatisfaction)target.serviceSatisfaction={};
      target.serviceSatisfaction[type]=Math.round(served/demand*100);
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
