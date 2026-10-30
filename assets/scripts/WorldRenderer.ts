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
   this.drawHazard(g,stage.world.hazard,x,y,stage.world.accent,stage.world.shoulder);
  }
 }
 private drawHazard(g:Graphics,kind:string,x:number,y:number,accent:string,trim:string):void {
  const a=color(accent),t=color(trim);g.lineWidth=3;g.strokeColor=color("#26313A");
  if(kind==="hay bale"){
   g.fillColor=t;g.roundRect(x-18,y-12,36,24,7);g.fill();g.strokeColor=a;g.moveTo(x-10,y-8);g.lineTo(x+9,y+8);g.stroke();
  }else if(kind==="cactus"){
   g.fillColor=color("#438B55");g.roundRect(x-7,y-21,14,42,6);g.fill();g.roundRect(x-19,y-8,13,9,4);g.fill();g.roundRect(x+6,y-1,13,9,4);g.fill();
  }else if(kind==="ice crystal"){
   g.fillColor=color("#B9F4FF");g.moveTo(x,y+22);g.lineTo(x+15,y+2);g.lineTo(x+8,y-18);g.lineTo(x-8,y-18);g.lineTo(x-15,y+2);g.close();g.fill();g.strokeColor=a;g.stroke();
  }else if(kind==="palm stump"){
   g.fillColor=color("#9C6844");g.circle(x,y,17);g.fill();g.strokeColor=t;g.lineWidth=4;g.circle(x,y,11);g.stroke();
  }else if(kind==="neon barrier"){
   g.fillColor=color("#29294B");g.roundRect(x-24,y-9,48,18,5);g.fill();g.strokeColor=a;g.lineWidth=4;g.roundRect(x-24,y-9,48,18,5);g.stroke();g.strokeColor=t;g.lineWidth=3;g.moveTo(x-12,y-6);g.lineTo(x-3,y+6);g.moveTo(x+4,y-6);g.lineTo(x+13,y+6);g.stroke();
  }else if(kind==="crate"){
   g.fillColor=color("#A87948");g.rect(x-16,y-16,32,32);g.fill();g.strokeColor=t;g.lineWidth=4;g.rect(x-16,y-16,32,32);g.moveTo(x-12,y-12);g.lineTo(x+12,y+12);g.moveTo(x+12,y-12);g.lineTo(x-12,y+12);g.stroke();
  }else if(kind==="rock"){
   g.fillColor=color("#737D7E");g.moveTo(x-19,y-5);g.lineTo(x-8,y-18);g.lineTo(x+9,y-15);g.lineTo(x+20,y+5);g.lineTo(x+7,y+17);g.lineTo(x-15,y+12);g.close();g.fill();g.stroke();
  }else if(kind==="pillar"){
   g.fillColor=color("#C9A36B");g.rect(x-11,y-18,22,36);g.fill();g.rect(x-16,y-21,32,7);g.fill();g.rect(x-16,y+14,32,7);g.fill();g.strokeColor=a;g.stroke();
  }else if(kind==="energy gate"){
   g.fillColor=color("#30335C");g.rect(x-20,y-22,8,44);g.rect(x+12,y-22,8,44);g.rect(x-20,y+14,40,8);g.fill();g.strokeColor=a;g.lineWidth=4;g.moveTo(x-12,y+18);g.lineTo(x+12,y+18);g.stroke();
  }else{
   g.fillColor=color("#E6E8F0");g.roundRect(x-19,y-15,38,30,5);g.fill();g.strokeColor=a;g.lineWidth=4;g.roundRect(x-19,y-15,38,30,5);g.stroke();g.strokeColor=color("#26313A");g.lineWidth=3;g.moveTo(x-10,y-12);g.lineTo(x-10,y+12);g.moveTo(x,y-12);g.lineTo(x,y+12);g.moveTo(x+10,y-12);g.lineTo(x+10,y+12);g.stroke();
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
