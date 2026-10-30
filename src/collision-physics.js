// Deterministic, allocation-light 2D impulse and cumulative vehicle damage helpers.
export const COLLISION_TUNING = Object.freeze({
  restitution: 0.16, tangentialFriction: 0.22, damageScale: 1 / 150000,
  damageCapPerImpact: 24, recoveryGrip: 3.8, maxYawRadians: 0.62
});
export function createDamageState() {
  return { total: 0, front: 0, rear: 0, left: 0, right: 0, engine: 0, smokeClock: 0, disabled: false };
}
export function damageLevel(damage) {
  const value = Math.max(0, damage?.total || 0);
  return value >= 82 ? 4 : value >= 58 ? 3 : value >= 30 ? 2 : value >= 8 ? 1 : 0;
}
export function applyVehicleDamage(state, energy, side = "front", tuning = COLLISION_TUNING) {
  const safeEnergy = Number.isFinite(energy) ? Math.max(0, energy) : 0;
  const points = Math.min(tuning.damageCapPerImpact, safeEnergy * tuning.damageScale);
  state.total = Math.min(100, state.total + points);
  const zone = ["front","rear","left","right"].includes(side) ? side : "front";
  state[zone] = Math.min(100, state[zone] + points);
  state.engine = Math.min(100, state.engine + points * (zone === "front" || zone === "rear" ? .72 : .24));
  state.disabled = state.total >= 96;
  return { points, level: damageLevel(state), disabled: state.disabled };
}
export function resolveVehicleImpact(a, b, options = {}) {
  const dx = b.x - a.x, dy = b.y - a.y, distance = Math.hypot(dx, dy) || .0001;
  const nx = dx / distance, ny = dy / distance;
  const overlap = Math.max(0, (a.radius || 30) + (b.radius || 30) - distance);
  const invA = 1 / Math.max(1, a.mass || 1100), invB = 1 / Math.max(1, b.mass || 1100);
  const invSum = invA + invB;
  const rvx = a.vx - b.vx, rvy = a.vy - b.vy;
  const closing = rvx * nx + rvy * ny;
  if (closing <= 0 && overlap <= 0) return { hit: false, closingSpeed: 0, energy: 0, impulse: 0, overlap: 0 };
  const restitution = Math.max(0, Math.min(.8, options.restitution ?? COLLISION_TUNING.restitution));
  const impulse = closing > 0 ? (1 + restitution) * closing / invSum : 0;
  if (impulse) {
    const ix = nx * impulse, iy = ny * impulse;
    a.vx -= ix * invA; a.vy -= iy * invA;
    b.vx += ix * invB; b.vy += iy * invB;
    const tx = -ny, ty = nx, tangentSpeed = rvx * tx + rvy * ty;
    const friction = Math.max(0, Math.min(.8, options.tangentialFriction ?? COLLISION_TUNING.tangentialFriction));
    const jt = Math.max(-impulse * friction, Math.min(impulse * friction, -tangentSpeed / invSum));
    a.vx += tx * jt * invA; a.vy += ty * jt * invA;
    b.vx -= tx * jt * invB; b.vy -= ty * jt * invB;
  }
  if (overlap > 0) {
    const correction = Math.max(0, overlap - 0.01) * .72 / invSum;
    a.x -= nx * correction * invA; a.y -= ny * correction * invA;
    b.x += nx * correction * invB; b.y += ny * correction * invB;
  }
  const reducedMass = 1 / invSum;
  const energy = .5 * reducedMass * Math.max(0, closing) * Math.max(0, closing);
  const forceProxy = impulse;
  const angle = Math.atan2(ny, nx);
  return { hit: true, normalX: nx, normalY: ny, angle, overlap, closingSpeed: Math.max(0, closing), impulse, forceProxy, energy, relativeTangentSpeed: Math.abs(rvx * -ny + rvy * nx) };
}
export function resolveBarrierImpact(vehicle, nx, ny, restitution = .12) {
  const length = Math.hypot(nx, ny) || 1; nx /= length; ny /= length;
  const closing = -(vehicle.vx * nx + vehicle.vy * ny);
  if (closing <= 0) return { hit: false, closingSpeed: 0, energy: 0 };
  const normalSpeed = vehicle.vx * nx + vehicle.vy * ny;
  vehicle.vx -= (1 + restitution) * normalSpeed * nx;
  vehicle.vy -= (1 + restitution) * normalSpeed * ny;
  const tangentX = -ny, tangentY = nx, tangentSpeed = vehicle.vx * tangentX + vehicle.vy * tangentY;
  vehicle.vx -= tangentX * tangentSpeed * .16;
  vehicle.vy -= tangentY * tangentSpeed * .16;
  return { hit: true, closingSpeed: closing, energy: .5 * Math.max(1, vehicle.mass || 1100) * closing * closing, impulse: (1 + restitution) * closing * Math.max(1, vehicle.mass || 1100) };
}
export function damageSideFromLocalNormal(localForwardDot, localRightDot) {
  if (Math.abs(localForwardDot) >= Math.abs(localRightDot)) return localForwardDot >= 0 ? "front" : "rear";
  return localRightDot >= 0 ? "right" : "left";
}
