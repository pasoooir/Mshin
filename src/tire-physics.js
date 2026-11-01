const clamp=(value,min,max)=>Math.max(min,Math.min(max,value));
const pedalInput=value=>typeof value==="boolean"?(value?1:0):clamp(Number.isFinite(value)?value:0,0,1);

/**
 * Resolve a rally tyre's combined longitudinal and lateral force demand.
 * Speed/acceleration use the browser simulation's world-unit calibration.
 * The friction circle is shared by steering, throttle and braking; steering
 * authority therefore falls naturally with speed and low-grip surfaces.
 */
export function resolveTireForces({speed,lateralVelocity,steer,throttle,brake,grip,deltaSeconds,mass=1250,steeringResponseScale=1,rearStability=1}) {
 const v=Number.isFinite(speed)?Math.max(0,speed):0;
 const lateral=Number.isFinite(lateralVelocity)?lateralVelocity:0;
 const steering=clamp(Number.isFinite(steer)?steer:0,-1,1);
 const throttleInput=pedalInput(throttle),brakeInput=pedalInput(brake);
 const dt=clamp(Number.isFinite(deltaSeconds)?deltaSeconds:0,0,.1);
 const surfaceGrip=clamp(Number.isFinite(grip)?grip:1,.35,1.35);
 // Existing vehicle mass values also drive collision response. Use the same
 // mass to model yaw inertia: lighter cars rotate more readily, heavier cars
 // need more time to change heading. This is a game-scale inertia ratio.
 const vehicleMass=clamp(Number.isFinite(mass)?mass:1250,850,2000);
 const yawInertiaScale=clamp(vehicleMass/1250,.8,1.6);
 // Per-car coefficients are game-scale handling calibration, not claimed
 // manufacturer measurements. They separate turn-in from rear-slip stability.
 const steeringScale=clamp(Number.isFinite(steeringResponseScale)?steeringResponseScale:1,.75,1.25);
 const rearStabilityScale=clamp(Number.isFinite(rearStability)?rearStability:1,.75,1.25);
 // Longitudinal load transfer changes the rear axle's normal-load share.
 // Positive values move load forward under braking; throttle moves it rearward.
 // The fractions are normalized axle-load shifts, not vehicle mass units.
 const weightTransferFraction=brakeInput*.14-throttleInput*.06;
 const rearAxleLoadFraction=clamp(.5-weightTransferFraction,.32,.68);
 const rearGripScale=Math.sqrt(rearAxleLoadFraction/.5);
 const capacity=320*surfaceGrip*rearGripScale;
 // Only the rear share of braking force is charged to this rear-axle budget;
 // the front axle carries the larger share under normal brake bias.
 const rearBrakeBias=.4;
 const longitudinalDemand=brakeInput*65*rearBrakeBias+throttleInput*30;
 const availableLateral=Math.sqrt(Math.max(0,capacity*capacity-longitudinalDemand*longitudinalDemand));

 // Bicycle-model steering: yaw rate follows speed, steering angle and wheelbase.
 const wheelbase=128;
 const maxRoadWheelAngle=.48;
 const roadWheelAngle=steering*maxRoadWheelAngle*steeringScale;
 const requestedYawRate=v>0?(v/wheelbase)*Math.tan(roadWheelAngle)/yawInertiaScale:0;
 const requestedCorneringAcceleration=Math.abs(v*requestedYawRate);
 const corneringScale=Math.min(1,availableLateral/Math.max(.001,requestedCorneringAcceleration));

 // Steering rotates the chassis; lateral velocity represents actual slip.
 // Damping removes residual sideslip without commanding a permanent lane drift.
 const lateralDamping=5.5*steeringScale;
 const requestedLateralAcceleration=-lateral*lateralDamping;
 const lateralAccelerationRaw=clamp(requestedLateralAcceleration,-availableLateral,availableLateral);
 const lateralAcceleration=Math.abs(lateralAccelerationRaw)<1e-9?0:lateralAccelerationRaw;
 const slipAngle=Math.atan2(lateral,Math.max(v,1));

 // Slip contributes a damped yaw correction, but the final yaw remains inside
 // the lateral force envelope so it cannot bypass the tyre friction circle.
 const slipCorrection=slipAngle*1.1*clamp((v-70)/100,0,1)/(rearGripScale*yawInertiaScale*rearStabilityScale);
 const yawLimit=availableLateral/Math.max(v,1);
 const yawRateTarget=clamp(requestedYawRate*corneringScale+slipCorrection,-yawLimit,yawLimit);
 const lateralScale=Math.min(1,availableLateral/Math.max(.001,Math.abs(requestedLateralAcceleration)));
 const corneringAcceleration=Math.abs(v*yawRateTarget);
 const combinedLateralDemand=Math.min(capacity*.98,Math.hypot(lateralAcceleration,corneringAcceleration));
 return {
  lateralAcceleration,
  yawRateTarget,
  slipAngle,
  tireCapacity:capacity,
  availableLateral,
  weightTransferFraction,
  rearAxleLoadFraction,
  rearGripScale,
  vehicleMass,
  yawInertiaScale,
  steeringScale,
  rearStabilityScale,
  yawRecoveryScale:rearStabilityScale,
  yawResponse:2.5*rearStabilityScale/yawInertiaScale,
  lateralScale,
  corneringScale,
  corneringUtilization:Math.min(.98,combinedLateralDemand/Math.max(capacity,.001)),
  longitudinalDemand,
  // Longitudinal braking remains calibrated in game speed-units; grip scales
  // the available deceleration while preserving the dry-road baseline.
  brakingDeceleration:brakeInput*470*surfaceGrip*Math.sqrt(Math.max(0,1-(combinedLateralDemand/Math.max(capacity,.001))**2)),
  throttleInput,
  brakeInput,
  frictionUtilization:Math.min(1,Math.hypot(longitudinalDemand,combinedLateralDemand)/Math.max(capacity,.001))
 };
}


/**
 * Limit requested drive acceleration by available tyre-road grip.
 * A grip value of 1 preserves the existing dry-road calibration.
 */
export function resolveLongitudinalAcceleration({requestedAcceleration,grip}) {
 const requested=Number.isFinite(requestedAcceleration)?Math.max(0,requestedAcceleration):0;
 const surfaceGrip=clamp(Number.isFinite(grip)?grip:1,.35,1.35);
 return requested*surfaceGrip;
}
