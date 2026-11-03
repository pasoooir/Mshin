export function createCityCameraController({canvas,camera,getRenderer,onTap,onChange,isCameraLocked=()=>false}){
 const pointers=new Map();let gesture=null;
 const clamp=(v,a,b)=>Math.max(a,Math.min(b,v)),pair=()=>[...pointers.values()].slice(0,2);
 const mid=p=>({x:(p[0].x+p[1].x)/2,y:(p[0].y+p[1].y)/2}),span=p=>Math.max(1,Math.hypot(p[1].x-p[0].x,p[1].y-p[0].y));
 const angle=p=>Math.atan2(p[1].y-p[0].y,p[1].x-p[0].x),delta=(a,b)=>Math.atan2(Math.sin(a-b),Math.cos(a-b));
 const renderer=()=>getRenderer(),ground=p=>renderer()?.groundPointAt?.(p.x,p.y)??null,focus=p=>renderer()?.focusPointAt?.(p.x,p.y)??ground(p);
 const update=()=>{renderer()?.updateCamera?.(camera);onChange?.()};
 const anchor=(a,b)=>{if(!a||!b)return;camera.targetX=(Number.isFinite(camera.targetX)?camera.targetX:0)+a.x-b.x;camera.targetZ=(Number.isFinite(camera.targetZ)?camera.targetZ:0)+a.z-b.z};
 const begin=()=>{if(pointers.size>=2){const p=pair(),m=mid(p);gesture={mode:"pinch-orbit",mid:m,distance:span(p),angle:angle(p),zoom:camera.zoom,orbit:camera.orbit||0,anchor:ground(m),moved:true}}
 else if(pointers.size===1){const p=pair()[0];gesture={mode:"pan",start:{x:p.x,y:p.y},anchor:ground(p),x:camera.x||0,y:camera.y||0,moved:false}}else gesture=null};
 const down=e=>{if(e.pointerType==="mouse"&&e.button!==0)return;e.preventDefault();pointers.set(e.pointerId,{id:e.pointerId,x:e.clientX,y:e.clientY,startX:e.clientX,startY:e.clientY});try{canvas.setPointerCapture(e.pointerId)}catch{}begin()};
 const move=e=>{const p=pointers.get(e.pointerId);if(!p)return;e.preventDefault();p.x=e.clientX;p.y=e.clientY;
 if(pointers.size>=2&&gesture?.mode==="pinch-orbit"&&!isCameraLocked()){const q=pair(),m=mid(q),g=gesture;camera.zoom=clamp(g.zoom*span(q)/g.distance,.42,1.5);camera.orbit=g.orbit+(m.x-g.mid.x)*.009+delta(angle(q),g.angle);renderer()?.updateCamera?.(camera);anchor(g.anchor,ground(m));update()}
 else if(pointers.size===1&&gesture?.mode==="pan"){if(Math.hypot(p.x-gesture.start.x,p.y-gesture.start.y)>5)gesture.moved=true;if(gesture.moved&&!isCameraLocked()){const hit=ground(p);if(gesture.anchor&&hit)anchor(gesture.anchor,hit);else{camera.x=gesture.x+p.x-gesture.start.x;camera.y=gesture.y+p.y-gesture.start.y}update()}}};
 const finish=e=>{const p=pointers.get(e.pointerId);if(!p)return;const tap=pointers.size===1&&gesture?.mode==="pan"&&!gesture.moved&&Math.hypot(e.clientX-p.startX,e.clientY-p.startY)<=5;
 if(tap){const hit=focus({x:e.clientX,y:e.clientY});if(hit&&!isCameraLocked()){camera.targetX=hit.x;camera.targetZ=hit.z;camera.x=0;camera.y=0;update()}const tile=renderer()?.tileAt(e.clientX,e.clientY);onTap?.(tile?.x??-1,tile?.y??-1)}
 pointers.delete(e.pointerId);try{if(canvas.hasPointerCapture(e.pointerId))canvas.releasePointerCapture(e.pointerId)}catch{}begin();if(gesture?.mode==="pan")gesture.moved=true};
 const wheel=e=>{e.preventDefault();const p={x:e.clientX,y:e.clientY},hit=ground(p);camera.zoom=clamp(camera.zoom*Math.exp(-e.deltaY*.0015),.42,1.5);renderer()?.updateCamera?.(camera);anchor(hit,ground(p));update()};
 canvas.style.touchAction="none";canvas.addEventListener("pointerdown",down,{passive:false});canvas.addEventListener("pointermove",move,{passive:false});canvas.addEventListener("pointerup",finish);canvas.addEventListener("pointercancel",finish);canvas.addEventListener("lostpointercapture",finish);canvas.addEventListener("wheel",wheel,{passive:false});
 return{getState:()=>({pointers:pointers.size,gesture:gesture?.mode??"idle",zoom:camera.zoom,orbit:camera.orbit||0}),destroy(){canvas.removeEventListener("pointerdown",down);canvas.removeEventListener("pointermove",move);canvas.removeEventListener("pointerup",finish);canvas.removeEventListener("pointercancel",finish);canvas.removeEventListener("lostpointercapture",finish);canvas.removeEventListener("wheel",wheel);pointers.clear();gesture=null}};
}
