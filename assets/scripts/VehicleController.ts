import { _decorator, Component } from "cc";
import { CarState, DriveInput, createRaceState, RaceState, stepCar, updateRace, createVehicleDamage, addVehicleDamage, resolveStaticBarrier, CollisionBody, createRigidBody2D, resolveRigidBody2D, splitImpactEnergy, worldVelocityToCar } from "../../src/cocos-core";
import { nearestTrackPoint, Point } from "../../src/stage-catalog";
const {ccclass}=_decorator;
@ccclass("MshinVehicleController")
export class VehicleController extends Component {
 readonly car:CarState={x:0,y:0,heading:Math.PI,speed:0,angularVelocity:0};
 readonly race:RaceState=createRaceState();
 readonly damage=createVehicleDamage();
 input:DriveInput={steer:0,throttle:false,brake:false};
 path:Point[]=[];trackWidth=100;targetLaps=3;surfaceGrip=1;obstacles:Array<Point & {angle:number}>=[];private hitCooldown=0;private lastLap=0;private smoothedSteer=0;
 onLap:(lap:number)=>void=()=>{};
 configure(path:Point[],trackWidth:number,laps:number,hazardCount:number,surfaceGrip=1):void {
  this.path=path;this.trackWidth=trackWidth;this.targetLaps=laps;this.surfaceGrip=surfaceGrip;this.obstacles=[];
  for(let i=0;i<hazardCount;i++){const index=Math.floor((i+.45)*path.length/hazardCount),p=path[index],n=path[(index+2)%path.length],dx=n.y-p.y,dy=p.x-n.x,len=Math.hypot(dx,dy)||1,side=i%2?1:-1;this.obstacles.push({x:p.x+dx/len*trackWidth*.18*side,y:p.y+dy/len*trackWidth*.18*side,angle:Math.atan2(n.y-p.y,n.x-p.x)});}
  const start=path[0];this.car.x=start.x;this.car.y=start.y;this.car.heading=Math.PI;this.car.speed=0;this.car.lateralSpeed=0;this.car.angularVelocity=0;Object.assign(this.damage,createVehicleDamage());
  Object.assign(this.race,{lap:0,previousProgress:0,finished:false,elapsedSeconds:0});this.lastLap=0;this.hitCooldown=0;this.node.setPosition(start.x,start.y,0);this.resetInput();
 }
 update(dt:number):void {
  if(this.race.finished||this.path.length<2)return;
  const nearest=nearestTrackPoint(this.car,this.path);
  this.input.offRoad=nearest.distance>this.trackWidth*.34;this.input.grip=this.surfaceGrip;this.input.performance=this.damage.disabled ? .3 : Math.max(.38,1-this.damage.total*.0048);
  const response=1-Math.exp(-Math.max(0,Math.min(dt,.05))*(Math.abs(this.input.steer)<.001?5:8));this.smoothedSteer+=(this.input.steer-this.smoothedSteer)*response;
  // Fixed substeps bound travel per solve and prevent high-speed obstacle tunnelling.
  let remaining=Math.max(0,Math.min(dt,.05));while(remaining>0){const sub=Math.min(remaining,1/120);stepCar(this.car,{...this.input,steer:this.smoothedSteer},sub);this.resolveObstacleContacts(sub);this.car.heading+=((this.car.angularVelocity??0)*sub);this.car.angularVelocity=(this.car.angularVelocity??0)*Math.exp(-4.2*sub);remaining-=sub;}
  const hit=nearestTrackPoint(this.car,this.path);const next=this.path[(hit.segment+1)%this.path.length],prev=this.path[hit.segment],tangent=Math.atan2(next.x-prev.x,prev.y-next.y),headingError=Math.atan2(Math.sin(tangent-this.car.heading),Math.cos(tangent-this.car.heading)),assist=Math.max(-Math.max(.8,Math.abs(this.car.speed)/180)*dt,Math.min(Math.max(.8,Math.abs(this.car.speed)/180)*dt,headingError));this.car.heading+=assist*.72;
  if(hit.distance>this.trackWidth*.46){const dx=this.car.x-hit.point.x,dy=this.car.y-hit.point.y,len=Math.hypot(dx,dy)||1,limit=this.trackWidth*.43,nx=dx/len,ny=dy/len;const body:CollisionBody={x:this.car.x,y:this.car.y,vx:Math.sin(this.car.heading)*this.car.speed,vy:-Math.cos(this.car.heading)*this.car.speed,mass:1250,radius:18};const impact=resolveStaticBarrier(body,nx,ny);this.car.x=hit.point.x+nx*limit;this.car.y=hit.point.y+ny*limit;if(impact.hit){this.car.speed=Math.hypot(body.vx,body.vy);this.car.heading=Math.atan2(body.vx,-body.vy);addVehicleDamage(this.damage,impact.energy,Math.abs(nx)>Math.abs(ny)?(nx>0?"right":"left"):"front");}else this.car.speed*=.92;}
  this.hitCooldown=Math.max(0,this.hitCooldown-dt);
  if(this.hitCooldown===0){for(const o of this.obstacles){const dx=this.car.x-o.x,dy=this.car.y-o.y,distance=Math.hypot(dx,dy);if(distance>=31)continue;const body:CollisionBody={x:this.car.x,y:this.car.y,vx:Math.sin(this.car.heading)*this.car.speed,vy:-Math.cos(this.car.heading)*this.car.speed,mass:1250,radius:18},impact=resolveStaticBarrier(body,dx/(distance||1),dy/(distance||1));if(impact.hit){this.car.speed=Math.hypot(body.vx,body.vy);this.car.heading=Math.atan2(body.vx,-body.vy);addVehicleDamage(this.damage,impact.energy,"front");}this.hitCooldown=.65;break;}}
  this.node.setPosition(this.car.x,this.car.y,0);this.node.angle=180-this.car.heading*180/Math.PI;
  updateRace(this.race,this.car.x,this.car.y,dt,this.targetLaps);
  if(this.race.lap!==this.lastLap){this.lastLap=this.race.lap;this.onLap(this.lastLap);}
 }

