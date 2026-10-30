import { _decorator, Component } from "cc";
import { CarState, DriveInput, createRaceState, RaceState, stepCar, updateRace } from "../../src/cocos-core";
import { nearestTrackPoint, Point } from "../../src/stage-catalog";
const {ccclass}=_decorator;
@ccclass("MshinVehicleController")
export class VehicleController extends Component {
 readonly car:CarState={x:0,y:0,heading:Math.PI,speed:0};
 readonly race:RaceState=createRaceState();
 input:DriveInput={steer:0,throttle:false,brake:false};
 path:Point[]=[];trackWidth=100;targetLaps=3;surfaceGrip=1;obstacles:Point[]=[];private hitCooldown=0;private lastLap=0;
 onLap:(lap:number)=>void=()=>{};
 configure(path:Point[],trackWidth:number,laps:number,hazardCount:number,surfaceGrip=1):void {
  this.path=path;this.trackWidth=trackWidth;this.targetLaps=laps;this.surfaceGrip=surfaceGrip;this.obstacles=[];
  for(let i=0;i<hazardCount;i++){const index=Math.floor((i+.45)*path.length/hazardCount),p=path[index],n=path[(index+2)%path.length],dx=n.y-p.y,dy=p.x-n.x,len=Math.hypot(dx,dy)||1,side=i%2?1:-1;this.obstacles.push({x:p.x+dx/len*trackWidth*.18*side,y:p.y+dy/len*trackWidth*.18*side});}
  const start=path[0];this.car.x=start.x;this.car.y=start.y;this.car.heading=Math.PI;this.car.speed=0;
  Object.assign(this.race,{lap:0,previousProgress:0,finished:false,elapsedSeconds:0});this.lastLap=0;this.hitCooldown=0;this.node.setPosition(start.x,start.y,0);this.resetInput();
 }
 update(dt:number):void {
  if(this.race.finished||this.path.length<2)return;
  const nearest=nearestTrackPoint(this.car,this.path);
  this.input.offRoad=nearest.distance>this.trackWidth*.34;this.input.grip=this.surfaceGrip;
  stepCar(this.car,this.input,dt);
  const hit=nearestTrackPoint(this.car,this.path);
  if(hit.distance>this.trackWidth*.46){const dx=this.car.x-hit.point.x,dy=this.car.y-hit.point.y,len=Math.hypot(dx,dy)||1,limit=this.trackWidth*.43;this.car.x=hit.point.x+dx/len*limit;this.car.y=hit.point.y+dy/len*limit;this.car.speed*=-.24;}
  this.hitCooldown=Math.max(0,this.hitCooldown-dt);
  if(this.hitCooldown===0&&this.obstacles.some(o=>Math.hypot(this.car.x-o.x,this.car.y-o.y)<31)){this.car.speed*=.42;this.hitCooldown=.65;}
  this.node.setPosition(this.car.x,this.car.y,0);this.node.angle=90-this.car.heading*180/Math.PI;
  updateRace(this.race,this.car.x,this.car.y,dt,this.targetLaps);
  if(this.race.lap!==this.lastLap){this.lastLap=this.race.lap;this.onLap(this.lastLap);}
 }
 resetInput():void {this.input={steer:0,throttle:false,brake:false};}
}
