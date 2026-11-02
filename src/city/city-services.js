export const CITY_SERVICE_TYPES = Object.freeze({
  power: Object.freeze({ label:"برق", category:"utility", radius:10, cost:4600, upkeep:42, color:"#e8c65f" }),
  water: Object.freeze({ label:"آب", category:"utility", radius:9, cost:3900, upkeep:34, color:"#68b9dc" }),
  sewage: Object.freeze({ label:"فاضلاب", category:"utility", radius:8, cost:4200, upkeep:38, color:"#9aab91" }),
  waste: Object.freeze({ label:"پسماند", category:"utility", radius:11, cost:3400, upkeep:46, color:"#b9b56d" }),
  police: Object.freeze({ label:"پلیس", category:"public", radius:8, cost:3700, upkeep:52, color:"#6d8ed1" }),
  fire: Object.freeze({ label:"آتش‌نشانی", category:"public", radius:8, cost:3600, upkeep:48, color:"#d96e58" }),
  health: Object.freeze({ label:"درمان", category:"public", radius:8, cost:4100, upkeep:54, color:"#e78c9c" }),
  education: Object.freeze({ label:"آموزش", category:"public", radius:9, cost:4300, upkeep:45, color:"#9a85c9" })
});

const distance=(a,b)=>Math.hypot(a.x-b.x,a.y-b.y);
const clamp=(v,min,max)=>Math.max(min,Math.min(max,v));

/** Calculate local coverage for every building and city-wide infrastructure/service ratios. */
export function computeCityServices(city) {
  const targets=(city.buildings||[]).filter(building=>!Object.hasOwn(CITY_SERVICE_TYPES,building.type));
  const providers=Object.fromEntries(Object.keys(CITY_SERVICE_TYPES).map(type=>[
    type,(city.buildings||[]).filter(building=>building.type===type)
  ]));
  const coverage={};
  let upkeep=0;
  for(const [type,definition] of Object.entries(CITY_SERVICE_TYPES)){
    const stations=providers[type];
    upkeep+=stations.length*definition.upkeep;
    const served=targets.filter(target=>stations.some(station=>distance(target,station)<=definition.radius)).length;
    coverage[type]=targets.length?Math.round(served/targets.length*100):0;
  }
  for(const building of targets){
    building.serviceCoverage={};
    for(const [type,definition] of Object.entries(CITY_SERVICE_TYPES)){
      building.serviceCoverage[type]=providers[type].some(station=>distance(building,station)<=definition.radius);
    }
  }
  const utilityTypes=Object.entries(CITY_SERVICE_TYPES).filter(([,v])=>v.category==="utility").map(([k])=>k);
  const publicTypes=Object.entries(CITY_SERVICE_TYPES).filter(([,v])=>v.category==="public").map(([k])=>k);
  const average=types=>Math.round(types.reduce((sum,type)=>sum+coverage[type],0)/types.length);
  return {
    coverage,
    utilityCoverage:average(utilityTypes),
    publicServiceCoverage:average(publicTypes),
    overallCoverage:Math.round((average(utilityTypes)+average(publicTypes))/2),
    upkeep
  };
}

export function cityServiceStatus(city) {
  const result=computeCityServices(city);
  return Object.freeze({
    utilityCoverage:clamp(result.utilityCoverage,0,100),
    publicServiceCoverage:clamp(result.publicServiceCoverage,0,100),
    overallCoverage:clamp(result.overallCoverage,0,100),
    coverage:{...result.coverage},
    upkeep:result.upkeep
  });
}
