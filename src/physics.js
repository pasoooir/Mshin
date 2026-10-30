export const TRACK = Object.freeze({ rx: 420, ry: 260, inner: 0.82, outer: 1.18 });
export const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
export function trackRadius(x, y) { return Math.hypot(x / TRACK.rx, y / TRACK.ry); }
export function stepCar(car, input, dt) {
  const t = clamp(dt, 0, 1 / 20);
  const throttle = input.throttle ? 1 : 0;
  const brake = input.brake ? 1 : 0;
  const grip = input.offRoad ? 0.42 : 1;
  if (brake) car.speed = Math.max(0, car.speed - 560 * t);
  else if (throttle) car.speed = clamp(car.speed + 306 * t, 0, 360);
  else car.speed = Math.max(0, car.speed - 95 * t);
  car.heading -= input.steer * (1.9 + Math.abs(car.speed) / 155) * grip * t * Math.sign(car.speed || 1);
  car.x += Math.sin(car.heading) * car.speed * t;
  car.y -= Math.cos(car.heading) * car.speed * t;
  return car;
}
export function resolveTrackCollision(car) {
  const r = trackRadius(car.x, car.y);
  if (r >= TRACK.inner && r <= TRACK.outer) return false;
  const angle = Math.atan2(car.y / TRACK.ry, car.x / TRACK.rx);
  const corrected = clamp(r, TRACK.inner + 0.012, TRACK.outer - 0.012);
  car.x = Math.cos(angle) * TRACK.rx * corrected;
  car.y = Math.sin(angle) * TRACK.ry * corrected;
  car.speed *= -0.22;
  return true;
}
export function lapProgress(x, y) {
  const a = Math.atan2(y / TRACK.ry, x / TRACK.rx);
  return (a + Math.PI * 2) % (Math.PI * 2) / (Math.PI * 2);
}
export function crossedFinish(previous, current) { return previous > 0.88 && current < 0.12; }
