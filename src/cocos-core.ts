/** Engine-independent gameplay core for the Cocos Creator 3.8.6 adapter. */
export interface CarState { x: number; y: number; heading: number; speed: number; }
export interface DriveInput { steer: number; throttle: boolean; brake: boolean; offRoad?: boolean; grip?: number; performance?: number; }
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
 const grip = (offRoad ? 0.42 : 1) * surfaceGrip;\n const performance = clamp(Number.isFinite(input.performance) ? (input.performance as number) : 1, 0.3, 1);
 const throttle = input.throttle ? 1 : 0; const brake = input.brake ? 1 : 0;
 const maxSpeed = (offRoad ? 220 : 360) * performance;
 if (brake) car.speed = Math.max(0, car.speed - 560 * dt);
 else if (throttle) car.speed = clamp(car.speed + 306 * (offRoad ? 0.58 : 1) * performance * dt, 0, maxSpeed);
 else car.speed = Math.max(0, car.speed - (offRoad ? 220 : 95) * dt);
 if (offRoad && car.speed > maxSpeed) car.speed = Math.max(maxSpeed, car.speed - 360 * dt);
 car.heading -= steer * (1.9 + Math.abs(car.speed) / 155) * grip * dt * Math.sign(car.speed || 1);
 car.x += Math.sin(car.heading) * car.speed * dt; car.y -= Math.cos(car.heading) * car.speed * dt; return car;
}

export interface CollisionBody { x:number; y:number; vx:number; vy:number; mass:number; radius:number; }
export interface VehicleDamageState { total:number; front:number; rear:number; left:number; right:number; engine:number; disabled:boolean; }
export function createVehicleDamage():VehicleDamageState { return {total:0,front:0,rear:0,left:0,right:0,engine:0,disabled:false}; }
export function vehicleDamageLevel(d:VehicleDamageState):number { return d.total>=82?4:d.total>=58?3:d.total>=30?2:d.total>=8?1:0; }
export function addVehicleDamage(d:VehicleDamageState,energy:number,zone:"front"|"rear"|"left"|"right"="front"):number {
 const points=Math.min(24,Math.max(0,Number.isFinite(energy)?energy:0)/300000);
 d.total=Math.min(100,d.total+points);d[zone]=Math.min(100,d[zone]+points);d.engine=Math.min(100,d.engine+points*((zone==="front"||zone==="rear") ? .72 : .24));d.disabled=d.total>=96;return vehicleDamageLevel(d);
}
export function resolveVehicleImpulse(a:CollisionBody,b:CollisionBody,restitution=.14):{hit:boolean;energy:number;impulse:number;closingSpeed:number} {
 const dx=b.x-a.x,dy=b.y-a.y,len=Math.hypot(dx,dy)||.0001,nx=dx/len,ny=dy/len,rvx=a.vx-b.vx,rvy=a.vy-b.vy,closing=rvx*nx+rvy*ny,overlap=Math.max(0,a.radius+b.radius-len),ia=1/Math.max(1,a.mass),ib=1/Math.max(1,b.mass),sum=ia+ib;
 if(closing<=0&&overlap<=0)return {hit:false,energy:0,impulse:0,closingSpeed:0};
 const impulse=closing>0?(1+clamp(restitution,0,.8))*closing/sum:0;
 if(impulse){a.vx+=nx*impulse*ia;a.vy+=ny*impulse*ia;b.vx-=nx*impulse*ib;b.vy-=ny*impulse*ib;}
 if(overlap){const correction=Math.max(0,overlap-.01)*.72/sum;a.x-=nx*correction*ia;a.y-=ny*correction*ia;b.x+=nx*correction*ib;b.y+=ny*correction*ib;}
 return {hit:true,energy:.5*(1/sum)*closing*closing,impulse,closingSpeed:Math.max(0,closing)};
}
export function resolveStaticBarrier(body:CollisionBody,nx:number,ny:number,restitution=.12):{hit:boolean;energy:number;closingSpeed:number} {
 const length=Math.hypot(nx,ny)||1;nx/=length;ny/=length;const normal=body.vx*nx+body.vy*ny,closing=-normal;if(closing<=0)return {hit:false,energy:0,closingSpeed:0};
 body.vx-=(1+restitution)*normal*nx;body.vy-=(1+restitution)*normal*ny;
 const tx=-ny,ty=nx,tangent=body.vx*tx+body.vy*ty;body.vx-=tx*tangent*.16;body.vy-=ty*tangent*.16;
 return {hit:true,energy:.5*Math.max(1,body.mass)*closing*closing,closingSpeed:closing};
}
\nexport function resolveTrackCollision(car: CarState, track: TrackBounds = GREEN_VALLEY_TRACK): boolean {
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
