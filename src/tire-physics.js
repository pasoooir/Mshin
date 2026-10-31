const clamp=(value,min,max)=>Math.max(min,Math.min(max,value));

/**
 * Resolve the browser car's combined longitudinal/lateral tire demand.
 * Speeds and accelerations use the game's world-unit calibration.
 */
export function resolveTireForces({speed,lateralVelocity,steer,throttle,brake,grip,deltaSeconds}) {
 const v=Number.isFinite(speed)?speed:0;
 const lateral=Number.isFinite(lateralVelocity)?lateralVelocity:0;
 const steering=clamp(Number.isFinite(steer)?steer:0,-1,1);
 const dt=clamp(Number.isFinite(deltaSeconds)?deltaSeconds:0,0,.1);
 const surfaceGrip=clamp(Number.isFinite(grip)?grip:1,.35,1.15);
 const capacity=85*surfaceGrip;
 const longitudinalDemand=brake?65:(throttle?30:0);
 const targetLateralVelocity=steering*(38+Math.abs(v)*.29)/Math.max(.55,surfaceGrip);
 const steeringResponse=1-Math.exp(-dt*(Math.abs(steering)<.001?9.5:11.5));
 const requestedLateralAcceleration=(targetLateralVelocity-lateral)*steeringResponse/Math.max(dt,.001);
 const lateralDemand=Math.abs(requestedLateralAcceleration);
 const lateralScale=Math.min(1,capacity/Math.max(.001,Math.hypot(longitudinalDemand,lateralDemand)));
 const lateralAcceleration=clamp(requestedLateralAcceleration*lateralScale,-capacity,capacity);
 const slipAngle=Math.atan2(lateral,Math.max(Math.abs(v),1));
 const requestedYawRate=steering*(.55+Math.abs(v)/500);
 const corneringDemand=Math.abs(v*requestedYawRate);
 const corneringScale=Math.min(1,capacity/Math.max(.001,Math.hypot(longitudinalDemand,corneringDemand)));
 const slipYaw=clamp(slipAngle*1.1,-.9,.9)*clamp((Math.abs(v)-70)/100,0,1);
 return {lateralAcceleration,yawRateTarget:requestedYawRate*corneringScale+slipYaw,slipAngle,tireCapacity:capacity,lateralScale,corneringScale};
}
