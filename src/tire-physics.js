const clamp=(value,min,max)=>Math.max(min,Math.min(max,value));

/**
 * Resolve a rally tyre's combined longitudinal and lateral force demand.
 * Speed/acceleration use the browser simulation's world-unit calibration.
 * The friction circle is shared by steering, throttle and braking; steering
 * authority therefore falls naturally with speed and low-grip surfaces.
 */
export function resolveTireForces({speed,lateralVelocity,steer,throttle,brake,grip,deltaSeconds}) {
 const v=Number.isFinite(speed)?Math.max(0,speed):0;
 const lateral=Number.isFinite(lateralVelocity)?lateralVelocity:0;
 const steering=clamp(Number.isFinite(steer)?steer:0,-1,1);
 const dt=clamp(Number.isFinite(deltaSeconds)?deltaSeconds:0,0,.1);
 const surfaceGrip=clamp(Number.isFinite(grip)?grip:1,.35,1.15);
 const capacity=85*surfaceGrip;
 const longitudinalDemand=brake?65:(throttle?30:0);
 const availableLateral=Math.sqrt(Math.max(0,capacity*capacity-longitudinalDemand*longitudinalDemand));

 // Bicycle-model steering: yaw rate follows speed, steering angle and wheelbase.
 const wheelbase=128;
 const maxRoadWheelAngle=.48;
 const roadWheelAngle=steering*maxRoadWheelAngle;
 const requestedYawRate=v>0?(v/wheelbase)*Math.tan(roadWheelAngle):0;
 const requestedCorneringAcceleration=Math.abs(v*requestedYawRate);
 const corneringScale=Math.min(1,availableLateral/Math.max(.001,requestedCorneringAcceleration));

 // Relaxation toward a speed-dependent lateral velocity gives the chassis
 // progressive slip instead of an instantaneous, arcade-like lane snap.
 const targetLateralVelocity=steering*Math.min(150,v*.42)/Math.max(.65,surfaceGrip);
 const steeringResponse=1-Math.exp(-dt*(Math.abs(steering)<.001?7:5.5));
 const requestedLateralAcceleration=(targetLateralVelocity-lateral)*steeringResponse/Math.max(dt,.001);
 const lateralAcceleration=clamp(requestedLateralAcceleration,-availableLateral,availableLateral);
 const slipAngle=Math.atan2(lateral,Math.max(v,1));

 // Slip contributes a damped yaw correction, but the final yaw remains inside
 // the lateral force envelope so it cannot bypass the tyre friction circle.
 const slipCorrection=slipAngle*1.1*clamp((v-70)/100,0,1);
 const yawLimit=availableLateral/Math.max(v,1);
 const yawRateTarget=clamp(requestedYawRate*corneringScale+slipCorrection,-yawLimit,yawLimit);
 const lateralScale=Math.min(1,availableLateral/Math.max(.001,Math.abs(requestedLateralAcceleration)));
 return {
  lateralAcceleration,
  yawRateTarget,
  slipAngle,
  tireCapacity:capacity,
  availableLateral,
  lateralScale,
  corneringScale,
  longitudinalDemand,
  // Longitudinal braking remains calibrated in game speed-units; grip scales
  // the available deceleration while preserving the dry-road baseline.
  brakingDeceleration:brake?470*surfaceGrip:0,
  frictionUtilization:Math.min(1,Math.hypot(longitudinalDemand,lateralAcceleration)/Math.max(capacity,.001))
 };
}
