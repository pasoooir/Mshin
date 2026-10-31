// Vehicle-specific CC0 RPM layers with independent SFX/music buses and seamless soundtrack crossfades.
export function createGameAudio() {
  let context = null, master = null, sfxBus = null, musicBus = null, engineFilter = null, compressor = null;
  let engineGains = [], engineSources = [], engineBuffers = [], evOscillators = [], evGain = null;
  let previewSource = null, previewGain = null, musicSource = null, musicSourceGain = null, musicMode = null;
  let sfxEnabled = true, musicEnabled = true, sfxVolume = .82, musicVolume = .24, decodePromise = null;
  let smoothedRpm = .18, throttleEnvelope = 0, lastUpdate = 0, lastGear = -1, shiftAt = -Infinity;
  const decoded = new Map(), oneShots = new Map();
  const profiles = {
    rally:{pitch:1.06,filterBase:920,filterRange:5050,volume:1.02,roughness:1.12},
    comet:{pitch:1.16,filterBase:1280,filterRange:5700,volume:.94,roughness:.72},
    lynx:{pitch:.88,filterBase:690,filterRange:3850,volume:1.08,roughness:.82},
    raptor:{pitch:.96,filterBase:820,filterRange:4300,volume:1.1,roughness:1.02},
    thunder:{electric:true,pitch:1.04,filterBase:2100,filterRange:4700,volume:.88,roughness:0}
  };
  const ensure = () => {
    const Audio = window.AudioContext || window.webkitAudioContext;
    if (!Audio) return false;
    if (!context) {
      context = new Audio();
      master = context.createGain(); master.gain.value = .9;
      compressor = context.createDynamicsCompressor();
      compressor.threshold.value = -20; compressor.knee.value = 18; compressor.ratio.value = 3;
      compressor.attack.value = .012; compressor.release.value = .18;
      master.connect(compressor); compressor.connect(context.destination);
      sfxBus = context.createGain(); sfxBus.gain.value = sfxEnabled ? sfxVolume : 0; sfxBus.connect(master);
      musicBus = context.createGain(); musicBus.gain.value = musicEnabled ? musicVolume : 0; musicBus.connect(master);
      engineFilter = context.createBiquadFilter(); engineFilter.type = "lowpass"; engineFilter.frequency.value = 1700; engineFilter.Q.value = .72; engineFilter.connect(sfxBus);
      engineGains = Array.from({length:6}, () => { const gain=context.createGain(); gain.gain.value=0; gain.connect(engineFilter); return gain; });
      evGain = context.createGain(); evGain.gain.value=0; evGain.connect(sfxBus);
      const low=context.createOscillator(), harmonic=context.createOscillator();
      low.type="sine"; harmonic.type="triangle"; low.frequency.value=42; harmonic.frequency.value=86;
      const lowGain=context.createGain(), harmonicGain=context.createGain();
      lowGain.gain.value=.15; harmonicGain.gain.value=.035;
      low.connect(lowGain); harmonic.connect(harmonicGain); lowGain.connect(evGain); harmonicGain.connect(evGain);
      low.start(); harmonic.start(); evOscillators=[low,harmonic];
    }
    if (context.state === "suspended") context.resume().catch(() => {});
    return true;
  };
  const decode = async id => {
    if (decoded.has(id)) return decoded.get(id);
    const data = window.MshinAssets?.audioData?.[id];
    if (!data || !context) return null;
    try { const buffer = await context.decodeAudioData(data.slice(0)); decoded.set(id, buffer); return buffer; }
    catch { decoded.set(id, null); return null; }
  };
  const loop = (buffer, gain, rate) => {
    if (!buffer || !context) return null;
    const source=context.createBufferSource(); source.buffer=buffer; source.loop=true;
    const edge=Math.min(.075,buffer.duration*.04); source.loopStart=edge; source.loopEnd=Math.max(edge+.12,buffer.duration-edge);
    source.playbackRate.value=rate; source.connect(gain); source.start(); return source;
  };
  const oneShot = async (id, volume, rate) => {
    if (!sfxEnabled || !ensure()) return;
    if (!oneShots.has(id)) oneShots.set(id, await decode(id));
    const buffer=oneShots.get(id); if (!buffer) return;
    const source=context.createBufferSource(), gain=context.createGain();
    source.buffer=buffer; source.playbackRate.value=rate; gain.gain.value=volume;
    source.connect(gain); gain.connect(sfxBus); source.onended=()=>{source.disconnect();gain.disconnect()}; source.start();
  };
  const prepare = () => {
    if (decodePromise) return decodePromise;
    if (!ensure()) return Promise.resolve(false);
    decodePromise=Promise.all([
      ...Array.from({length:6},(_,i)=>decode("engine"+i)),
      decode("brakeSqueal"), decode("gearDown"), decode("menuMusic"), decode("raceMusic")
    ]).then(buffers => {
      engineBuffers=buffers.slice(0,6);
      engineSources=engineBuffers.map((buffer,i)=>loop(buffer,engineGains[i],.96));
      oneShots.set("brakeSqueal",buffers[6]); oneShots.set("gearDown",buffers[7]);
      const ready=engineBuffers.every(Boolean)&&Boolean(buffers[6])&&Boolean(buffers[7])&&Boolean(buffers[8])&&Boolean(buffers[9]);
      window.MshinAudioReady=ready;
      return ready;
    });
    return decodePromise;
  };
  const gearForSpeed = speed => { const n=Math.max(0,Math.min(1,speed/390)); return n<.13?0:n<.28?1:n<.44?2:n<.61?3:n<.79?4:5; };
  const playMusic = async mode => {
    if (!ensure() || !musicEnabled) return false;
    const selected=mode==="race"?"raceMusic":"menuMusic";
    if (!(await prepare())) return false;
    if (musicMode===mode && musicSource) return true;
    const buffer=decoded.get(selected); if (!buffer) return false;
    const now=context.currentTime, source=context.createBufferSource(), gain=context.createGain();
    source.buffer=buffer; source.loop=true; source.connect(gain); gain.connect(musicBus);
    gain.gain.setValueAtTime(.0001,now); source.start(now); gain.gain.exponentialRampToValueAtTime(1,now+.65);
    if (musicSource && musicSourceGain) {
      musicSourceGain.gain.cancelScheduledValues(now);
      musicSourceGain.gain.setValueAtTime(Math.max(.0001,musicSourceGain.gain.value),now);
      musicSourceGain.gain.exponentialRampToValueAtTime(.0001,now+.65);
      try { musicSource.stop(now+.68); } catch {}
    }
    musicSource=source; musicSourceGain=gain; musicMode=mode;
    source.onended=()=>{if(musicSource===source){musicSource=null;musicSourceGain=null;musicMode=null}source.disconnect();gain.disconnect()};
    return true;
  };
  const setSfxEnabled = value => {
    sfxEnabled=Boolean(value);
    if (context) sfxBus.gain.setTargetAtTime(sfxEnabled?sfxVolume:0,context.currentTime,.04);
    return sfxEnabled;
  };
  const setMusicEnabled = value => {
    musicEnabled=Boolean(value);
    if (context) musicBus.gain.setTargetAtTime(musicEnabled?musicVolume:0,context.currentTime,.05);
    return musicEnabled;
  };
  const setSfxVolume = value => {
    sfxVolume=Math.max(0,Math.min(1,Number(value)||0));
    if (context) sfxBus.gain.setTargetAtTime(sfxEnabled?sfxVolume:0,context.currentTime,.04);
    return sfxVolume;
  };
  const setMusicVolume = value => {
    musicVolume=Math.max(0,Math.min(1,Number(value)||0));
    if (context) musicBus.gain.setTargetAtTime(musicEnabled?musicVolume:0,context.currentTime,.05);
    return musicVolume;
  };
  return {
    unlock(){if(ensure())prepare()},
    ready(){if(!ensure())return Promise.resolve(false);return Promise.race([prepare(),new Promise(resolve=>setTimeout(()=>resolve(false),15000))])},
    playMusic,
    setMusicMode:playMusic,
    setMusicEnabled,
    setMusicVolume,
    setSfxEnabled,
    setSfxVolume,
    async preview(vehicleId="rally"){
      if(!sfxEnabled||!ensure())return false;
      const ok=await prepare();if(!ok)return false;
      const profile=profiles[vehicleId]||profiles.rally;
      if(previewSource){try{previewSource.stop()}catch{}previewSource=null}
      if(previewGain)previewGain.disconnect();
      if(profile.electric){
        const now=context.currentTime,osc=context.createOscillator(),gain=context.createGain();
        osc.type="triangle";osc.frequency.setValueAtTime(105,now);osc.frequency.exponentialRampToValueAtTime(520,now+1.15);
        gain.gain.setValueAtTime(.0001,now);gain.gain.exponentialRampToValueAtTime(.16*profile.volume,now+.12);gain.gain.exponentialRampToValueAtTime(.0001,now+1.45);
        osc.connect(gain);gain.connect(sfxBus);osc.start(now);osc.stop(now+1.5);previewSource=osc;previewGain=gain;return true;
      }
      const buffer=engineBuffers[2]||engineBuffers[1]||engineBuffers[0];if(!buffer)return false;
      const source=context.createBufferSource(),gain=context.createGain(),now=context.currentTime;
      source.buffer=buffer;source.playbackRate.value=profile.pitch*.98;
      gain.gain.setValueAtTime(.0001,now);gain.gain.exponentialRampToValueAtTime(.25*profile.volume,now+.12);
      gain.gain.setValueAtTime(.25*profile.volume,now+1.05);gain.gain.exponentialRampToValueAtTime(.0001,now+1.5);
      source.connect(gain);gain.connect(sfxBus);source.start(now);source.stop(now+1.55);previewSource=source;previewGain=gain;return true;
    },
    update(speed,active,throttle=false,brake=false,boost=false,vehicleId="rally"){
      if(!ensure())return;if(!decodePromise)prepare();if(!engineSources.length)return;
      const profile=profiles[vehicleId]||profiles.rally,now=context.currentTime,dt=lastUpdate?Math.min(.1,Math.max(.001,now-lastUpdate)):.016;lastUpdate=now;
      const velocity=Math.max(0,Math.min(390,speed||0)),gear=gearForSpeed(velocity),gearChanged=lastGear>=0&&gear!==lastGear;
      if(gearChanged&&!profile.electric){shiftAt=now;if(gear<lastGear)oneShot("gearDown",.17,.94)}lastGear=gear;
      const bounds=[0,.13,.28,.44,.61,.79,1.001],span=bounds[gear+1]-bounds[gear];
      let rpm=.22+Math.max(0,Math.min(1,(velocity/390-bounds[gear])/span))*.76;
      const throttleTarget=throttle?1:0;throttleEnvelope+=(throttleTarget-throttleEnvelope)*(1-Math.exp(-dt*(throttle?9:4.2)));
      rpm=Math.max(.16,Math.min(1,rpm+throttleEnvelope*.075*profile.roughness+(boost?.055:0)));
      const shifting=!profile.electric&&now-shiftAt<.16;if(shifting)rpm=Math.max(.16,rpm-.16*(1-(now-shiftAt)/.16));
      const response=1-Math.exp(-dt*(throttle?12:5));smoothedRpm+=(rpm-smoothedRpm)*response;
      const position=smoothedRpm*5,lower=Math.floor(position),fraction=position-lower,upper=Math.min(5,lower+1);
      const lowWeight=Math.cos(fraction*Math.PI/2),highWeight=Math.sin(fraction*Math.PI/2);
      const load=throttleEnvelope*.23+(boost?.09:0)-(brake?.035:0),level=active?Math.max(.07,Math.min(.58,.16+load))*profile.volume:0;
      engineGains.forEach((gain,i)=>{const weight=i===lower?lowWeight:i===upper?highWeight:0;gain.gain.setTargetAtTime(profile.electric?0:level*weight,now,.055)});
      if(profile.electric){evGain.gain.setTargetAtTime(active?(.12+throttleEnvelope*.18+(boost?.05:0))*profile.volume:0,now,.07);evOscillators[0]?.frequency.setTargetAtTime(38+velocity*.92+throttleEnvelope*22+(boost?28:0),now,.08);evOscillators[1]?.frequency.setTargetAtTime(82+velocity*1.72+throttleEnvelope*38+(boost?46:0),now,.08)}
      else{evGain.gain.setTargetAtTime(0,now,.06);const pitch=profile.pitch*(.94+smoothedRpm*.13+throttleEnvelope*.025);engineSources.forEach((source,i)=>{if(source)source.playbackRate.setTargetAtTime(pitch+(i-2.5)*.002,now,.075)})}
      engineFilter.frequency.setTargetAtTime(profile.filterBase+smoothedRpm*profile.filterRange+throttleEnvelope*650,now,.08);
      if(brake&&velocity>95&&Math.random()<dt*.22)oneShot("brakeSqueal",.055,.98);
    },
    collision(intensity=1){const n=Math.max(0,Math.min(1.5,intensity));oneShot("brakeSqueal",.12+n*.18,.92+n*.12)},
    finish(){oneShot("gearDown",.24,.92)},
    toggle(){return setSfxEnabled(!sfxEnabled)},
    get enabled(){return sfxEnabled},
    get musicEnabled(){return musicEnabled},
    get sfxVolume(){return sfxVolume},
    get musicVolume(){return musicVolume}
  };
}
