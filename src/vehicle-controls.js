/** Convert the track tangent into the WebGL car model's local +Z forward axis. */
export function vehicleModelHeading(trackAngle, yaw = 0) {
  const angle = Number.isFinite(trackAngle) ? trackAngle : 0;
  const slip = Number.isFinite(yaw) ? yaw : 0;
  return angle + Math.PI / 2 + slip;
}

/** Read device tilt along the physical screen's horizontal axis. */
export function screenRelativeTilt(event, screenAngle = 0) {
  if (!event || !Number.isFinite(event.beta) || !Number.isFinite(event.gamma)) return null;
  const angle = ((Number(screenAngle) % 360) + 360) % 360;
  if (angle >= 45 && angle < 135) return event.beta;
  if (angle >= 225 && angle < 315) return -event.beta;
  if (angle >= 135 && angle < 225) return -event.gamma;
  return event.gamma;
}

/** Convert calibrated degrees of tilt to a stable, bounded steering command. */
export function tiltToSteer(tiltDegrees, sensitivity = 1, deadZone = 1.8, fullScale = 22) {
  if (!Number.isFinite(tiltDegrees)) return 0;
  const dead = Math.max(0, Number.isFinite(deadZone) ? deadZone : 1.8);
  const range = Math.max(dead + 1, Number.isFinite(fullScale) ? fullScale : 22);
  const magnitude = Math.abs(tiltDegrees);
  if (magnitude <= dead) return 0;
  const normalized = Math.min(1, (magnitude - dead) / (range - dead));
  const gain = Math.max(.35, Math.min(1.8, Number.isFinite(sensitivity) ? sensitivity : 1));
  return Math.sign(tiltDegrees) * Math.min(1, Math.pow(normalized, 1.12) * gain);
}

/** Map a horizontal joystick drag to steering in the game's world-space convention. */
export function joystickDeltaToSteer(delta, limit) {
  if (!Number.isFinite(delta) || !Number.isFinite(limit) || limit <= 0) return 0;
  const raw = Math.max(-1, Math.min(1, delta / limit));
  const magnitude = Math.abs(raw);
  const deadZone = 0.07;
  if (magnitude <= deadZone) return 0;
  const linear = (magnitude - deadZone) / (1 - deadZone);
  // Positive screen-right must yaw toward world-right. The track tangent and
  // canvas Y-down coordinate system make that the negative physics steer sign.
  return -Math.sign(raw) * Math.pow(linear, 1.28);
}

/** Convert a physical rightward phone tilt into the matching right-turn command. */
export function screenTiltToSteer(tiltDegrees, sensitivity = 1) {
  const steering = tiltToSteer(tiltDegrees, sensitivity);
  return steering === 0 ? 0 : -steering;
}
