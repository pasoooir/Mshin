// Recorded CC0 idle/load/road layers are mixed by vehicle profile and RPM; music and SFX remain isolated.
export function createGameAudio() {
  let context=null,master=null,sfxBus=null,musicBus=null,engineFilter=null,compressor=null;
  let engineGains=[],engineSources=[],engineBuffers={},evOscillators=[],evGain=null;
  let previewSource=null,previewGain=null,musicSource=null,musicSourceGain=null,musicMode=null;
  let sfxEnabled=true,musicEnabled=true,sfxVolume=.82,musicVolume=.24,decodePromise=null,coreAudioReady=false;
  let smoothedRpm=.18,throttleEnvelope=0,lastUpdate=0,lastGear=-1,shiftAt=-Infinity;
  const decoded=new Map(),oneShots=new Map();
  const profiles={
    rally:{pitch:1.02,filterBase:760,filterRange:3650,volume:1.02,roughness:1.08,resonance:.78,idle:1.0,load:1.08,road:.52},
    comet:{pitch:1.13,filterBase:1120,filterRange:4700,volume:.94,roughness:.72,resonance:.56,idle:.72,load:1.22,road:.62},
    lynx:{pitch:.91,filterBase:620,filterRange:3250,volume:1.06,roughness:.86,resonance:1.02,idle:1.2,load:.82,road:.94},
    raptor:{pitch:.98,filterBase:890,filterRange:4300,volume:1.1,roughness:1.24,resonance:1.18,idle:.86,load:1.26,road:.58},
    thunder:{electric:true,pitch:1.04,filterBase:2100,filterRange:4700,volume:.88,roughness:0,resonance:.7,idle:0,load:0,road:.42}
  };
  const ensure=()=>{
    const Audio=window.AudioContext||window.webkitAudioContext;if(!Audio)return false;
    if(!context){
      context=new Audio();master=context.createGain();master.gain.value=.9;
      compressor=context.createDynamicsCompressor();compressor.threshold.value=-20;compressor.knee.value=18;compressor.ratio.value=3;compressor.attack.value=.012;compressor.release.value=.18;
      master.connect(compressor);compressor.connect(context.destination);
      sfxBus=context.createGain();sfxBus.gain.value=sfxEnabled?sfxVolume:0;sfxBus.connect(master);
      musicBus=context.createGain();musicBus.gain.value=musicEnabled?musicVolume:0;musicBus.connect(master);
      engineFilter=context.createBiquadFilter();engineFilter.type="lowpass";engineFilter.frequency.value=1700;engineFilter.Q.value=.72;engineFilter.connect(sfxBus);
      engineGains=Array.from({length:3},()=>{const gain=context.createGain();gain.gain.value=0;gain.connect(engineFilter);return gain});
      evGain=context.createGain();evGain.gain.value=0;evGain.connect(sfxBus);
      const low=context.createOscillator(),harmonic=context.createOscillator();low.type="sine";harmonic.type="triangle";low.frequency.value=42;harmonic.frequency.value=86;
      const lowGain=context.createGain(),harmonicGain=context.createGain();lowGain.gain.value=.15;harmonicGain.gain.value=.035;
      low.connect(lowGain);harmonic.connect(harmonicGain);lowGain.connect(evGain);harmonicGain.connect(evGain);low.start();harmonic.start();evOscillators=[low,harmonic];
    }
    if(context.state==="suspended")context.resume().catch(()=>{});
    return true;
  };
  const decode=async id=>{
    if(decoded.has(id))return decoded.get(id);
    const data=window.MshinAssets?.audioData?.[id];if(!data||!context)return null;
    try{const buffer=await context.decodeAudioData(data.slice(0));decoded.set(id,buffer);return buffer}
    catch{decoded.set(id,null);return null}
  };
  const loop=(buffer,gain)=>{
    if(!buffer||!context)return null;
    const source=context.createBufferSource();source.buffer=buffer;source.loop=true;
    const edge=Math.min(.09,buffer.duration*.035);source.loopStart=edge;source.loopEnd=Math.max(edge+.12,buffer.duration-edge);
    source.connect(gain);source.start();return source;
  };
  const oneShot=async(id,volume,rate=1)=>{
    if(!sfxEnabled||!ensure())return;
    if(!oneShots.has(id))oneShots.set(id,await decode(id));
    const buffer=oneShots.get(id);if(!buffer)return;
    const source=context.createBufferSource(),gain=context.createGain();source.buffer=buffer;source.playbackRate.value=rate;gain.gain.value=volume;
    source.connect(gain);gain.connect(sfxBus);source.onended=()=>{source.disconnect();gain.disconnect()};source.start();
  };
  const prepare=()=>{
    if(decodePromise)return decodePromise;if(!ensure())return Promise.resolve(false);
    const ids=["engineIdle","engineLoad","roadRoll","engineStart","engineStop","brakeSqueal","gearDown","collisionImpact"];
    decodePromise=Promise.all(ids.map(decode)).then(buffers=>{
      engineBuffers={idle:buffers[0],load:buffers[1],road:buffers[2]};
      engineSources=[loop(engineBuffers.idle,engineGains[0]),loop(engineBuffers.load,engineGains[1]),loop(engineBuffers.road,engineGains[2])];
      ["engineStart","engineStop","brakeSqueal","gearDown","collisionImpact"].forEach((id,index)=>oneShots.set(id,buffers[index+3]));
      coreAudioReady=Object.values(engineBuffers).every(Boolean)&&buffers.slice(3).every(Boolean);
      window.MshinAudioReady=coreAudioReady;return coreAudioReady;
    });
    return decodePromise;
  };
  const gearForSpeed=speed=>{const n=Math.max(0,Math.min(1,speed/390));return n<.13?0:n<.28?1:n<.44?2:n<.61?3:n<.79?4:5};
  const playMusic=async mode=>{
    if(!ensure()||!musicEnabled)return false;
    const selected=mode==="race"?"raceMusic":"menuMusic";await prepare();
    if(musicMode===mode&&musicSource)return true;
    const buffer=await decode(selected);window.MshinAudioReady=coreAudioReady&&Boolean(buffer);if(!buffer)return false;
    const now=context.currentTime,source=context.createBufferSource(),gain=context.createGain();source.buffer=buffer;source.loop=true;source.connect(gain);gain.connect(musicBus);
    gain.gain.setValueAtTime(.0001,now);source.start(now);gain.gain.exponentialRampToValueAtTime(1,now+.65);
    if(musicSource&&musicSourceGain){musicSourceGain.gain.cancelScheduledValues(now);musicSourceGain.gain.setValueAtTime(Math.max(.0001,musicSourceGain.gain.value),now);musicSourceGain.gain.exponentialRampToValueAtTime(.0001,now+.65);try{musicSource.stop(now+.68)}catch{}}
    musicSource=source;musicSourceGain=gain;musicMode=mode;
    source.onended=()=>{if(musicSource===source){musicSource=null;musicSourceGain=null;musicMode=null}else{decoded.delete(selected)}source.disconnect();gain.disconnect()};
    return true;
  };
  const setSfxEnabled=value=>{sfxEnabled=Boolean(value);if(context)sfxBus.gain.setTargetAtTime(sfxEnabled?sfxVolume:0,context.currentTime,.04);return sfxEnabled};
  const setMusicEnabled=value=>{musicEnabled=Boolean(value);if(context)musicBus.gain.setTargetAtTime(musicEnabled?musicVolume:0,context.currentTime,.05);return musicEnabled};
  const setSfxVolume=value=>{sfxVolume=Math.max(0,Math.min(1,Number(value)||0));if(context)sfxBus.gain.setTargetAtTime(sfxEnabled?sfxVolume:0,context.currentTime,.04);return sfxVolume};
  const setMusicVolume=value=>{musicVolume=Math.max(0,Math.min(1,Number(value)||0));if(context)musicBus.gain.setTargetAtTime(musicEnabled?musicVolume:0,context.currentTime,.05);return musicVolume};
  const impactThump=intensity=>{
    if(!ensure()||!sfxEnabled)return;
    const now=context.currentTime,osc=context.createOscillator(),gain=context.createGain();osc.type="triangle";osc.frequency.setValueAtTime(118,now);osc.frequency.exponentialRampToValueAtTime(38,now+.19);
    gain.gain.setValueAtTime(.0001,now);gain.gain.exponentialRampToValueAtTime(.16*Math.max(.25,Math.min(1.5,intensity)),now+.012);gain.gain.exponentialRampToValueAtTime(.0001,now+.23);
    osc.connect(gain);gain.connect(sfxBus);osc.onended=()=>{osc.disconnect();gain.disconnect()};osc.start(now);osc.stop(now+.24);
  };
  return {
    unlock(){try{if(ensure())prepare()}catch(error){window.MshinAudioError=error.message}},
    ready(){if(!ensure())return Promise.resolve(false);const task=prepare().then(async core=>{const musicReady=!musicEnabled||Boolean(await decode("raceMusic"));window.MshinAudioReady=core&&musicReady;return core&&musicReady});return Promise.race([task,new Promise(resolve=>setTimeout(()=>resolve(false),15000))])},
    playMusic,setMusicMode:playMusic,setMusicEnabled,setMusicVolume,setSfxEnabled,setSfxVolume,
    startEngine(){oneShot("engineStart",.25,.98)},
    async preview(vehicleId="rally"){
      if(!sfxEnabled||!ensure())return false;await prepare();const profile=profiles[vehicleId]||profiles.rally;
      if(previewSource){try{previewSource.stop()}catch{}previewSource=null}if(previewGain)previewGain.disconnect();
      if(profile.electric){const now=context.currentTime,osc=context.createOscillator(),gain=context.createGain();osc.type="triangle";osc.frequency.setValueAtTime(105,now);osc.frequency.exponentialRampToValueAtTime(520,now+1.15);gain.gain.setValueAtTime(.0001,now);gain.gain.exponentialRampToValueAtTime(.16*profile.volume,now+.12);gain.gain.exponentialRampToValueAtTime(.0001,now+1.45);osc.connect(gain);gain.connect(sfxBus);osc.start(now);osc.stop(now+1.5);previewSource=osc;previewGain=gain;return true}
      const buffer=engineBuffers.load||engineBuffers.idle;if(!buffer)return false;
      const source=context.createBufferSource(),gain=context.createGain(),now=context.currentTime;source.buffer=buffer;source.playbackRate.value=profile.pitch*.96;
      gain.gain.setValueAtTime(.0001,now);gain.gain.exponentialRampToValueAtTime(.24*profile.volume,now+.12);gain.gain.setValueAtTime(.24*profile.volume,now+1.05);gain.gain.exponentialRampToValueAtTime(.0001,now+1.5);
      source.connect(gain);gain.connect(sfxBus);source.start(now);source.stop(now+1.55);previewSource=source;previewGain=gain;return true;
    },
    update(speed,active,throttle=false,brake=false,boost=false,vehicleId="rally"){
      if(!ensure())return;if(!decodePromise)prepare();if(!engineSources.length)return;
      const profile=profiles[vehicleId]||profiles.rally,now=context.currentTime,dt=lastUpdate?Math.min(.1,Math.max(.001,now-lastUpdate)):.016;lastUpdate=now;
      const velocity=Math.max(0,Math.min(390,speed||0)),gear=gearForSpeed(velocity),gearChanged=lastGear>=0&&gear!==lastGear;
      if(gearChanged&&!profile.electric){shiftAt=now;oneShot("gearDown",.14,gear < lastGear ? .9 : 1.08)}lastGear=gear;
      const bounds=[0,.13,.28,.44,.61,.79,1.001],span=bounds[gear+1]-bounds[gear];
      let rpm=.22+Math.max(0,Math.min(1,(velocity/390-bounds[gear])/span))*.76;
      throttleEnvelope+=( (throttle?1:0)-throttleEnvelope )*(1-Math.exp(-dt*(throttle?9:4.2)));
      rpm=Math.max(.16,Math.min(1,rpm+throttleEnvelope*.075*profile.roughness+(boost?.055:0)));
      if(!profile.electric&&now-shiftAt<.16)rpm=Math.max(.16,rpm-.16*(1-(now-shiftAt)/.16));
      smoothedRpm+=(rpm-smoothedRpm)*(1-Math.exp(-dt*(throttle?12:5)));
      const level=active?Math.max(.07,Math.min(.5,.14+throttleEnvelope*.28+smoothedRpm*.12+(boost?.05:0)))*profile.volume:0;
      const idleMix=(.68+(1-smoothedRpm)*.48+(brake?.1:0))*profile.idle;
      const loadMix=(.12+throttleEnvelope*.95+(boost?.22:0))*(.45+smoothedRpm*.55)*profile.load;
      const roadMix=(velocity/390)*(.28+(brake?.25:0))*profile.road;
      engineGains[0].gain.setTargetAtTime(profile.electric?0:level*idleMix,now,.07);
      engineGains[1].gain.setTargetAtTime(profile.electric?0:level*loadMix,now,.055);
      engineGains[2].gain.setTargetAtTime(level*roadMix,now,.08);
      if(profile.electric){evGain.gain.setTargetAtTime(active?(.12+throttleEnvelope*.18+(boost?.05:0))*profile.volume:0,now,.07);evOscillators[0]?.frequency.setTargetAtTime(38+velocity*.92+throttleEnvelope*22+(boost?28:0),now,.08);evOscillators[1]?.frequency.setTargetAtTime(82+velocity*1.72+throttleEnvelope*38+(boost?46:0),now,.08)}
      else{evGain.gain.setTargetAtTime(0,now,.06);engineSources[0]?.playbackRate.setTargetAtTime(profile.pitch*(.92+smoothedRpm*.16),now,.08);engineSources[1]?.playbackRate.setTargetAtTime(profile.pitch*(.78+smoothedRpm*.32+throttleEnvelope*.05),now,.06);engineSources[2]?.playbackRate.setTargetAtTime(.86+velocity/390*.38,now,.08)}
      engineFilter.frequency.setTargetAtTime(profile.filterBase+smoothedRpm*profile.filterRange+throttleEnvelope*650,now,.08);
      engineFilter.Q.setTargetAtTime(profile.resonance,now,.1);
      if(brake&&velocity>95&&Math.random()<dt*.22)oneShot("brakeSqueal",.055,.98);
    },
    collision(intensity=1){const n=Math.max(0,Math.min(1.5,intensity));oneShot("collisionImpact",.22+n*.2,.9+n*.08);oneShot("brakeSqueal",.08+n*.08,.92);impactThump(n)},
    finish(){oneShot("engineStop",.22,.96);oneShot("gearDown",.18,.92)},
    toggle(){return setSfxEnabled(!sfxEnabled)},
    get enabled(){return sfxEnabled},get musicEnabled(){return musicEnabled},get sfxVolume(){return sfxVolume},get musicVolume(){return musicVolume}
  };
}