 private resolveObstacleContacts(dt:number):void {
  this.hitCooldown=Math.max(0,this.hitCooldown-dt);if(this.hitCooldown>0)return;
  for(const obstacle of this.obstacles){
   const dx=this.car.x-obstacle.x,dy=this.car.y-obstacle.y;
   if(Math.hypot(dx,dy)>58)continue;
   const forwardAngle=this.car.heading-Math.PI/2;
   const body=createRigidBody2D({x:this.car.x,y:this.car.y,vx:Math.sin(this.car.heading)*this.car.speed,vy:-Math.cos(this.car.heading)*this.car.speed,
    angle:forwardAngle,angularVelocity:this.car.angularVelocity??0,mass:1250,length:92,width:44});
   const barrier=createRigidBody2D({x:obstacle.x,y:obstacle.y,angle:obstacle.angle,mass:1,length:34,width:28,static:true});
   const impact=resolveRigidBody2D(body,barrier);
   if(!impact.hit)continue;
   this.car.x=body.x;this.car.y=body.y;this.car.angularVelocity=body.angularVelocity;
   const forwardX=Math.sin(this.car.heading),forwardY=-Math.cos(this.car.heading);
   const forwardSpeed=body.vx*forwardX+body.vy*forwardY;
   const lateralSpeed=body.vx*(-forwardY)+body.vy*forwardX;
   this.car.speed=Math.max(0,forwardSpeed);
   if(Math.abs(lateralSpeed)>8)this.car.heading+=Math.atan2(lateralSpeed,Math.max(20,Math.abs(forwardSpeed)))*.35;
   const localForward=impact.nx*forwardX+impact.ny*forwardY,localRight=impact.nx*(-forwardY)+impact.ny*forwardX;
   addVehicleDamage(this.damage,impact.energy,Math.abs(localForward)>=Math.abs(localRight)?(localForward>=0?"front":"rear"):(localRight>=0?"right":"left"));
   this.hitCooldown=.18;break;
  }
 }
 /** Shared contact hook for future Cocos AI/traffic actors; both vehicles receive the same impulse solve. */
 resolveVehicleContact(other:VehicleController):void {
  if(other===this||this.hitCooldown>0||other.hitCooldown>0)return;
  const make=(v:VehicleController)=>{const fx=Math.sin(v.car.heading),fy=-Math.cos(v.car.heading),rx=Math.cos(v.car.heading),ry=Math.sin(v.car.heading),lateral=v.car.lateralSpeed??0;
   return createRigidBody2D({x:v.car.x,y:v.car.y,vx:fx*v.car.speed+rx*lateral,vy:fy*v.car.speed+ry*lateral,
    angle:v.car.heading-Math.PI/2,angularVelocity:v.car.angularVelocity??0,mass:1250,length:92,width:44,restitution:.12,friction:.72});
  };
  const a=make(this),b=make(other),impact=resolveRigidBody2D(a,b);if(!impact.hit)return;
  const energyShare=splitImpactEnergy(impact.energy,a.invMass,b.invMass);
  for(const [vehicle,body,normalSign,damageEnergy] of [[this,a,1,energyShare.a],[other,b,-1,energyShare.b]] as Array<[VehicleController,ReturnType<typeof make>,number,number]>) {
   vehicle.car.x=body.x;vehicle.car.y=body.y;vehicle.car.angularVelocity=body.angularVelocity;
   const velocity=worldVelocityToCar(body.vx,body.vy,vehicle.car.heading);
   vehicle.car.speed=Math.max(0,velocity.speed);
   vehicle.car.lateralSpeed=velocity.lateralSpeed;
   // Classify the impulse in this vehicle's own forward/right coordinate frame.
   const fx=Math.sin(vehicle.car.heading),fy=-Math.cos(vehicle.car.heading);
   // Keep yaw rate from the impulse solve; VehicleController integrates it at fixed substeps.
   const localF=impact.nx*normalSign*fx+impact.ny*normalSign*fy,localR=impact.nx*normalSign*(-fy)+impact.ny*normalSign*fx;
   addVehicleDamage(vehicle.damage,damageEnergy,Math.abs(localF)>=Math.abs(localR)?(localF>=0?"front":"rear"):(localR>=0?"right":"left"));
   vehicle.hitCooldown=.22;
  }
 }
 resetInput():void {this.input={steer:0,throttle:false,brake:false};this.smoothedSteer=0;}
}
