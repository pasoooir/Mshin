/** Engine-independent gameplay core for the Cocos Creator 3.8.6 adapter. */
export interface CarState { x: number; y: number; heading: number; speed: number; }
export interface DriveInput { steer: number; throttle: boolean; brake: boolean; offRoad?: boolean; grip?: number; }
export interface TrackBounds { radiusX: number; radiusY: number; inner: number; outer: number; }
export interface RaceState { lap: number; previousProgress: number; finished: boolean; elapsedSeconds: number; }
export const GREEN_VALLEY_TRACK: Readonly<TrackBounds> = Object.freeze({ radiusX: 420, radiusY: 260, inner: 0.82, outer: 1.18 });
export const clamp = (v: number, lo: number, hi: number): number => Math.max(lo, Math.min(hi, v));
const FRAME_STEP_LIMIT = 1 / 20;
export function normalizeJoystick(dx: number, dy: number, radius: number): { x: number; y: number } {
 if (!Number.isFinite(radius) || radius <= 0 || !Number.isFinite(dx) || !Number.isFinite(dy)) return { x: 0, y: 0 };
 const length = Math.hypot(dx, dy); if (length === 0) return { x: 0, y: 0 };
 const scale = Math.min(1, radius / length) / radius;
 return { x: clamp(dx * scale, -1, 1), y: clamp(dy * scale, -1, 1) };
}
export function stepCar(car: CarState, input: DriveInput, deltaSeconds: number): CarState {
 const dt = clamp(Number.isFinite(deltaSeconds) ? deltaSeconds : 0, 0, FRAME_STEP_LIMIT);
 const steer = clamp(Number.isFinite(input.steer) ? input.steer : 0, -1, 1);
 const offRoad = Boolean(input.offRoad);
 const surfaceGrip = clamp(Number.isFinite(input.grip) ? (input.grip as number) : 1, 0.35, 1.15);
 const grip = (offRoad ? 0.42 : 1) * surfaceGrip;
 const throttle = input.throttle ? 1 : 0; const brake = input.brake ? 1 : 0;
 const maxSpeed = offRoad ? 220 : 360;
 if (brake) car.speed = Math.max(0, car.speed - 560 * dt);
 else if (throttle) car.speed = clamp(car.speed + 306 * (offRoad ? 0.58 : 1) * dt, 0, maxSpeed);
 else car.speed = Math.max(0, car.speed - (offRoad ? 220 : 95) * dt);
 if (offRoad && car.speed > maxSpeed) car.speed = Math.max(maxSpeed, car.speed - 360 * dt);
 car.heading -= steer * (1.9 + Math.abs(car.speed) / 155) * grip * dt * Math.sign(car.speed || 1);
 car.x += Math.sin(car.heading) * car.speed * dt; car.y -= Math.cos(car.heading) * car.speed * dt; return car;
}
export function resolveTrackCollision(car: CarState, track: TrackBounds = GREEN_VALLEY_TRACK): boolean {
 const r = Math.hypot(car.x / track.radiusX, car.y / track.radiusY); if (r >= track.inner && r <= track.outer) return false;
 const a = Math.atan2(car.y / track.radiusY, car.x / track.radiusX); const corrected = clamp(r, track.inner + 0.012, track.outer - 0.012);
 car.x = Math.cos(a) * track.radiusX * corrected; car.y = Math.sin(a) * track.radiusY * corrected; car.speed *= -0.22; return true;
}
export function trackProgress(x: number, y: number, track: TrackBounds = GREEN_VALLEY_TRACK): number {
 const a = Math.atan2(y / track.radiusY, x / track.radiusX); return ((a + Math.PI * 2) % (Math.PI * 2)) / (Math.PI * 2);
}
export function createRaceState(): RaceState { return { lap: 0, previousProgress: 0, finished: false, elapsedSeconds: 0 }; }
export function updateRace(state: RaceState, x: number, y: number, dt: number, targetLaps = 3): RaceState {
 if (state.finished) return state;
 const elapsedStep = clamp(Number.isFinite(dt) ? dt : 0, 0, FRAME_STEP_LIMIT);
 state.elapsedSeconds += elapsedStep;
 if (!Number.isFinite(x) || !Number.isFinite(y)) return state;
 const current = trackProgress(x, y);
 const lapsRequired = Number.isFinite(targetLaps) ? Math.max(1, Math.floor(targetLaps)) : 3;
 if (state.previousProgress > 0.88 && current < 0.12) { state.lap += 1; if (state.lap >= lapsRequired) state.finished = true; }
 state.previousProgress = current; return state;
}
