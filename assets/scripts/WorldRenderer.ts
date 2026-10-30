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
  this.drawThemeDecor(g,stage);
  this.drawHazards(g,stage);
  return this.path;
 }
 private drawHazards(g:Graphics,stage:StageDefinition):void {
  for(let i=0;i<stage.hazardCount;i++){
   const index=Math.floor((i+.45)*this.path.length/stage.hazardCount),p=this.path[index],n=this.path[(index+2)%this.path.length];
   const dx=n.y-p.y,dy=p.x-n.x,len=Math.hypot(dx,dy)||1,side=i%2?1:-1,x=p.x+dx/len*stage.trackWidth*.18*side,y=p.y+dy/len*stage.trackWidth*.18*side;
   g.fillColor=color(stage.world.accent);g.circle(x,y,13);g.fill();g.lineWidth=3;g.strokeColor=color("#26313A");g.circle(x,y,13);g.stroke();
  }
 }
 private drawThemeDecor(g:Graphics,stage:StageDefinition):void {
  let seed=stage.seed;const rand=()=>{seed=(seed*9301+49297)%233280;return seed/233280;};
  for(let i=0;i<stage.hazardCount*3;i++){
   const a=rand()*Math.PI*2,r=850+rand()*330,x=Math.cos(a)*r,y=Math.sin(a)*r*.62;
   g.fillColor=color(stage.world.shoulder);
   if(stage.world.decoration==="tree"||stage.world.decoration==="palm"||stage.world.decoration==="pine"){
    g.circle(x,y,10+rand()*12);g.fill();g.fillColor=color(stage.world.accent);g.circle(x-3,y+4,4);g.fill();
   }else if(stage.world.decoration==="dune"){
    g.ellipse(x,y,28,9);g.fill();
   }else if(stage.world.decoration==="tower"||stage.world.decoration==="grandstand"||stage.world.decoration==="ruin"){
    g.rect(x-10,y-18,20,36);g.fill();g.fillColor=color(stage.world.accent);g.rect(x-7,y-12,5,7);g.fill();g.rect(x+2,y-12,5,7);g.fill();
   }else if(stage.world.decoration==="pipe"){
    g.circle(x,y,15);g.strokeColor=color(stage.world.accent);g.lineWidth=6;g.stroke();
   }else if(stage.world.decoration==="planet"){
    g.circle(x,y,14);g.fill();g.ellipse(x,y,26,8);g.strokeColor=color(stage.world.accent);g.lineWidth=3;g.stroke();
   }else{
    g.moveTo(x-16,y-12);g.lineTo(x,y+18);g.lineTo(x+16,y-12);g.close();g.fill();
   }
  }
 }
 private stroke(g:Graphics,path:Point[],width:number,hex:string):void{if(!path.length)return;g.lineWidth=width;g.strokeColor=color(hex);g.moveTo(path[0].x,path[0].y);for(let i=1;i<path.length;i++)g.lineTo(path[i].x,path[i].y);g.close();g.stroke();}
}
