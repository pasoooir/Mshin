import { resolveTireForces, resolveLongitudinalAcceleration } from "./tire-physics.js";

const clamp = (value, min, max) => Math.max(min, Math.min(max, value));
const wrapAngle = value => Math.atan2(Math.sin(value), Math.cos(value));

/**
 * Integrates a vehicle in world space, then projects its position back into
 * the track's local Frenet frame. The track never drives or corrects the car:
 * steering, tyre forces and the car's actual heading determine its trajectory.
 *
 * speed is the longitudinal body speed in the game's calibrated speed units;
 * lateralVelocity is body-local lateral speed in the same calibrated units as speed.
 */
export function stepVehicleDynamics(vehicle, controls, tuning, frameAt) {
  const dt = clamp(Number.isFinite(tuning.dt) ? tuning.dt : 0, 0, 1 / 30);
  if (dt <= 0) return null;

  const trackT = vehicle.t;
  const frame = frameAt(trackT);
  const forwardAngle = frame.angle + vehicle.yaw;
  const forwardX = Math.cos(forwardAngle);
  const forwardY = Math.sin(forwardAngle);
  const sideX = -forwardY;
  const sideY = forwardX;

  const speed = Math.max(0, Number(vehicle.speed) || 0);
  const lateralVelocity = Number(vehicle.lateralVelocity) || 0;
  const grip = clamp(Number(tuning.grip) || 1, 0.25, 1.5);
  const mass = clamp(Number(tuning.mass) || 1250, 650, 8000);
  const tire = resolveTireForces({
    speed,
    lateralVelocity,
    steer: controls.steer,
    throttle: controls.throttle,
    brake: controls.brake,
    grip,
    deltaSeconds: dt,
    mass,
    steeringResponseScale: tuning.steeringResponse || 1,
    rearStability: tuning.rearStability || 1
  });

  const maxSpeed = Math.max(0, tuning.maxSpeed || 0);
  const requestedAcceleration = Math.max(0, tuning.acceleration || 0) * grip;
  const driveAcceleration = resolveLongitudinalAcceleration({
    requestedAcceleration,
    grip: 1
  });
  const rollingAndAeroDrag = 18 + speed * speed * 0.00052;
  let longitudinalAcceleration = controls.brake
    ? -tire.brakingDeceleration
    : controls.throttle
      ? driveAcceleration
      : -rollingAndAeroDrag;

  // The combined tyre-force budget prevents full drive/brake force and full
  // cornering force from being applied independently at the same time.
  const longitudinalLimit = 470 * grip;
  const lateralUse = Math.min(0.98, Math.abs(tire.lateralAcceleration) / Math.max(1, tire.tireCapacity));
  const availableLongitudinal = longitudinalLimit * Math.sqrt(1 - lateralUse * lateralUse);
  longitudinalAcceleration = clamp(longitudinalAcceleration, -availableLongitudinal, availableLongitudinal);
  vehicle.speed = clamp(speed + longitudinalAcceleration * dt, 0, maxSpeed);

  vehicle.lateralVelocity = lateralVelocity + tire.lateralAcceleration * dt;
  const yawRate = Number(vehicle.yawRate) || 0;
  vehicle.yawRate = clamp(
    yawRate + (tire.yawRateTarget - yawRate) * (1 - Math.exp(-tire.yawResponse * dt)),
    -1.4,
    1.4
  );

  // Convert the chassis velocity into world-space displacement. This is the
  // key distinction from lane-following: yaw changes the direction of travel.
  const worldUnitsPerSpeedUnit = tuning.worldUnitsPerSpeedUnit || 1;
  const longitudinalWorldSpeed = vehicle.speed * worldUnitsPerSpeedUnit;
  const lateralWorldSpeed = vehicle.lateralVelocity * worldUnitsPerSpeedUnit;
  const worldVx = forwardX * longitudinalWorldSpeed + sideX * lateralWorldSpeed;
  const worldVy = forwardY * longitudinalWorldSpeed + sideY * lateralWorldSpeed;
  const dx = worldVx * dt;
  const dy = worldVy * dt;

  const tangentDistance = dx * Math.cos(frame.angle) + dy * Math.sin(frame.angle);
  const normalDistance = dx * frame.nx + dy * frame.ny;
  const before = frameAt(trackT - 0.002);
  const after = frameAt(trackT + 0.002);
  const tangentScale = Math.max(1, Math.hypot(after.p.x - before.p.x, after.p.y - before.p.y) / 0.004);
  vehicle.t = (trackT + tangentDistance / tangentScale + Math.PI * 2) % (Math.PI * 2);
  vehicle.lateral = clamp((Number(vehicle.lateral) || 0) + normalDistance, -260, 260);

  // Preserve the car's world heading while the track's local tangent rotates.
  const worldHeading = forwardAngle + vehicle.yawRate * dt;
  const nextFrame = frameAt(vehicle.t);
  vehicle.yaw = clamp(wrapAngle(worldHeading - nextFrame.angle), -1.15, 1.15);

  return {
    tire,
    worldVelocity: { x: worldVx, y: worldVy },
    heading: worldHeading,
    slipAngle: Math.atan2(vehicle.lateralVelocity, Math.max(1, longitudinalWorldSpeed)),
    longitudinalAcceleration,
    tangentSpeed: tangentDistance / dt,
    lateralSpeed: normalDistance / dt
  };
}
