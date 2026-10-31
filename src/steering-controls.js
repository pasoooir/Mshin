const clamp=(value,min,max)=>Math.max(min,Math.min(max,value));
const smoothstep=(edge0,edge1,value)=>{const t=clamp((value-edge0)/(edge1-edge0),0,1);return t*t*(3-2*t)};

/** Fuzzy steering curve: blends gentle, medium and aggressive input zones. */
export function fuzzySteering(value,{deadZone=.055,sensitivity=1,speed=0,maxSpeed=360}={}){
 const raw=clamp(Number.isFinite(value)?value:0,-1,1),magnitude=Math.abs(raw);
 if(magnitude<=clamp(deadZone,0,.35))return 0;
 const normalized=clamp((magnitude-deadZone)/(1-deadZone),0,1);
 const gentle=1-smoothstep(.18,.52,normalized);
 const aggressive=smoothstep(.58,.96,normalized);
 const medium=1-gentle-aggressive;
 const fuzzyGain=gentle*1.12+medium*1.02+aggressive*.91;
 const speedRatio=clamp((Number.isFinite(speed)?Math.abs(speed):0)/Math.max(1,maxSpeed),0,1.25);
 const speedGain=1.12-speedRatio*.27;
 const response=clamp(normalized*fuzzyGain*speedGain*(Number.isFinite(sensitivity)?sensitivity:1),0,1);
 return Math.sign(raw)*response;
}

/** Convert device tilt into steering relative to a calibrated neutral position. */
export function mapTiltToSteering(angle,center=0,{range=22,deadZone=2.5,sensitivity=1}={}){
 if(!Number.isFinite(angle)||!Number.isFinite(center))return 0;
 const delta=angle-center,absolute=Math.abs(delta),zone=clamp(deadZone,0,20),limit=clamp(range,8,55);
 if(absolute<=zone)return 0;
 const normalized=clamp((absolute-zone)/Math.max(1,limit-zone),0,1);
 const curved=normalized*normalized*(3-2*normalized);
 return Math.sign(delta)*clamp(curved*(Number.isFinite(sensitivity)?sensitivity:1),0,1);
}

/** Mix steering sources without bypassing the vehicle's tire/physics simulation. */
export function combineSteering({mode="joystick",joystick=0,gyro=0}={}){
 if(mode==="gyro")return clamp(gyro,-1,1);
 if(mode==="hybrid")return clamp(joystick+gyro*.72,-1,1);
 return clamp(joystick,-1,1);
}
