/** Engine-independent gameplay core for the Cocos Creator 3.8.6 adapter. */
export interface CarState { x: number; y: number; heading: number; speed: number; angularVelocity?:number; }
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
 const grip = (offRoad ? 0.42 : 1) * surfaceGrip;
 const performance = clamp(Number.isFinite(input.performance) ? (input.performance as number) : 1, 0.3, 1);
 const throttle = input.throttle ? 1 : 0; const brake = input.brake ? 1 : 0;
 const maxSpeed = (offRoad ? 220 : 360) * performance;
 if (brake) car.speed = Math.max(0, car.speed - 560 * dt);
 else if (throttle) car.speed = clamp(car.speed + 306 * (offRoad ? 0.58 : 1) * performance * dt, 0, maxSpeed);
 else car.speed = Math.max(0, car.speed - (offRoad ? 220 : 95) * dt);
 if (car.speed > maxSpeed) car.speed = Math.max(maxSpeed, car.speed - 360 * dt);
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
 if(impulse){a.vx-=nx*impulse*ia;a.vy-=ny*impulse*ia;b.vx+=nx*impulse*ib;b.vy+=ny*impulse*ib;}
 if(overlap){const correction=Math.max(0,overlap-.01)*.72/sum;a.x-=nx*correction*ia;a.y-=ny*correction*ia;b.x+=nx*correction*ib;b.y+=ny*correction*ib;}
 return {hit:true,energy:.5*(1/sum)*Math.max(0,closing)*Math.max(0,closing),impulse,closingSpeed:Math.max(0,closing)};
}
export function resolveStaticBarrier(body:CollisionBody,nx:number,ny:number,restitution=.12):{hit:boolean;energy:number;closingSpeed:number} {
 const length=Math.hypot(nx,ny)||1;nx/=length;ny/=length;const normal=body.vx*nx+body.vy*ny,closing=-normal;if(closing<=0)return {hit:false,energy:0,closingSpeed:0};
 body.vx-=(1+restitution)*normal*nx;body.vy-=(1+restitution)*normal*ny;
 const tx=-ny,ty=nx,tangent=body.vx*tx+body.vy*ty;body.vx-=tx*tangent*.16;body.vy-=ty*tangent*.16;
 return {hit:true,energy:.5*Math.max(1,body.mass)*closing*closing,closingSpeed:closing};
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


/** Oriented 2D rigid body used by the Cocos scene adapter. Coordinates are world units. */
export interface RigidBody2D {
 x:number;y:number;vx:number;vy:number;angle:number;angularVelocity:number;
 mass:number;length:number;width:number;inertia:number;invMass:number;invInertia:number;
 restitution:number;friction:number;
}
export interface RigidImpactResult {hit:boolean;nx:number;ny:number;overlap:number;closingSpeed:number;impulse:number;energy:number;pointX:number;pointY:number;}
export function createRigidBody2D(options:{x:number;y:number;vx?:number;vy?:number;angle?:number;angularVelocity?:number;mass?:number;length?:number;width?:number;restitution?:number;friction?:number;static?:boolean}):RigidBody2D {
 const mass=Math.max(1,options.mass??1250),length=Math.max(1,options.length??54),width=Math.max(1,options.width??30),isStatic=options.static===true;
 const inertia=mass*(length*length+width*width)/12;
 return {x:options.x,y:options.y,vx:options.vx??0,vy:options.vy??0,angle:options.angle??0,angularVelocity:options.angularVelocity??0,mass,length,width,inertia,
  invMass:isStatic?0:1/mass,invInertia:isStatic?0:1/inertia,restitution:clamp(options.restitution??.12,0,.8),friction:clamp(options.friction??.34,0,1)};
}
function rigidAxes(b:RigidBody2D):[Point,Point] {const c=Math.cos(b.angle),s=Math.sin(b.angle);return [{x:c,y:s},{x:-s,y:c}];}
function rigidRadius(b:RigidBody2D,axis:Point,basis:[Point,Point]):number {
 return Math.abs(axis.x*basis[0].x+axis.y*basis[0].y)*b.length/2+Math.abs(axis.x*basis[1].x+axis.y*basis[1].y)*b.width/2;
}
function rigidSupport(b:RigidBody2D,dx:number,dy:number):Point {
 const axes=rigidAxes(b),d0=dx*axes[0].x+dy*axes[0].y,d1=dx*axes[1].x+dy*axes[1].y,s0=Math.abs(d0)<1e-8?0:Math.sign(d0),s1=Math.abs(d1)<1e-8?0:Math.sign(d1);
 return {x:b.x+s0*axes[0].x*b.length/2+s1*axes[1].x*b.width/2,y:b.y+s0*axes[0].y*b.length/2+s1*axes[1].y*b.width/2};
}
function rigidCross(ax:number,ay:number,bx:number,by:number):number{return ax*by-ay*bx;}
function rigidVelocityAt(b:RigidBody2D,rx:number,ry:number):Point{return {x:b.vx-b.angularVelocity*ry,y:b.vy+b.angularVelocity*rx};}
export function resolveRigidBody2D(a:RigidBody2D,b:RigidBody2D,positionPercent=.82):RigidImpactResult {
 const aa=rigidAxes(a),bb=rigidAxes(b),dx=b.x-a.x,dy=b.y-a.y;let overlap=Infinity,nx=0,ny=0;
 for(const axis of [...aa,...bb]){const distance=Math.abs(dx*axis.x+dy*axis.y),depth=rigidRadius(a,axis,aa)+rigidRadius(b,axis,bb)-distance;
  if(depth<=0)return {hit:false,nx:0,ny:0,overlap:0,closingSpeed:0,impulse:0,energy:0,pointX:0,pointY:0};
  if(depth<overlap){overlap=depth;const sign=dx*axis.x+dy*axis.y>=0?1:-1;nx=axis.x*sign;ny=axis.y*sign;}
 }
 const pa=rigidSupport(a,nx,ny),pb=rigidSupport(b,-nx,-ny),pointX=(pa.x+pb.x)/2,pointY=(pa.y+pb.y)/2;
 const rax=pointX-a.x,ray=pointY-a.y,rbx=pointX-b.x,rby=pointY-b.y,va=rigidVelocityAt(a,rax,ray),vb=rigidVelocityAt(b,rbx,rby);
 const vn=(vb.x-va.x)*nx+(vb.y-va.y)*ny,ran=rigidCross(rax,ray,nx,ny),rbn=rigidCross(rbx,rby,nx,ny);
 const denom=a.invMass+b.invMass+ran*ran*a.invInertia+rbn*rbn*b.invInertia;let impulse=0,energy=0,closingSpeed=Math.max(0,-vn);
 if(vn<0&&denom>1e-10){
  const e=Math.min(a.restitution,b.restitution);impulse=-(1+e)*vn/denom;const ix=impulse*nx,iy=impulse*ny;
  a.vx-=ix*a.invMass;a.vy-=iy*a.invMass;a.angularVelocity-=rigidCross(rax,ray,ix,iy)*a.invInertia;
  b.vx+=ix*b.invMass;b.vy+=iy*b.invMass;b.angularVelocity+=rigidCross(rbx,rby,ix,iy)*b.invInertia;
  energy=.5*vn*vn/denom*(1-e*e);
  const tx=-ny,ty=nx,vat=rigidVelocityAt(a,rax,ray),vbt=rigidVelocityAt(b,rbx,rby),vt=(vbt.x-vat.x)*tx+(vbt.y-vat.y)*ty;
  const rat=rigidCross(rax,ray,tx,ty),rbt=rigidCross(rbx,rby,tx,ty),td=a.invMass+b.invMass+rat*rat*a.invInertia+rbt*rbt*b.invInertia;
  const mu=Math.sqrt(a.friction*b.friction),jt=clamp(-vt/Math.max(1e-10,td),-impulse*mu,impulse*mu),tix=jt*tx,tiy=jt*ty;
  a.vx-=tix*a.invMass;a.vy-=tiy*a.invMass;a.angularVelocity-=rigidCross(rax,ray,tix,tiy)*a.invInertia;
  b.vx+=tix*b.invMass;b.vy+=tiy*b.invMass;b.angularVelocity+=rigidCross(rbx,rby,tix,tiy)*b.invInertia;
 }
 const invSum=a.invMass+b.invMass,correction=invSum>0?Math.max(overlap-.02,0)*positionPercent/invSum:0;
 if(correction){a.x-=nx*correction*a.invMass;a.y-=ny*correction*a.invMass;b.x+=nx*correction*b.invMass;b.y+=ny*correction*b.invMass;}
 return {hit:true,nx,ny,overlap,closingSpeed,impulse,energy,pointX,pointY};
}
export function resolveRigidVehiclePair(a:RigidBody2D,b:RigidBody2D):RigidImpactResult {return resolveRigidBody2D(a,b);}
