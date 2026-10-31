// Deterministic 2D rigid-body vehicle contact solver.
// Vehicle geometry is one oriented rectangle; wheels/bumpers are attached mass,
// not independent colliders. Units: world units, seconds, kilograms.
const EPS = 1e-8;
const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));

export function createRigidVehicle({ x=0, y=0, vx=0, vy=0, angle=0, angularVelocity=0,
  mass=1200, length=108, width=58, restitution=.12, friction=.34 } = {}) {
  const safeMass = Math.max(1, mass);
  return { x, y, vx, vy, angle, angularVelocity, mass:safeMass, length, width,
    inertia:safeMass*(length*length+width*width)/12,
    invMass:1/safeMass, invInertia:12/(safeMass*(length*length+width*width)),
    restitution:clamp(restitution,0,.8), friction:clamp(friction,0,1) };
}

function axes(body) {
  const c=Math.cos(body.angle), s=Math.sin(body.angle);
  return [{x:c,y:s},{x:-s,y:c}]; // longitudinal, lateral
}
function projectRadius(body, axis, basis) {
  return Math.abs(axis.x*basis[0].x+axis.y*basis[0].y)*body.length/2+
    Math.abs(axis.x*basis[1].x+axis.y*basis[1].y)*body.width/2;
}
function support(body, dx, dy) {
  const basis=axes(body);
  return {x:body.x+Math.sign(Math.abs(dx*basis[0].x+dy*basis[0].y)<EPS?0:dx*basis[0].x+dy*basis[0].y)*basis[0].x*body.length/2+
      Math.sign(Math.abs(dx*basis[1].x+dy*basis[1].y)<EPS?0:dx*basis[1].x+dy*basis[1].y)*basis[1].x*body.width/2,
    y:body.y+Math.sign(Math.abs(dx*basis[0].x+dy*basis[0].y)<EPS?0:dx*basis[0].x+dy*basis[0].y)*basis[0].y*body.length/2+
      Math.sign(Math.abs(dx*basis[1].x+dy*basis[1].y)<EPS?0:dx*basis[1].x+dy*basis[1].y)*basis[1].y*body.width/2};
}
export function vehicleContact(a,b) {
  const dx=b.x-a.x,dy=b.y-a.y,aa=axes(a),bb=axes(b);
  let minOverlap=Infinity,nx=0,ny=0;
  for(const axis of [...aa,...bb]) {
    const distance=Math.abs(dx*axis.x+dy*axis.y);
    const overlap=projectRadius(a,axis,aa)+projectRadius(b,axis,bb)-distance;
    if(overlap<=0)return {hit:false,overlap:0};
    if(overlap<minOverlap){minOverlap=overlap;const sign=dx*axis.x+dy*axis.y>=0?1:-1;nx=axis.x*sign;ny=axis.y*sign;}
  }
  // Midpoint between opposing support features is stable and allocation-light.
  const pa=support(a,nx,ny),pb=support(b,-nx,-ny);
  return {hit:true,nx,ny,overlap:minOverlap,point:{x:(pa.x+pb.x)/2,y:(pa.y+pb.y)/2}};
}
function cross(ax,ay,bx,by){return ax*by-ay*bx}
function velocityAt(body,rx,ry){return {x:body.vx-body.angularVelocity*ry,y:body.vy+body.angularVelocity*rx}}
export function resolveRigidVehicleImpact(a,b,{positionPercent=.82,slop=.02}={}) {
  const contact=vehicleContact(a,b);
  if(!contact.hit)return {hit:false,energy:0,impulse:0,overlap:0};
  const {nx,ny,point}=contact,raX=point.x-a.x,raY=point.y-a.y,rbX=point.x-b.x,rbY=point.y-b.y;
  const va=velocityAt(a,raX,raY),vb=velocityAt(b,rbX,rbY),rvx=vb.x-va.x,rvy=vb.y-va.y;
  const vn=rvx*nx+rvy*ny,invA=a.invMass??1/a.mass,invB=b.invMass??1/b.mass;
  const ran=cross(raX,raY,nx,ny),rbn=cross(rbX,rbY,nx,ny);
  const denom=invA+invB+ran*ran*a.invInertia+rbn*rbn*b.invInertia;
  let j=0,energy=0;
  if(vn<0) {
    const e=Math.min(a.restitution??.12,b.restitution??.12);
    j=-(1+e)*vn/Math.max(EPS,denom);
    const ix=j*nx,iy=j*ny;
    a.vx-=ix*invA;a.vy-=iy*invA;a.angularVelocity-=cross(raX,raY,ix,iy)*a.invInertia;
    b.vx+=ix*invB;b.vy+=iy*invB;b.angularVelocity+=cross(rbX,rbY,ix,iy)*b.invInertia;
    energy=.5*vn*vn/Math.max(EPS,denom)*(1-e*e);
    const tx=-ny,ty=nx,vat=velocityAt(a,raX,raY),vbt=velocityAt(b,rbX,rbY);
    const vt=(vbt.x-vat.x)*tx+(vbt.y-vat.y)*ty;
    const rat=cross(raX,raY,tx,ty),rbt=cross(rbX,rbY,tx,ty);
    const td=invA+invB+rat*rat*a.invInertia+rbt*rbt*b.invInertia;
    const mu=Math.sqrt((a.friction??.34)*(b.friction??.34));
    const jt=clamp(-vt/Math.max(EPS,td),-j*mu,j*mu),tix=jt*tx,tiy=jt*ty;
    a.vx-=tix*invA;a.vy-=tiy*invA;a.angularVelocity-=cross(raX,raY,tix,tiy)*a.invInertia;
    b.vx+=tix*invB;b.vy+=tiy*invB;b.angularVelocity+=cross(rbX,rbY,tix,tiy)*b.invInertia;
  }
  const correction=Math.max(contact.overlap-slop,0)*positionPercent/(invA+invB);
  if(correction){a.x-=nx*correction*invA;a.y-=ny*correction*invA;b.x+=nx*correction*invB;b.y+=ny*correction*invB;}
  return {hit:true,nx,ny,overlap:contact.overlap,closingSpeed:Math.max(0,-vn),impulse:j,energy,point,angularA:a.angularVelocity,angularB:b.angularVelocity};
}

