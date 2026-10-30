import { _decorator, Component, Graphics, Color, UITransform } from "cc";
import { StageDefinition, generateTrackPath, Point } from "../../src/stage-catalog";
const {ccclass}=_decorator;
function color(hex:string):Color{const h=hex.slice(1);return new Color(parseInt(h.slice(0,2),16),parseInt(h.slice(2,4),16),parseInt(h.slice(4,6),16),255);}
@ccclass("MshinWorldRenderer")
export class WorldRenderer extends Component {
 path:Point[]=[];
 configure(stage:StageDefinition):Point[] {
  this.path=generateTrackPath(stage);const ui=this.getComponent(UITransform)??this.addComponent(UITransform);ui.setContentSize(3600,2400);const g=this.getComponent(Graphics)??this.addComponent(Graphics);g.clear();
  g.fillColor=color(stage.world.ground);g.rect(-1800,-1200,3600,2400);g.fill();
  this.stroke(g,this.path,stage.trackWidth+64,stage.world.shoulder);
  this.stroke(g,this.path,stage.trackWidth,stage.world.road);
  g.lineWidth=4;g.strokeColor=color(stage.world.accent);
  for(let i=0;i<this.path.length;i+=8){const p=this.path[i];g.circle(p.x,p.y,4);g.stroke();}
  let seed=stage.seed;const rand=()=>{seed=(seed*9301+49297)%233280;return seed/233280;};
  for(let i=0;i<stage.hazardCount*4;i++){const a=rand()*Math.PI*2,r=850+rand()*300;g.fillColor=color(i%3?stage.world.shoulder:stage.world.accent);g.circle(Math.cos(a)*r,Math.sin(a)*r*.62,8+rand()*15);g.fill();}
  return this.path;
 }
 private stroke(g:Graphics,path:Point[],width:number,hex:string):void{if(!path.length)return;g.lineWidth=width;g.strokeColor=color(hex);g.moveTo(path[0].x,path[0].y);for(let i=1;i<path.length;i++)g.lineTo(path[i].x,path[i].y);g.close();g.stroke();}
}
