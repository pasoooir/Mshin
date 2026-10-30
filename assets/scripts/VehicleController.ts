import { _decorator, Component } from "cc";
import { CarState, DriveInput, createRaceState, RaceState, stepCar, updateRace, createVehicleDamage, addVehicleDamage, resolveStaticBarrier, vehicleDamageLevel, CollisionBody } from "../../src/cocos-core";
import { nearestTrackPoint, Point } from "../../src/stage-catalog";
const {ccclass}=_decorator;
@ccclass("MshinVehicleController")
export class VehicleController extends Component {
 readonly car:CarState={x:0,y:0,heading:Math.PI,speed:0};
 readonly race:RaceState=createRaceState();\n readonly damage=createVehicleDamage();
 input:DriveInput={steer:0,throttle:false,brake:false};
 path:Point[]=[];trackWidth=100;targetLaps=3;surfaceGrip=1;obstacles:Point[]=[];private hitCooldown=0;private lastLap=0;private smoothedSteer=0;
 onLap:(lap:number)=>void=()=>{};
 configure(path:Point[],trackWidth:number,laps:number,hazardCount:number,surfaceGrip=1):void {
  this.path=path;this.trackWidth=trackWidth;this.targetLaps=laps;this.surfaceGrip=surfaceGrip;this.obstacles=[];
  for(let i=0;i<hazardCount;i++){const index=Math.floor((i+.45)*path.length/hazardCount),p=path[index],n=path[(index+2)%path.length],dx=n.y-p.y,dy=p.x-n.x,len=Math.hypot(dx,dy)||1,side=i%2?1:-1;this.obstacles.push({x:p.x+dx/len*trackWidth*.18*side,y:p.y+dy/len*trackWidth*.18*side});}
  const start=path[0];this.car.x=start.x;this.car.y=start.y;this.car.heading=Math.PI;this.car.speed=0;Object.assign(this.damage,createVehicleDamage());
  Object.assign(this.race,{lap:0,previousProgress:0,finished:false,elapsedSeconds:0});this.lastLap=0;this.hitCooldown=0;this.node.setPosition(start.x,start.y,0);this.resetInput();
 }
 update(dt:number):void {
  if(this.race.finished||this.path.length<2)return;
  const nearest=nearestTrackPoint(this.car,this.path);
  this.input.offRoad=nearest.distance>this.trackWidth*.34;this.input.grip=this.surfaceGrip;this.input.performance=this.damage.disabled?.3:Math.max(.38,1-this.damage.total*.0048);
  const response=1-Math.exp(-Math.max(0,Math.min(dt,.05))*(Math.abs(this.input.steer)<.001?5:8));this.smoothedSteer+=(this.input.steer-this.smoothedSteer)*response;stepCar(this.car,{...this.input,steer:this.smoothedSteer},dt);
  const hit=nearestTrackPoint(this.car,this.path);const next=this.path[(hit.segment+1)%this.path.length],prev=this.path[hit.segment],tangent=Math.atan2(next.x-prev.x,prev.y-next.y),headingError=Math.atan2(Math.sin(tangent-this.car.heading),Math.cos(tangent-this.car.heading)),assist=Math.max(-Math.max(.8,Math.abs(this.car.speed)/180)*dt,Math.min(Math.max(.8,Math.abs(this.car.speed)/180)*dt,headingError));this.car.heading+=assist*.72;
  if(hit.distance>this.trackWidth*.46){const dx=this.car.x-hit.point.x,dy=this.car.y-hit.point.y,len=Math.hypot(dx,dy)||1,limit=this.trackWidth*.43,nx=dx/len,ny=dy/len;const body:CollisionBody={x:this.car.x,y:this.car.y,vx:Math.sin(this.car.heading)*this.car.speed,vy:-Math.cos(this.car.heading)*this.car.speed,mass:1250,radius:18};const impact=resolveStaticBarrier(body,nx,ny);this.car.x=hit.point.x+nx*limit;this.car.y=hit.point.y+ny*limit;if(impact.hit){this.car.speed=Math.hypot(body.vx,body.vy);this.car.heading=Math.atan2(body.vx,-body.vy);addVehicleDamage(this.damage,impact.energy,Math.abs(nx)>Math.abs(ny)?(nx>0?"right":"left"):"front");}else this.car.speed*=.92;}
  this.hitCooldown=Math.max(0,this.hitCooldown-dt);
  if(this.hitCooldown===0){for(const o of this.obstacles){const dx=this.car.x-o.x,dy=this.car.y-o.y,distance=Math.hypot(dx,dy);if(distance>=31)continue;const body:CollisionBody={x:this.car.x,y:this.car.y,vx:Math.sin(this.car.heading)*this.car.speed,vy:-Math.cos(this.car.heading)*this.car.speed,mass:1250,radius:18},impact=resolveStaticBarrier(body,dx/(distance||1),dy/(distance||1));if(impact.hit){this.car.speed=Math.hypot(body.vx,body.vy);this.car.heading=Math.atan2(body.vx,-body.vy);addVehicleDamage(this.damage,impact.energy,"front");}this.hitCooldown=.65;break;}}
  this.node.setPosition(this.car.x,this.car.y,0);this.node.angle=180-this.car.heading*180/Math.PI;
  updateRace(this.race,this.car.x,this.car.y,dt,this.targetLaps);
  if(this.race.lap!==this.lastLap){this.lastLap=this.race.lap;this.onLap(this.lastLap);}
 }
 resetInput():void {this.input={steer:0,throttle:false,brake:false};this.smoothedSteer=0;}
}