// Conservative temporal sampling prevents fast bodies stepping through one another.
// The caller supplies previous/current transforms; a contact is resolved at the
// earliest sampled time, then the remaining frame can be integrated with new velocity.
export function sweptVehicleContact(a0,a1,b0,b1,{maxStep=24}={}) {
  const travel=Math.hypot((a1.x-a0.x)-(b1.x-b0.x),(a1.y-a0.y)-(b1.y-b0.y));
  const radiusA=Math.hypot(a0.length,a0.width)/2,radiusB=Math.hypot(b0.length,b0.width)/2;
  const rotationalTravel=Math.abs(a1.angle-a0.angle)*radiusA+Math.abs(b1.angle-b0.angle)*radiusB;
  const feature=Math.max(4,Math.min(a0.width,a0.length,b0.width,b0.length)*.35);
  const steps=clamp(Math.ceil((travel+rotationalTravel)/feature),1,maxStep);
  for(let i=0;i<=steps;i++){
    const t=i/steps;
    const a={...a0,x:a0.x+(a1.x-a0.x)*t,y:a0.y+(a1.y-a0.y)*t,angle:a0.angle+(a1.angle-a0.angle)*t};
    const b={...b0,x:b0.x+(b1.x-b0.x)*t,y:b0.y+(b1.y-b0.y)*t,angle:b0.angle+(b1.angle-b0.angle)*t};
    const hit=vehicleContact(a,b);
    if(hit.hit)return {...hit,timeOfImpact:t,steps};
  }
  return {hit:false,timeOfImpact:1,steps};
}

export function applyRigidImpactDamage(damage, impact, localSide, tuning={}) {
  const energy=Math.max(0,Number(impact?.energy)||0);
  const scale=tuning.damageScale??1/190000;
  const cap=tuning.damageCapPerImpact??28;
  const points=Math.min(cap,energy*scale);
  const zone=["front","rear","left","right"].includes(localSide)?localSide:"front";
  damage.total=clamp((damage.total||0)+points,0,100);
  damage[zone]=clamp((damage[zone]||0)+points,0,100);
  const structural=zone==="front"||zone==="rear"?1:.55;
  damage.engine=clamp((damage.engine||0)+points*structural*.45,0,100);
  damage.disabled=damage.total>=96;
  return {points,zone,disabled:damage.disabled,energy};
}

/** Allocate dissipated impact energy by inverse-mass response. */
export function splitImpactEnergy(energy,invMassA,invMassB) {
  const safeEnergy=Math.max(0,Number.isFinite(energy)?energy:0),a=Math.max(0,Number.isFinite(invMassA)?invMassA:0),b=Math.max(0,Number.isFinite(invMassB)?invMassB:0),sum=a+b;
  return sum>1e-12?{a:safeEnergy*a/sum,b:safeEnergy*b/sum}:{a:safeEnergy*.5,b:safeEnergy*.5};
}
