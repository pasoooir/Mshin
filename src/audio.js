// Recorded CC0 RPM layers use equal-power crossfades; vehicle-specific profiles give each class a distinct character.
export function createGameAudio(){
 let context=null,master=null,filter=null,compressor=null,engineGains=[],engineSources=[],evOscillators=[],evGain=null;
 let enabled=true,decodePromise=null,smoothedRpm=.18,throttleEnvelope=0,lastUpdate=0,lastGear=-1,shiftAt=-Infinity;
 const oneShots=new Map();
 const profiles={rally:{pitch:1.06,filterBase:920,filterRange:5050,volume:1.02,roughness:1.12},comet:{pitch:1.16,filterBase:1280,filterRange:5700,volume:.94,roughness:.72},lynx:{pitch:.88,filterBase:690,filterRange:3850,volume:1.08,roughness:.82},raptor:{pitch:.96,filterBase:820,filterRange:4300,volume:1.1,roughness:1.02},thunder:{electric:true,pitch:1.04,filterBase:2100,filterRange:4700,volume:.88}};
 const ensure=()=>{
  if(!enabled)return false;const Audio=window.AudioContext||window.webkitAudioContext;if(!Audio)return false;
  if(!context){context=new Audio();master=context.createGain();master.gain.value=.72;filter=context.createBiquadFilter();filter.type="lowpass";filter.frequency.value=1700;filter.Q.value=.72;compressor=context.createDynamicsCompressor();compressor.threshold.value=-20;compressor.knee.value=18;compressor.ratio.value=3;compressor.attack.value=.012;compressor.release.value=.18;master.connect(filter);filter.connect(compressor);compressor.connect(context.destination);engineGains=Array.from({length:6},()=>{const g=context.createGain();g.gain.value=0;g.connect(master);return g});evGain=context.createGain();evGain.gain.value=0;evGain.connect(master);const low=context.createOscillator(),harmonic=context.createOscillator();low.type="sine";harmonic.type="triangle";low.frequency.value=42;harmonic.frequency.value=86;const lowGain=context.createGain(),harmonicGain=context.createGain();lowGain.gain.value=.15;harmonicGain.gain.value=.035;low.connect(lowGain);harmonic.connect(harmonicGain);lowGain.connect(evGain);harmonicGain.connect(evGain);low.start();harmonic.start();evOscillators=[low,harmonic]}
  if(context.state==="suspended")context.resume().catch(()=>{});return true;
 };
 const decode=async id=>{const data=window.MshinAssets?.audioData?.[id];if(!data||!context)return null;try{return await context.decodeAudioData(data.slice(0))}catch{return null}};
 const loop=(buffer,gain,rate)=>{if(!buffer||!context)return null;const s=context.createBufferSource();s.buffer=buffer;s.loop=true;const edge=Math.min(.075,buffer.duration*.04);s.loopStart=edge;s.loopEnd=Math.max(edge+.12,buffer.duration-edge);s.playbackRate.value=rate;s.connect(gain);s.start();return s};
 const oneShot=async(id,volume,rate)=>{if(!ensure())return;if(!oneShots.has(id))oneShots.set(id,await decode(id));const b=oneShots.get(id);if(!b)return;const s=context.createBufferSource(),g=context.createGain();s.buffer=b;s.playbackRate.value=rate;g.gain.value=volume;s.connect(g);g.connect(master);s.start()};
 const prepare=()=>{if(decodePromise||!context)return decodePromise;decodePromise=Promise.all([...Array.from({length:6},(_,i)=>decode("engine"+i)),decode("brakeSqueal"),decode("gearDown")]).then(buffers=>{const engines=buffers.slice(0,6);engines.forEach((b,i)=>engineSources[i]=loop(b,engineGains[i],.96));oneShots.set("brakeSqueal",buffers[6]);oneShots.set("gearDown",buffers[7]);window.MshinAudioReady=engines.every(Boolean)&&Boolean(buffers[6])&&Boolean(buffers[7]);return window.MshinAudioReady});return decodePromise};
 const gearForSpeed=speed=>{const n=Math.max(0,Math.min(1,speed/390));return n<.13?0:n<.28?1:n<.44?2:n<.61?3:n<.79?4:5};
 return {
  unlock(){if(ensure())prepare()},ready(){if(!ensure())return Promise.resolve(false);return Promise.race([prepare(),new Promise(resolve=>setTimeout(()=>resolve(false),9000))])},
  update(speed,active,throttle=false,brake=false,boost=false,vehicleId="rally"){
   if(!ensure())return;if(!decodePromise)prepare();if(!engineSources.length)return;const profile=profiles[vehicleId]||profiles.rally,now=context.currentTime,dt=lastUpdate?Math.min(.1,Math.max(.001,now-lastUpdate)):.016;lastUpdate=now;
   const velocity=Math.max(0,Math.min(390,speed||0)),gear=gearForSpeed(velocity),gearChanged=lastGear>=0&&gear!==lastGear;if(gearChanged&&!profile.electric){shiftAt=now;if(gear<lastGear)oneShot("gearDown",.17,.94)}lastGear=gear;
   const bounds=[0,.13,.28,.44,.61,.79,1.001],span=bounds[gear+1]-bounds[gear];let rpm=.22+Math.max(0,Math.min(1,(velocity/390-bounds[gear])/span))*.76;
   const throttleTarget=throttle?1:0;throttleEnvelope+=(throttleTarget-throttleEnvelope)*(1-Math.exp(-dt*(throttle?9:4.2)));rpm=Math.max(.16,Math.min(1,rpm+throttleEnvelope*.075*profile.roughness+(boost?.055:0)));
   const shifting=!profile.electric&&now-shiftAt<.16;if(shifting)rpm=Math.max(.16,rpm-.16*(1-(now-shiftAt)/.16));const response=1-Math.exp(-dt*(throttle?12:5));smoothedRpm+=(rpm-smoothedRpm)*response;
   const position=smoothedRpm*5,lower=Math.floor(position),fraction=position-lower,upper=Math.min(5,lower+1),lowWeight=Math.cos(fraction*Math.PI/2),highWeight=Math.sin(fraction*Math.PI/2),load=throttleEnvelope*.23+(boost?.09:0)-(brake?.035:0),level=active?Math.max(.07,Math.min(.58,.16+load))*profile.volume:0;
   engineGains.forEach((gain,i)=>{const weight=i===lower?lowWeight:i===upper?highWeight:0;gain.gain.setTargetAtTime(profile.electric?0:level*weight,now,.055)});
   if(profile.electric){evGain.gain.setTargetAtTime(active?(.12+throttleEnvelope*.18+(boost?.05:0))*profile.volume:0,now,.07);evOscillators[0]?.frequency.setTargetAtTime(38+velocity*.92+throttleEnvelope*22+(boost?28:0),now,.08);evOscillators[1]?.frequency.setTargetAtTime(82+velocity*1.72+throttleEnvelope*38+(boost?46:0),now,.08)}
   else{evGain.gain.setTargetAtTime(0,now,.06);const pitch=profile.pitch*(.94+smoothedRpm*.13+throttleEnvelope*.025);engineSources.forEach((source,i)=>{if(source)source.playbackRate.setTargetAtTime(pitch+(i-2.5)*.002,now,.075)})}
   filter.frequency.setTargetAtTime(profile.filterBase+smoothedRpm*profile.filterRange+throttleEnvelope*650,now,.08);if(brake&&velocity>95&&Math.random()<dt*.22)oneShot("brakeSqueal",.055,.98);
  },
  collision(intensity=1){const n=Math.max(0,Math.min(1.5,intensity));oneShot("brakeSqueal",.12+n*.18,.92+n*.12)},finish(){oneShot("gearDown",.24,.92)},
  toggle(){enabled=!enabled;if(master&&context)master.gain.setTargetAtTime(enabled?.72:0,context.currentTime,.05);if(enabled)this.unlock();return enabled},get enabled(){return enabled}
 };
}
