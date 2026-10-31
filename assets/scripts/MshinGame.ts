import { _decorator, Component, Node, Graphics, Label, UITransform, Color, Camera, Canvas, view, EventTouch, ResolutionPolicy, macro, Input, input, KeyCode, JsonAsset, resources } from "cc";
import { STAGES, WORLD_THEMES, StageDefinition, generateTrackPath, nearestTrackPoint } from "../../src/stage-catalog";
import { calculateRacingLineTarget, calculateAiTargetSpeed } from "../../src/cocos-core";
import { VehicleController } from "./VehicleController";
import { VehicleDamageRenderer } from "./VehicleDamageRenderer";
import { WorldRenderer } from "./WorldRenderer";
import { ProgressStore, PlayerProgress } from "./ProgressStore";
const {ccclass}=_decorator;
type Screen="home"|"worlds"|"stages"|"race"|"paused"|"finished";
const hex=(v:string)=>{const h=v.replace("#","");return new Color(parseInt(h.slice(0,2),16),parseInt(h.slice(2,4),16),parseInt(h.slice(4,6),16),255);};
@ccclass("MshinGame")
export class MshinGame extends Component {
 private screen:Screen="home";private stage:StageDefinition=STAGES[0];private progress:PlayerProgress=ProgressStore.load();private selectedWorld=0;
 private cameraNode!:Node;private camera!:Camera;private worldRoot!:Node;private hudCanvas!:Node;private hudRoot!:Node;private menuRoot!:Node;private worldNode!:Node;private carNode!:Node;private vehicle!:VehicleController;private rivals:VehicleController[]=[];
 private labels=new Map<string,Label>();private uiNodes:Node[]=[];private joystick!:Node;private knob!:Node;private stickId=-1;
 private lastSize={width:0,height:0};private finishHandled=false;private artLibrary:any=null;private hudRefresh=0;
 start():void {
  view.setDesignResolutionSize(1280,720,ResolutionPolicy.FIXED_HEIGHT);view.setOrientation(macro.ORIENTATION_LANDSCAPE);
  const scene=this.node.scene;if(!scene)throw new Error("Attach MshinGame to a node in the active Cocos Creator scene.");
  this.cameraNode=new Node("Mshin Camera");scene.addChild(this.cameraNode);this.cameraNode.setPosition(0,0,1000);
  this.camera=this.cameraNode.addComponent(Camera);this.camera.projection=Camera.ProjectionType.ORTHO;this.camera.orthoHeight=720;this.camera.near=1;this.camera.far=2000;this.camera.priority=1;
  this.worldRoot=new Node("World Canvas");scene.addChild(this.worldRoot);
  this.worldRoot.addComponent(UITransform).setContentSize(5200,3600);
  const worldCanvas=this.worldRoot.addComponent(Canvas);worldCanvas.cameraComponent=this.camera;worldCanvas.alignCanvasWithScreen=false;
  this.worldNode=new Node("Generated World");this.worldRoot.addChild(this.worldNode);
  this.carNode=new Node("Player Car");this.worldRoot.addChild(this.carNode);this.drawCar();
  this.vehicle=this.carNode.addComponent(VehicleController);
  this.hudCanvas=new Node("HUD Canvas");this.cameraNode.addChild(this.hudCanvas);this.hudCanvas.setPosition(0,0,-900);
  this.hudCanvas.addComponent(UITransform).setContentSize(1280,720);
  const uiCanvas=this.hudCanvas.addComponent(Canvas);uiCanvas.cameraComponent=this.camera;uiCanvas.alignCanvasWithScreen=false;
  this.hudRoot=new Node("HUD and Menus");this.hudCanvas.addChild(this.hudRoot);this.menuRoot=new Node("Responsive Menu Layer");this.hudRoot.addChild(this.menuRoot);
  this.createPersistentHud();this.bindKeyboard();this.showLoading();this.resizeUi();
  resources.load("vector-art",JsonAsset,(error,asset)=>{if(!error&&asset)this.artLibrary=asset.json;else console.warn("Mshin Cocos vector art preload failed; procedural Graphics fallback will be used.",error);this.showHome();});
 }
 update(dt:number):void {
  if(this.screen==="race"){
   this.updateRivalTraffic();this.resolveTrafficContacts();
   this.cameraNode.setPosition(this.vehicle.car.x,this.vehicle.car.y,1000);this.cameraNode.angle=-this.carNode.angle;this.hudCanvas.angle=this.carNode.angle;
   this.hudRefresh+=dt;if(this.hudRefresh>=.1){this.hudRefresh=0;
    this.setText("speed","سرعت  "+Math.round(Math.abs(this.vehicle.car.speed)*.42));
    this.setText("damage","بدنه  "+Math.round(this.vehicle.damage.total)+"٪");
    this.setText("time","زمان  "+this.format(this.vehicle.race.elapsedSeconds));
    this.setText("lap","دور  "+this.vehicle.race.lap+" / "+this.stage.laps);
   }
   if(this.vehicle.race.finished&&!this.finishHandled){this.finishHandled=true;this.progress=ProgressStore.complete(this.stage,this.vehicle.race.elapsedSeconds);this.showFinished();}
  }
  const s=view.getVisibleSize();if(s.width!==this.lastSize.width||s.height!==this.lastSize.height)this.resizeUi();
 }
 private makeNode(name:string,parent:Node):Node {const n=new Node(name);parent.addChild(n);n.addComponent(UITransform).setContentSize(120,60);return n;}
 private createPersistentHud():void {
  const bg=this.makeNode("HUD Backdrop",this.hudRoot);const g=bg.addComponent(Graphics);g.fillColor=new Color(18,32,52,220);g.roundRect(-610,300,1220,86,18);g.fill();
  this.addLabel("brand","مِشین • مسابقه آرکید",0,330,26,false);
  this.addLabel("world","",0,294,15,false);
  this.addLabel("lap","دور  ۰ / ۳",-420,330,18,false);this.addLabel("time","زمان  ۰۰:۰۰",-260,330,18,false);this.addLabel("speed","سرعت  ۰",-90,330,18,false);this.addLabel("damage","بدنه  ۰٪",120,330,18,false);
 }
 private addLabel(id:string,text:string,x:number,y:number,size:number,transient:boolean):Label {
  const n=this.makeNode("Label "+id,transient?this.menuRoot:this.hudRoot);n.setPosition(x,y,0);n.getComponent(UITransform)!.setContentSize(390,48);
  const l=n.addComponent(Label);l.string=text;l.fontSize=size;l.lineHeight=size+5;l.color=new Color(255,255,255,255);l.horizontalAlign=Label.HorizontalAlign.CENTER;l.verticalAlign=Label.VerticalAlign.CENTER;
  this.labels.set(id,l);if(transient)this.uiNodes.push(n);return l;
 }
 private setText(id:string,value:string):void {const l=this.labels.get(id);if(l)l.string=value;}
 private clearUi():void {for(const n of this.uiNodes){this.labels.forEach((v,k)=>{if(v.node===n)this.labels.delete(k);});n.destroy();}this.uiNodes=[];}
 private addUiLabel(text:string,x:number,y:number,size:number):void {this.addLabel("screen-"+this.uiNodes.length,text,x,y,size,true);}
 private button(text:string,x:number,y:number,w:number,h:number,action:()=>void):Node {
  const n=this.makeNode("Button "+text,this.menuRoot);n.setPosition(x,y,0);n.getComponent(UITransform)!.setContentSize(w,h);
  const g=n.addComponent(Graphics);
  g.fillColor=hex("#14253A");g.moveTo(-w/2+7,-h/2);g.lineTo(w/2-18,-h/2);g.lineTo(w/2,h/2);g.lineTo(-w/2+7,h/2);g.close();g.fill();
  g.strokeColor=hex("#536A80");g.lineWidth=2;g.moveTo(-w/2+7,-h/2);g.lineTo(w/2-18,-h/2);g.lineTo(w/2,h/2);g.lineTo(-w/2+7,h/2);g.close();g.stroke();
  g.fillColor=hex("#F33A52");g.moveTo(-w/2+7,-h/2);g.lineTo(-w/2+15,-h/2);g.lineTo(-w/2+15,h/2);g.lineTo(-w/2+7,h/2);g.close();g.fill();
  g.fillColor=hex("#FFFFFF");g.moveTo(w/2-23,-h/2+7);g.lineTo(w/2-18,-h/2+7);g.lineTo(w/2-8,h/2-7);g.lineTo(w/2-13,h/2-7);g.close();g.fill();
  const labelNode=this.makeNode("Button Label",n);labelNode.getComponent(UITransform)!.setContentSize(w-28,h-8);
  const l=labelNode.addComponent(Label);l.string=text;l.fontSize=Math.min(24,h*.36);l.color=hex("#F3F7FC");l.horizontalAlign=Label.HorizontalAlign.CENTER;l.verticalAlign=Label.VerticalAlign.CENTER;
  n.on(Node.EventType.TOUCH_END,action,this);this.uiNodes.push(n);return n;
 }
 private drawMenuBackdrop(kicker:string,subtitle:string):void {
  const n=this.makeNode("Motorsport Menu Backdrop",this.menuRoot);n.getComponent(UITransform)!.setContentSize(1280,720);
  const g=n.addComponent(Graphics);g.fillColor=hex("#081321");g.rect(-640,-360,1280,720);g.fill();
  g.fillColor=hex("#10243A");g.moveTo(-640,-360);g.lineTo(-180,-360);g.lineTo(250,360);g.lineTo(-640,360);g.close();g.fill();
  g.fillColor=hex("#F33A52");g.moveTo(-640,250);g.lineTo(-640,360);g.lineTo(-565,360);g.lineTo(-615,250);g.close();g.fill();
  g.fillColor=hex("#1A344C");g.moveTo(310,-360);g.lineTo(640,-360);g.lineTo(640,360);g.lineTo(520,360);g.close();g.fill();
  g.strokeColor=hex("#F33A52");g.lineWidth=5;g.moveTo(-610,-300);g.lineTo(-430,-300);g.stroke();
  g.strokeColor=hex("#34506A");g.lineWidth=2;for(let i=0;i<9;i++){const y=-220+i*52;g.moveTo(350,y);g.lineTo(620,y);g.stroke();}
  g.fillColor=hex("#FFFFFF");g.moveTo(410,290);g.lineTo(600,290);g.lineTo(620,310);g.lineTo(410,310);g.close();g.fill();
  g.fillColor=hex("#F33A52");g.moveTo(580,290);g.lineTo(600,290);g.lineTo(620,310);g.lineTo(600,310);g.close();g.fill();
  this.uiNodes.push(n);n.setSiblingIndex(0);
  this.addUiLabel(kicker,0,300,14);this.addUiLabel(subtitle,0,265,17);
 }
 private addButton(text:string,x:number,y:number,w:number,h:number,fn:()=>void):void {this.button(text,x,y,w,h,fn);}
 private drawStagePreview(stage:StageDefinition,x:number,y:number):void {
  const n=this.makeNode("Stage Preview "+stage.id,this.menuRoot);n.setPosition(x,y,0);n.getComponent(UITransform)!.setContentSize(180,78);
  const g=n.addComponent(Graphics);g.fillColor=hex(stage.world.ground);g.roundRect(-90,-39,180,78,10);g.fill();
  const path=generateTrackPath(stage,48),draw=(width:number,stroke:string)=>{g.lineWidth=width;g.strokeColor=hex(stroke);g.moveTo(path[0].x*.1,path[0].y*.1);for(let i=1;i<path.length;i++)g.lineTo(path[i].x*.1,path[i].y*.1);g.close();g.stroke();};
  draw(15,stage.world.shoulder);draw(9,stage.world.road);
  g.fillColor=hex(stage.world.accent);for(let i=0;i<path.length;i+=12){g.circle(path[i].x*.1,path[i].y*.1,2.5);g.fill();}
  this.uiNodes.push(n);
 }
 private showLoading():void {this.screen="home";this.clearUi();this.addUiLabel("در حال آماده‌سازی دنیای مسابقه",0,40,30);this.addUiLabel("در حال بارگذاری تصاویر و رنگ‌بندی خودروها…",0,-25,18);}
 private showHome():void {
  this.clearRivals();this.screen="home";this.clearUi();this.drawMenuBackdrop("MSHIN MOTORSPORT","مسابقه را انتخاب کن؛ مسیر بعدی منتظر توست");
  this.addUiLabel("MSHIN",0,135,76);this.addUiLabel("۵۰ پیست  •  ۱۰ دنیای متفاوت  •  یک قهرمان",0,72,21);
  this.addUiLabel("مرحله بعدی  "+this.progress.unlockedStage+" / ۵۰",0,-225,19);
  this.addButton("شروع مسابقه",0,-35,330,76,()=>this.startStage(this.progress.unlockedStage));
  this.addButton("انتخاب دنیا",0,-135,330,66,()=>this.showWorlds());
 }
 private showWorlds():void {
  this.screen="worlds";this.clearUi();this.drawMenuBackdrop("WORLD SELECT","جهان مورد علاقه‌ات را برای مسابقه انتخاب کن");this.addUiLabel("انتخاب دنیای مسابقه",0,215,34);
  WORLD_THEMES.forEach((world,i)=>{const col=i%5,row=Math.floor(i/5),x=(col-2)*220,y=100-row*170;this.addButton(world.name,x,y,196,110,()=>{this.selectedWorld=i;this.showStages();});});
  this.addButton("بازگشت",0,-280,170,54,()=>this.showHome());
 }
 private showStages():void {
  this.screen="stages";this.clearUi();const world=WORLD_THEMES[this.selectedWorld];this.drawMenuBackdrop("STAGE SELECT",world.name+"  •  انتخاب مرحله");this.addUiLabel(world.name.toUpperCase()+"  •  انتخاب مرحله",0,215,29);
  for(let i=0;i<5;i++){const s=STAGES[this.selectedWorld*5+i],unlocked=ProgressStore.isUnlocked(s.id,this.progress),x=(i-2)*230;
   this.addButton((unlocked?"▶ ":"🔒 ")+String(s.stageInWorld).padStart(2,"0")+"  "+s.name,x,35,210,112,()=>{if(unlocked)this.startStage(s.id);});
   this.drawStagePreview(s,x,155);
   this.addUiLabel(this.progress.completed.includes(s.id)?"✓ تکمیل‌شده":unlocked?"آماده":"قفل‌شده",x,-42,13);
  }
  this.addButton("بازگشت",0,-205,170,54,()=>this.showWorlds());
 }
 private startStage(id:number):void {
  this.clearRivals();this.stage=STAGES[id-1];this.screen="race";this.clearUi();this.finishHandled=false;
  this.worldNode.destroyAllChildren();const rn=new Node("World Renderer");this.worldNode.addChild(rn);const renderer=rn.addComponent(WorldRenderer);
  const path=renderer.configure(this.stage,this.artLibrary);
  this.carNode.destroy();this.carNode=new Node("Player Car");this.worldRoot.addChild(this.carNode);this.drawCar();
  this.vehicle=this.carNode.addComponent(VehicleController);this.vehicle.configure(path,this.stage.trackWidth,this.stage.laps,this.stage.hazardCount,this.stage.world.grip);
  const damageFxNode=new Node("Vehicle Damage FX");damageFxNode.setPosition(0,0,1);this.carNode.addChild(damageFxNode);const damageRenderer=damageFxNode.addComponent(VehicleDamageRenderer);damageRenderer.bind(this.vehicle);
  this.vehicle.onLap=(lap)=>this.setText("lap","دور  "+lap+" / "+this.stage.laps);
  this.spawnRivals(path);
  this.setText("world",this.stage.world.name+"  •  مرحله "+String(id).padStart(2,"۰"));
  this.createControls();this.cameraNode.setPosition(this.vehicle.car.x,this.vehicle.car.y,1000);
 }
 private spawnRivals(path:{x:number;y:number}[]):void {
  const paints=["#36B7E8","#E6A23C","#9B7AE8"];
  for(let i=0;i<3;i++){
   const node=new Node("AI Rival "+(i+1));this.worldRoot.addChild(node);node.setScale(1.25,1.25,1);
   const g=node.addComponent(Graphics),body=hex(paints[i]);
   g.fillColor=new Color(4,12,24,70);g.ellipse(2,-3,22,39);g.fill();
   g.fillColor=hex("#26313A");g.roundRect(-22,-27,12,21,4);g.fill();g.roundRect(10,-27,12,21,4);g.fill();g.roundRect(-22,8,12,21,4);g.fill();g.roundRect(10,8,12,21,4);g.fill();
   g.fillColor=body;g.roundRect(-16,-37,32,74,10);g.fill();g.strokeColor=hex("#FFFFFF");g.lineWidth=2;g.roundRect(-16,-37,32,74,10);g.stroke();
   g.fillColor=hex("#26313A");g.roundRect(-12,-12,24,31,6);g.fill();g.fillColor=hex("#BDEEFF");g.roundRect(-11,-10,22,25,5);g.fill();
   g.fillColor=hex("#FFF5C8");g.circle(-9,31,3);g.fill();g.circle(9,31,3);g.fill();
   const controller=node.addComponent(VehicleController);
   controller.configure(path,this.stage.trackWidth,999,0,this.stage.world.grip);
   const index=Math.floor(path.length*(i+1)/4),p=path[index],next=path[(index+1)%path.length],prev=path[(index+path.length-1)%path.length];
   const laneOffset=(i-1)*this.stage.trackWidth*.14,tx=next.x-prev.x,ty=next.y-prev.y,tlen=Math.hypot(tx,ty)||1,nx=-ty/tlen,ny=tx/tlen;
   controller.car.x=p.x+nx*laneOffset;controller.car.y=p.y+ny*laneOffset;controller.car.heading=Math.atan2(next.x-p.x,p.y-next.y);
   controller.car.speed=0;node.setPosition(controller.car.x,controller.car.y,0);node.angle=180-controller.car.heading*180/Math.PI;
   const fx=new Node("Rival Damage FX");fx.setPosition(0,0,1);node.addChild(fx);fx.addComponent(VehicleDamageRenderer).bind(controller);
   this.rivals.push(controller);
  }
 }
 private updateRivalTraffic():void {
  for(const rival of this.rivals){
   if(!rival.enabled||rival.path.length<2)continue;
   const nearest=nearestTrackPoint(rival.car,rival.path),lookAhead=8;
   const targetIndex=(nearest.segment+lookAhead)%rival.path.length;
   const laneIndex=this.rivals.indexOf(rival),laneOffset=(laneIndex-1)*this.stage.trackWidth*.14;
   const target=calculateRacingLineTarget(rival.path,targetIndex,laneOffset);
   const desired=Math.atan2(target.x-rival.car.x,rival.car.y-target.y);
   const error=Math.atan2(Math.sin(desired-rival.car.heading),Math.cos(desired-rival.car.heading));
   const before=rival.path[(targetIndex+rival.path.length-2)%rival.path.length],next=rival.path[(targetIndex+1)%rival.path.length];
   const incoming=Math.atan2(target.y-before.y,target.x-before.x),outgoing=Math.atan2(next.y-target.y,next.x-target.x);
   const turn=Math.atan2(Math.sin(outgoing-incoming),Math.cos(outgoing-incoming));
   const targetSpeed=calculateAiTargetSpeed(turn);
   rival.input.steer=Math.max(-1,Math.min(1,error*1.75));
   rival.input.throttle=Math.abs(error)<.82&&rival.car.speed<targetSpeed;
   rival.input.brake=Math.abs(error)>1.0||rival.car.speed>targetSpeed+18;
  }
 }
 private resolveTrafficContacts():void {
  const traffic=[this.vehicle,...this.rivals].filter(v=>v&&v.enabled);
  for(let i=0;i<traffic.length;i++)for(let j=i+1;j<traffic.length;j++)traffic[i].resolveVehicleContact(traffic[j]);
 }
 private clearRivals():void {
  for(const rival of this.rivals){rival.resetInput();rival.node.destroy();}
  this.rivals=[];
 }
 private createControls():void {
  this.joystick=this.makeNode("Virtual Joystick",this.hudRoot);this.uiNodes.push(this.joystick);this.joystick.setPosition(-500,-250,0);this.joystick.getComponent(UITransform)!.setContentSize(184,132);
  const jg=this.joystick.addComponent(Graphics);jg.fillColor=new Color(20,38,62,225);jg.strokeColor=new Color(220,238,255,190);jg.lineWidth=4;jg.roundRect(-92,-66,184,132,48);jg.fill();jg.stroke();
  this.knob=this.makeNode("Joystick Knob",this.joystick);this.knob.getComponent(UITransform)!.setContentSize(68,52);const kg=this.knob.addComponent(Graphics);kg.fillColor=hex("#EAF6D5");kg.roundRect(-34,-26,68,52,22);kg.fill();kg.strokeColor=hex("#407B50");kg.lineWidth=4;kg.roundRect(-34,-26,68,52,22);kg.stroke();
  this.joystick.on(Node.EventType.TOUCH_START,this.onStickStart,this);this.joystick.on(Node.EventType.TOUCH_MOVE,this.onStickMove,this);this.joystick.on(Node.EventType.TOUCH_END,this.onStickEnd,this);this.joystick.on(Node.EventType.TOUCH_CANCEL,this.onStickEnd,this);
  this.holdButton("ترمز",350,-250,130,86,(v)=>this.vehicle.input.brake=v);
  this.holdButton("گاز",510,-220,145,112,(v)=>this.vehicle.input.throttle=v);
  this.addButton("Ⅱ",560,300,72,54,()=>this.pauseRace());
 }
 private holdButton(text:string,x:number,y:number,w:number,h:number,change:(held:boolean)=>void):void {
  const n=this.makeNode(text,this.hudRoot);n.setPosition(x,y,0);n.getComponent(UITransform)!.setContentSize(w,h);
  const g=n.addComponent(Graphics);g.fillColor=hex(text==="گاز"?"#F18B3B":"#4779C7");g.roundRect(-w/2,-h/2,w,h,18);g.fill();g.strokeColor=hex("#FFFFFF");g.lineWidth=3;g.roundRect(-w/2,-h/2,w,h,18);g.stroke();
  const labelNode=this.makeNode("Pedal Label",n);labelNode.getComponent(UITransform)!.setContentSize(w-12,h-8);
  const l=labelNode.addComponent(Label);l.string=text;l.fontSize=22;l.color=hex("#FFFFFF");l.horizontalAlign=Label.HorizontalAlign.CENTER;l.verticalAlign=Label.VerticalAlign.CENTER;
  n.on(Node.EventType.TOUCH_START,()=>change(true),this);n.on(Node.EventType.TOUCH_END,()=>change(false),this);n.on(Node.EventType.TOUCH_CANCEL,()=>change(false),this);this.uiNodes.push(n);
 }
 private onStickStart(e:EventTouch):void {this.stickId=e.getID();this.onStickMove(e);}
 private onStickMove(e:EventTouch):void {if(e.getID()!==this.stickId)return;const p=this.joystick.getComponent(UITransform)!.convertToNodeSpaceAR(e.getUILocation()),limit=58,raw=Math.max(-1,Math.min(1,p.x/limit)),m=Math.abs(raw),dead=.07,linear=m<=dead?0:(m-dead)/(1-dead);this.knob.setPosition(Math.max(-limit,Math.min(limit,p.x)),0,0);this.vehicle.input.steer=Math.sign(raw)*Math.pow(linear,1.28);}
 private onStickEnd(e:EventTouch):void {if(e.getID()!==this.stickId)return;this.stickId=-1;this.knob.setPosition(0,0,0);this.vehicle.input.steer=0;}
 private pauseRace():void {
  if(this.screen!=="race")return;this.screen="paused";this.vehicle.enabled=false;this.vehicle.resetInput();for(const rival of this.rivals){rival.enabled=false;rival.resetInput();}this.clearUi();
  const overlay=this.makeNode("Pause Screen Overlay",this.menuRoot);overlay.getComponent(UITransform)!.setContentSize(1280,720);const shade=overlay.addComponent(Graphics);shade.fillColor=new Color(3,8,14,190);shade.rect(-640,-360,1280,720);shade.fill();this.uiNodes.push(overlay);overlay.setSiblingIndex(0);
  this.addUiLabel("PAUSE", -470, 305, 42);this.addUiLabel("MSHIN MOTORSPORT  /  EVENT PAUSED",-220,258,14);
  const entries:[string,number,boolean,()=>void][]=[
   ["CONTINUE",190,true,()=>{this.screen="race";this.clearUi();this.vehicle.enabled=true;for(const rival of this.rivals)rival.enabled=true;this.createControls();}],
   ["RETRY",125,true,()=>this.startStage(this.stage.id)],
   ["LEAVE EVENT",60,true,()=>{this.vehicle.enabled=false;this.showHome();}],
   ["DRIVER DETAILS",-5,false,()=>{}],["MAP",-70,false,()=>{}],["MULTIPLAYER",-135,false,()=>{}],["FRIENDS",-200,false,()=>{}],["SETTINGS",-265,false,()=>{}]
  ];
  entries.forEach(([label,y,active,action],index)=>this.addPauseEntry(label,-390,y,active,action,index===0));
  this.addUiLabel("MOST WANTED",330,270,32);
  const rivals=[["01","Mshin Driver","YOUR CAR"],["02","Rival Alpha","SPORT CLASS"],["03","Rival Bravo","RALLY CLASS"],["04","Rival Charlie","GT CLASS"],["05","Rival Delta","PRO CLASS"]];
  rivals.forEach((row,i)=>this.addWantedRow(row[0],row[1],row[2],330,175-i*82,i===0));
 }
 private addPauseEntry(label:string,x:number,y:number,active:boolean,action:()=>void,selected=false):void {
  const n=this.makeNode("Pause Entry "+label,this.menuRoot);n.setPosition(x,y,0);n.getComponent(UITransform)!.setContentSize(365,52);const g=n.addComponent(Graphics);
  g.fillColor=active?hex(selected?"#202A32":"#111A22"):hex("#111820");g.moveTo(-182,-26);g.lineTo(160,-26);g.lineTo(182,26);g.lineTo(-182,26);g.close();g.fill();
  g.fillColor=hex(active?"#E51E35":"#59616A");g.moveTo(-182,-26);g.lineTo(-165,-26);g.lineTo(-165,26);g.lineTo(-182,26);g.close();g.fill();
  g.fillColor=hex("#E9EDF0");g.moveTo(145,-26);g.lineTo(160,-26);g.lineTo(182,26);g.lineTo(167,26);g.close();g.fill();
  const t=this.makeNode("Pause Entry Label",n);t.getComponent(UITransform)!.setContentSize(315,46);const l=t.addComponent(Label);l.string=label;l.fontSize=active?20:18;l.color=hex(active?"#FFFFFF":"#9AA4AD");l.horizontalAlign=Label.HorizontalAlign.LEFT;l.verticalAlign=Label.VerticalAlign.CENTER;
  if(active)n.on(Node.EventType.TOUCH_END,action,this);this.uiNodes.push(n);
 }
 private addWantedRow(rank:string,name:string,detail:string,x:number,y:number,player=false):void {
  const n=this.makeNode("Most Wanted "+rank,this.menuRoot);n.setPosition(x,y,0);n.getComponent(UITransform)!.setContentSize(510,66);const g=n.addComponent(Graphics);
  g.fillColor=hex(player?"#D5D9DC":"#111A22");g.moveTo(-255,-33);g.lineTo(240,-33);g.lineTo(255,33);g.lineTo(-240,33);g.close();g.fill();
  g.fillColor=hex("#E51E35");g.moveTo(-255,-33);g.lineTo(-185,-33);g.lineTo(-170,33);g.lineTo(-240,33);g.close();g.fill();
  const rankNode=this.makeNode("Wanted Rank",n);rankNode.getComponent(UITransform)!.setContentSize(62,56);const rl=rankNode.addComponent(Label);rl.string=rank;rl.fontSize=30;rl.color=hex("#FFFFFF");rl.horizontalAlign=Label.HorizontalAlign.CENTER;rl.verticalAlign=Label.VerticalAlign.CENTER;rankNode.setPosition(-215,0,0);
  const title=this.makeNode("Wanted Driver",n);title.getComponent(UITransform)!.setContentSize(300,30);const tl=title.addComponent(Label);tl.string=name;tl.fontSize=player?18:17;tl.color=hex(player?"#18232C":"#F04455");tl.horizontalAlign=Label.HorizontalAlign.LEFT;tl.verticalAlign=Label.VerticalAlign.CENTER;title.setPosition(25,10,0);
  const sub=this.makeNode("Wanted Detail",n);sub.getComponent(UITransform)!.setContentSize(300,22);const sl=sub.addComponent(Label);sl.string=detail;sl.fontSize=12;sl.color=hex(player?"#35424D":"#B7C0C8");sl.horizontalAlign=Label.HorizontalAlign.LEFT;sl.verticalAlign=Label.VerticalAlign.CENTER;sub.setPosition(25,-15,0);this.uiNodes.push(n);
 }
 private showFinished():void {
  this.screen="finished";this.vehicle.enabled=false;this.vehicle.resetInput();for(const rival of this.rivals){rival.enabled=false;rival.resetInput();}this.clearUi();this.drawMenuBackdrop("RACE COMPLETE","عملکردت ثبت شد؛ آماده مرحله بعدی باش");
  this.addUiLabel("🏆  پایان مسابقه!",0,85,56);this.addUiLabel("زمان  "+this.format(this.vehicle.race.elapsedSeconds),0,15,24);
  this.addButton("مرحله بعد",0,-75,250,70,()=>this.startStage(Math.min(50,this.stage.id+1)));
  this.addButton("منوی اصلی",0,-165,230,58,()=>this.showHome());
 }
 private drawCar():void {
  this.carNode.setScale(1.25,1.25,1);
  const g=this.carNode.addComponent(Graphics),paint=this.artLibrary?.cars?.rally??{body:"#F15D4E",highlight:"#FFD4A5",glass:"#BDEEFF",trim:"#26313A"};
  g.fillColor=new Color(4,12,24,75);g.ellipse(2,-3,22,39);g.fill();
  g.fillColor=hex(paint.trim);g.roundRect(-22,-27,12,21,4);g.fill();g.roundRect(10,-27,12,21,4);g.fill();g.roundRect(-22,8,12,21,4);g.fill();g.roundRect(10,8,12,21,4);g.fill();
  g.fillColor=hex(paint.body);g.roundRect(-16,-37,32,74,10);g.fill();g.strokeColor=hex(paint.highlight);g.lineWidth=2;g.roundRect(-16,-37,32,74,10);g.stroke();
  g.fillColor=hex(paint.trim);g.roundRect(-12,-12,24,31,6);g.fill();g.fillColor=hex(paint.glass);g.roundRect(-11,-10,22,25,5);g.fill();
  g.fillColor=hex(paint.highlight);g.roundRect(-12,21,24,8,3);g.fill();g.fillColor=hex("#FFF5C8");g.circle(-9,31,3);g.fill();g.circle(9,31,3);g.fill();
  g.fillColor=hex("#FF665F");g.roundRect(-11,-35,7,4,2);g.fill();g.roundRect(4,-35,7,4,2);g.fill();
 }
 private bindKeyboard():void {
  input.on(Input.EventType.KEY_DOWN,(e)=>{if(this.screen!=="race")return;
   if(e.keyCode===KeyCode.ARROW_LEFT||e.keyCode===KeyCode.KEY_A)this.vehicle.input.steer=-1;
   if(e.keyCode===KeyCode.ARROW_RIGHT||e.keyCode===KeyCode.KEY_D)this.vehicle.input.steer=1;
   if(e.keyCode===KeyCode.ARROW_UP||e.keyCode===KeyCode.KEY_W)this.vehicle.input.throttle=true;
   if(e.keyCode===KeyCode.SPACE||e.keyCode===KeyCode.ARROW_DOWN)this.vehicle.input.brake=true;
   if(e.keyCode===KeyCode.ESCAPE)this.pauseRace();
  });
  input.on(Input.EventType.KEY_UP,(e)=>{if(this.screen!=="race")return;
   if([KeyCode.ARROW_LEFT,KeyCode.KEY_A,KeyCode.ARROW_RIGHT,KeyCode.KEY_D].includes(e.keyCode))this.vehicle.input.steer=0;
   if(e.keyCode===KeyCode.ARROW_UP||e.keyCode===KeyCode.KEY_W)this.vehicle.input.throttle=false;
   if(e.keyCode===KeyCode.SPACE||e.keyCode===KeyCode.ARROW_DOWN)this.vehicle.input.brake=false;
  });
 }
 private resizeUi():void {
  const s=view.getVisibleSize();this.lastSize={width:s.width,height:s.height};this.camera.orthoHeight=s.height;const menuScale=Math.max(.45,Math.min(1,s.width/1280,s.height/720));this.menuRoot.setScale(menuScale,menuScale,1);this.menuRoot.setPosition(0,0,0);
  const pos=(name:string,x:number,y:number)=>{const n=this.hudRoot.getChildByName(name);if(n)n.setPosition(x,y,0);};
  pos("HUD Backdrop",0,s.height/2-52);pos("Label brand",0,s.height/2-26);pos("Label world",0,s.height/2-62);
  pos("Label lap",-s.width/2+150,s.height/2-26);pos("Label time",-s.width/2+320,s.height/2-26);pos("Label speed",-s.width/2+485,s.height/2-26);
  pos("Virtual Joystick",-s.width/2+105,-s.height/2+105);pos("ترمز",s.width/2-260,-s.height/2+105);pos("گاز",s.width/2-105,-s.height/2+112);
  pos("Button Ⅱ",s.width/2-60,s.height/2-60);
 }
 private format(seconds:number):string {const m=Math.floor(seconds/60),v=Math.floor(seconds%60);return String(m).padStart(2,"0")+":"+String(v).padStart(2,"0");}
 onDestroy():void {input.targetOff(this);}
}
