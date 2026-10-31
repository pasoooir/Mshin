const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
const PANELS=["front","rear","left","right"];
export function createDestructionState(){
 return {damage:0,panels:{front:0,rear:0,left:0,right:0},phase:"intact",smoke:0,fire:0,explosionTriggered:false,burnTime:0,despawned:false};
}
export function applyDestructionImpact(state,{damage=0,panel="front"}={}){
 const amount=clamp(Number.isFinite(damage)?damage:0,0,35),zone=PANELS.includes(panel)?panel:"front";
 state.damage=clamp(state.damage+amount,0,120);
 state.panels[zone]=clamp(state.panels[zone]+amount*.9,0,100);
 state.smoke=clamp(Math.max(state.smoke,(state.damage-18)/62),0,1);
 if(state.damage>=34&&state.phase==="intact")state.phase="scorched";
 if(state.damage>=52&&["intact","scorched"].includes(state.phase))state.phase="smoking";
 if(state.damage>=76&&["intact","scorched","smoking"].includes(state.phase))state.phase="burning";
 if(state.damage>=100&&!state.explosionTriggered){state.explosionTriggered=true;state.phase="exploded";state.fire=1;state.burnTime=0;}
 return {damage:state.damage,soot:clamp(state.panels[zone]/100,0,1),phase:state.phase,explosion:state.explosionTriggered};
}
export function stepDestruction(state,dt){
 const step=clamp(Number.isFinite(dt)?dt:0,0,.1);
 if(state.phase==="exploded"){state.phase="burning";state.burnTime=0;}
 else if(state.phase==="burning"){
  state.burnTime+=step;state.fire=clamp(1-state.burnTime/5,0,1);
  state.smoke=clamp(Math.max(state.smoke,.85-state.burnTime*.1),0,1);
  if(state.burnTime>=5)state.phase="burnt";
 }else if(state.phase==="burnt"){
  state.smoke=clamp(state.smoke-step*.35,0,1);
  if(state.smoke<=0){state.phase="despawned";state.despawned=true;}
 }
 return {phase:state.phase,smoke:state.smoke,fire:state.fire,despawned:state.despawned,explosion:state.explosionTriggered};
}
export function destructionVisuals(state){
 return {soot:{...state.panels},smoke:state.smoke,fire:state.fire,explosion:state.explosionTriggered,despawned:state.despawned,phase:state.phase};
}
