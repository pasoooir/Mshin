const clamp = (value, min, max) => Math.max(min, Math.min(max, value));

/**
 * Closed-loop steering controller used only by browser smoke tests.
 * Positive lateral/yaw values mean the vehicle is moving/pointing toward the
 * positive track-normal direction, so the controller commands counter-steer.
 */
export function calculateRaceSteering({ lateral = 0, targetLateral = 0, yaw = 0, lateralVelocity = 0, trackCurvature = 0 }) {
  const safeLateral = Number.isFinite(lateral) ? lateral : 0;
  const safeTargetLateral = Number.isFinite(targetLateral) ? targetLateral : 0;
  const safeYaw = Number.isFinite(yaw) ? yaw : 0;
  const safeCurvature = Number.isFinite(trackCurvature) ? trackCurvature : 0;
  const safeLateralVelocity = Number.isFinite(lateralVelocity) ? lateralVelocity : 0;
  const curveCompensation = Math.atan(safeCurvature * 128) / 0.48;
  const correction = curveCompensation - ((safeLateral - safeTargetLateral) / 500) - (safeYaw * 0.28) - (safeLateralVelocity / 900);
  const steering = clamp(correction, -0.52, 0.52);
  return Math.abs(steering) < 0.035 ? 0 : steering;
}
