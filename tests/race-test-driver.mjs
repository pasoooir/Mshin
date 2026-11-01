const clamp = (value, min, max) => Math.max(min, Math.min(max, value));

/**
 * Closed-loop steering controller used only by browser smoke tests.
 * Positive lateral/yaw values mean the vehicle is moving/pointing toward the
 * positive track-normal direction, so the controller commands counter-steer.
 */
export function calculateRaceSteering({ lateral = 0, yaw = 0, lateralVelocity = 0 }) {
  const safeLateral = Number.isFinite(lateral) ? lateral : 0;
  const safeYaw = Number.isFinite(yaw) ? yaw : 0;
  const safeLateralVelocity = Number.isFinite(lateralVelocity) ? lateralVelocity : 0;
  const correction = -(safeLateral / 220) - (safeYaw * 1.5) - (safeLateralVelocity / 320);
  const steering = clamp(correction, -0.9, 0.9);
  return Math.abs(steering) < 0.035 ? 0 : steering;
}
