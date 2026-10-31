const clamp=(v,min,max)=>Math.max(min,Math.min(max,v));
const wrap=(v,period)=>((v%period)+period)%period;
const signedGap=(from,to,period)=>wrap(to-from+period/2,period)-period/2;

/**
 * Deterministic lane-changing traffic controller.
 * distance is measured along a closed circuit; lateral is the signed lane offset.
 */
export function stepTrafficVehicle(vehicle,{trackLength,lanes=[-42,0,42],neighbors=[],player=null,curvature=0,dt=1/60,cruiseSpeed=220}={}) {
 const length=Math.max(1,Number.isFinite(trackLength)?trackLength:1);
 const step=clamp(Number.isFinite(dt)?dt:0,0,.05);
 const laneSet=lanes.filter(Number.isFinite);
 if(!laneSet.length)laneSet.push(0);
 const currentLane=Number.isInteger(vehicle.laneIndex)?clamp(vehicle.laneIndex,0,laneSet.length-1):0;
 vehicle.laneIndex=currentLane;
 vehicle.changeCooldown=Math.max(0,(vehicle.changeCooldown||0)-step);
 vehicle.distance=wrap(Number.isFinite(vehicle.distance)?vehicle.distance:0,length);
 vehicle.speed=Math.max(0,Number.isFinite(vehicle.speed)?vehicle.speed:0);
 vehicle.lateral=Number.isFinite(vehicle.lateral)?vehicle.lateral:laneSet[currentLane];
 vehicle.lateralVelocity=Number.isFinite(vehicle.lateralVelocity)?vehicle.lateralVelocity:0;
 const all=[...neighbors, ...(player?[player]:[])].filter(other=>other&&other!==vehicle);
 const aheadInLane=(laneIndex)=>all.map(other=>({other,gap:wrap((Number(other.distance)||0)-vehicle.distance,length)}))
   .filter(item=>item.gap>1&&item.gap<Math.min(260,Math.max(100,vehicle.speed*.95))&&Math.abs((Number(item.other.lateral)||0)-laneSet[laneIndex])<24)
   .sort((a,b)=>a.gap-b.gap)[0]||null;
 let targetLane=Number.isInteger(vehicle.targetLane)?clamp(vehicle.targetLane,0,laneSet.length-1):currentLane;
 if(vehicle.changeCooldown<=0){
  const currentAhead=aheadInLane(currentLane);
  const blocked=currentAhead&&currentAhead.gap<Math.max(78,vehicle.speed*.48);
  if(blocked){
   const choices=laneSet.map((_,index)=>({index,ahead:aheadInLane(index)}))
    .filter(choice=>choice.index!==currentLane&&(!choice.ahead||choice.ahead.gap>Math.max(115,vehicle.speed*.72)))
    .sort((a,b)=>(b.ahead?.gap??length)-(a.ahead?.gap??length));
   if(choices.length){targetLane=choices[0].index;vehicle.targetLane=targetLane;vehicle.changeCooldown=1.1+(vehicle.id%3)*.23;}
  } else if(targetLane!==currentLane&&Math.abs(vehicle.lateral-laneSet[targetLane])<5){vehicle.laneIndex=targetLane;vehicle.changeCooldown=.7;}
  else if(targetLane===currentLane&&Math.abs(vehicle.lateral-laneSet[currentLane])<5&&vehicle.changeCooldown<=0){
   // Small deterministic lane variation prevents traffic from remaining in a fixed procession.
   const seed=(Math.floor(vehicle.distance/180)+(vehicle.id||0)*7)%17;
   if(seed===0&&laneSet.length>1){const candidates=laneSet.map((_,i)=>i).filter(i=>i!==currentLane&&!aheadInLane(i));if(candidates.length){targetLane=candidates[0];vehicle.targetLane=targetLane;vehicle.changeCooldown=2.4;}}
  }
 }
 const laneTarget=laneSet[targetLane];
 const laneGap=aheadInLane(targetLane);
 const safeSpeed=laneGap?Math.min(cruiseSpeed,Math.max(65,cruiseSpeed*(laneGap.gap/Math.max(90,vehicle.speed*.65)))):cruiseSpeed;
 const bendFactor=1-clamp(Math.abs(Number(curvature)||0)*1.8,0,.42);
 const desiredSpeed=Math.max(70,safeSpeed*bendFactor);
 const accel=clamp((desiredSpeed-vehicle.speed)*1.35,-150,85);
 vehicle.speed=clamp(vehicle.speed+accel*step,45,Math.max(80,cruiseSpeed*1.08));
 const lateralError=laneTarget-vehicle.lateral;
 const lateralAccel=clamp(lateralError*2.6-vehicle.lateralVelocity*3.2,-95,95);
 vehicle.lateralVelocity=clamp(vehicle.lateralVelocity+lateralAccel*step,-38,38);
 vehicle.lateral=clamp(vehicle.lateral+vehicle.lateralVelocity*step,Math.min(...laneSet)-12,Math.max(...laneSet)+12);
 if(Math.abs(lateralError)<2.2&&Math.abs(vehicle.lateralVelocity)<3){vehicle.lateral=laneTarget;vehicle.lateralVelocity=0;vehicle.laneIndex=targetLane;}
 vehicle.distance=wrap(vehicle.distance+vehicle.speed/430*step,length);
 vehicle.yaw=clamp((vehicle.yaw||0)+clamp(vehicle.lateralVelocity*.003,-.16,.16)*step,-.28,.28);
 return vehicle;
}

export function trafficFollowingGap(speed){return clamp(Math.max(72,Math.max(0,speed)*.58),72,190);}
