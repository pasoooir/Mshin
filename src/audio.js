// Real race-engine recordings are downloaded and decoded during the boot preload.
// Sources: SFXMint vehicle/race-car CC0 1.0 library (direct immutable hotlinks).
export function createGameAudio() {
  let context = null, master = null, idleGain = null, revGain = null;
  let idleSource = null, revSource = null, enabled = true, decodePromise = null;
  const oneShots = new Map();
  const ensure = () => {
    if (!enabled) return false;
    const Audio = window.AudioContext || window.webkitAudioContext;
    if (!Audio) return false;
    if (!context) {
      context = new Audio();
      master = context.createGain(); master.gain.value = 0.72; master.connect(context.destination);
      idleGain = context.createGain(); idleGain.gain.value = 0; idleGain.connect(master);
      revGain = context.createGain(); revGain.gain.value = 0; revGain.connect(master);
    }
    if (context.state === "suspended") context.resume().catch(() => {});
    return true;
  };
  const decode = async (id) => {
    const data = window.MshinAssets?.audioData?.[id];
    if (!data || !context) return null;
    try { return await context.decodeAudioData(data.slice(0)); } catch { return null; }
  };
  const loopBuffer = (buffer, gainNode, playbackRate = 1) => {
    if (!buffer || !context) return null;
    const source = context.createBufferSource(); source.buffer = buffer; source.loop = true;
    source.loopStart = Math.min(.12, buffer.duration * .08);
    source.loopEnd = Math.max(source.loopStart + .2, buffer.duration - .16);
    source.playbackRate.value = playbackRate; source.connect(gainNode); source.start();
    return source;
  };
  const playOneShot = async (id, volume = .4, rate = 1) => {
    if (!ensure()) return;
    if (!oneShots.has(id)) oneShots.set(id, await decode(id));
    const buffer = oneShots.get(id); if (!buffer) return;
    const source = context.createBufferSource(), gain = context.createGain();
    source.buffer = buffer; source.playbackRate.value = rate; gain.gain.value = volume;
    source.connect(gain); gain.connect(master); source.start();
  };
  const prepare = async () => {
    if (decodePromise || !context) return decodePromise;
    decodePromise = Promise.all([decode("engineIdle"), decode("engineRev"), decode("brakeSqueal"), decode("gearDown")]).then(([idle, rev, brake, gear]) => {
      oneShots.set("brakeSqueal", brake); oneShots.set("gearDown", gear);\n      window.MshinAudioReady = Boolean(idle && rev && brake && gear);
      idleSource = loopBuffer(idle, idleGain, .88);
      revSource = loopBuffer(rev, revGain, .9);
      idleGain.gain.setTargetAtTime(.24, context.currentTime, .3);
      revGain.gain.setTargetAtTime(.015, context.currentTime, .3);
    });
    return decodePromise;
  };
  return {
    unlock() { if (ensure()) prepare(); },
    ready() { return ensure() ? prepare() : Promise.resolve(); },
    update(speed, active, throttle = false) {
      if (!ensure()) return;
      prepare();
      if (!idleSource || !revSource) return;
      const now = context.currentTime, normalized = Math.max(0, Math.min(1.35, speed / 330));
      idleSource.playbackRate.setTargetAtTime(.82 + normalized * .62, now, .12);
      revSource.playbackRate.setTargetAtTime(.78 + normalized * .78, now, .1);
      idleGain.gain.setTargetAtTime(active ? .22 - normalized * .07 : 0, now, .16);
      revGain.gain.setTargetAtTime(active ? (.015 + normalized * .19 + (throttle ? .10 : 0)) : 0, now, .13);
    },
    collision(intensity = 1) {
      const level = Math.max(0, Math.min(1.5, intensity));
      playOneShot("brakeSqueal", .12 + level * .18, .92 + level * .12);
    },
    finish() { playOneShot("gearDown", .24, .92); },
    toggle() {
      enabled = !enabled;
      if (master && context) master.gain.setTargetAtTime(enabled ? .72 : 0, context.currentTime, .05);
      if (enabled) this.unlock();
      return enabled;
    },
    get enabled() { return enabled; }
  };
}
