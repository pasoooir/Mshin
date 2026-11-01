const clamp = (value, min, max) => Math.max(min, Math.min(max, value));

const TRACK_TAU = Math.PI * 2;

export function chooseRaceTargetLateral({ trackT = 0, currentTarget = 0, traffic = [] }) {
  const position = Number.isFinite(trackT) ? trackT : 0;
  const current = Number.isFinite(currentTarget) ? currentTarget : 0;
  const candidates = [-100, 0, 100];
  const score = candidate => {
    let risk = Math.abs(candidate - current) * 0.0015;
    for (const vehicle of Array.isArray(traffic) ? traffic : []) {
      if (!Number.isFinite(vehicle?.distance) || !Number.isFinite(vehicle?.lateral)) continue;
      const gap = ((vehicle.distance - position) % TRACK_TAU + TRACK_TAU) % TRACK_TAU;
      const trackGap = Math.min(gap, TRACK_TAU - gap) * 950;
      risk += Math.exp(-trackGap / 160) * Math.exp(-Math.abs(candidate - vehicle.lateral) / 55);
    }
    return risk;
  };
  return candidates.reduce((best, candidate) => score(candidate) < score(best) ? candidate : best, candidates[0]);
}

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
  const correction = curveCompensation - ((safeLateral - safeTargetLateral) / 2000) - (safeYaw * 0.18) - (safeLateralVelocity / 1000);
  const steering = clamp(correction, -0.85, 0.85);
  return Math.abs(steering) < 0.035 ? 0 : steering;
}
