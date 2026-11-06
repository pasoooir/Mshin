const clamp=(v,min,max)=>Math.max(min,Math.min(max,v));
const wrap=(v,period)=>((v%period)+period)%period;

/**
 * Deterministic lane-changing traffic controller.
 * Uses direct nearest-gap scans instead of allocating/map/filter/sort arrays
 * for every AI car on every fixed simulation step.
 */
export function stepTrafficVehicle(vehicle,{trackLength,lanes=[-42,0,42],neighbors=[],player=null,curvature=0,dt=1/60,cruiseSpeed=220,maxSpeed=null,acceleration=85,braking=150,distanceScale=1/430}={}) {
 const length=Math.max(1,Number.isFinite(trackLength)?trackLength:1);
 const step=clamp(Number.isFinite(dt)?dt:0,0,.05);
 const laneSet=lanes;
 if(!laneSet.length)return vehicle;
 let minLane=Infinity,maxLane=-Infinity;
 for(let i=0;i<laneSet.length;i++){const lane=laneSet[i];if(!Number.isFinite(lane))continue;minLane=Math.min(minLane,lane);maxLane=Math.max(maxLane,lane)}
 if(!Number.isFinite(minLane)){vehicle.lateral=0;return vehicle}
 const currentLane=Number.isInteger(vehicle.laneIndex)?clamp(vehicle.laneIndex,0,laneSet.length-1):0;
 vehicle.laneIndex=currentLane;
 vehicle.changeCooldown=Math.max(0,(vehicle.changeCooldown||0)-step);
 vehicle.distance=wrap(Number.isFinite(vehicle.distance)?vehicle.distance:0,length);
 vehicle.speed=Math.max(0,Number.isFinite(vehicle.speed)?vehicle.speed:0);
 vehicle.lateral=Number.isFinite(vehicle.lateral)?vehicle.lateral:laneSet[currentLane];
 vehicle.lateralVelocity=Number.isFinite(vehicle.lateralVelocity)?vehicle.lateralVelocity:0;
 const aheadInLane=laneIndex=>{
  const target=laneSet[laneIndex],maxGap=Math.min(260,Math.max(100,vehicle.speed*.95));
  let nearest=null,nearestGap=maxGap;
  const consider=other=>{
   if(!other||other===vehicle)return;
   const gap=wrap((Number(other.distance)||0)-vehicle.distance,length);
   if(gap>1&&gap<nearestGap&&Math.abs((Number(other.lateral)||0)-target)<24){nearest=other;nearestGap=gap}
  };
  for(let i=0;i<neighbors.length;i++)consider(neighbors[i]);
  consider(player);
  return nearest?{other:nearest,gap:nearestGap}:null;
 };
 let targetLane=Number.isInteger(vehicle.targetLane)?clamp(vehicle.targetLane,0,laneSet.length-1):currentLane;
 if(vehicle.changeCooldown<=0){
  const currentAhead=aheadInLane(currentLane),blocked=currentAhead&&currentAhead.gap<Math.max(78,vehicle.speed*.48);
  if(blocked){
   let bestLane=-1,bestGap=-Infinity;
   for(let i=0;i<laneSet.length;i++){
    if(i===currentLane)continue;
    const ahead=aheadInLane(i),gap=ahead?ahead.gap:length;
    if(gap>Math.max(115,vehicle.speed*.72)&&gap>bestGap){bestLane=i;bestGap=gap}
   }
   if(bestLane>=0){targetLane=bestLane;vehicle.targetLane=targetLane;vehicle.changeCooldown=1.1+(vehicle.id%3)*.23}
  }else if(targetLane!==currentLane&&Math.abs(vehicle.lateral-laneSet[targetLane])<5){vehicle.laneIndex=targetLane;vehicle.changeCooldown=.7}
  else if(targetLane===currentLane&&Math.abs(vehicle.lateral-laneSet[currentLane])<5){
   const seed=(Math.floor(vehicle.distance/180)+(vehicle.id||0)*7)%17;
   if(seed===0&&laneSet.length>1){
    for(let i=0;i<laneSet.length;i++){if(i===currentLane||aheadInLane(i))continue;targetLane=i;vehicle.targetLane=targetLane;vehicle.changeCooldown=2.4;break}
   }
  }
 }
 const laneTarget=laneSet[targetLane],laneGap=aheadInLane(targetLane);
 const topSpeed=Number.isFinite(maxSpeed)&&maxSpeed>0?maxSpeed:Math.max(80,cruiseSpeed*1.08);
 const safeSpeed=laneGap?Math.min(cruiseSpeed,Math.max(65,cruiseSpeed*(laneGap.gap/Math.max(90,vehicle.speed*.65)))):cruiseSpeed;
 const bendFactor=1-clamp(Math.abs(Number(curvature)||0)*1.8,0,.42),desiredSpeed=clamp(Math.max(70,safeSpeed*bendFactor),0,topSpeed);
 const accelerationLimit=Math.max(0,Number.isFinite(acceleration)?acceleration:85),brakingLimit=Math.max(0,Number.isFinite(braking)?braking:150);
 const longitudinalAcceleration=step>0?clamp((desiredSpeed-vehicle.speed)/step,-brakingLimit,accelerationLimit):0;
 vehicle.speed=clamp(vehicle.speed+longitudinalAcceleration*step,0,topSpeed);
 const lateralError=laneTarget-vehicle.lateral,lateralAccel=clamp(lateralError*2.6-vehicle.lateralVelocity*3.2,-95,95);
 vehicle.lateralVelocity=clamp(vehicle.lateralVelocity+lateralAccel*step,-38,38);
 vehicle.lateral=clamp(vehicle.lateral+vehicle.lateralVelocity*step,minLane-12,maxLane+12);
 if(Math.abs(lateralError)<2.2&&Math.abs(vehicle.lateralVelocity)<3){vehicle.lateral=laneTarget;vehicle.lateralVelocity=0;vehicle.laneIndex=targetLane}
 const worldDistanceScale=Number.isFinite(distanceScale)&&distanceScale>0?distanceScale:1/430;
 vehicle.distance=wrap(vehicle.distance+vehicle.speed*step*worldDistanceScale,length);
 vehicle.yaw=clamp((vehicle.yaw||0)+clamp(vehicle.lateralVelocity*.003,-.16,.16)*step,-.28,.28);
 return vehicle;
}
export function trafficFollowingGap(speed){return clamp(Math.max(72,Math.max(0,speed)*.58),72,190)}
