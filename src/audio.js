// Lightweight synthesized arcade audio. AudioContext is created only after a user gesture.
export function createGameAudio() {
  let context = null, master = null, engine = null, engineGain = null, enabled = true;
  const ensure = () => {
    if (!enabled) return false;
    const Audio = window.AudioContext || window.webkitAudioContext;
    if (!Audio) return false;
    if (!context) {
      context = new Audio();
      master = context.createGain();
      master.gain.value = 0.22;
      master.connect(context.destination);
      engine = context.createOscillator();
      engine.type = "sawtooth";
      engine.frequency.value = 55;
      engineGain = context.createGain();
      engineGain.gain.value = 0;
      engine.connect(engineGain);
      engineGain.connect(master);
      engine.start();
    }
    if (context.state === "suspended") context.resume().catch(() => {});
    return true;
  };
  const tone = (frequency, duration, type = "sine", volume = 0.22) => {
    if (!ensure()) return;
    const osc = context.createOscillator(), gain = context.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(frequency, context.currentTime);
    gain.gain.setValueAtTime(volume, context.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, context.currentTime + duration);
    osc.connect(gain); gain.connect(master);
    osc.start(); osc.stop(context.currentTime + duration);
  };
  return {
    unlock() { ensure(); },
    update(speed, active) {
      if (!ensure()) return;
      const now = context.currentTime;
      engine.frequency.setTargetAtTime(48 + Math.max(0, speed) * 0.48, now, 0.08);
      engineGain.gain.setTargetAtTime(active ? 0.035 + Math.min(speed / 330, 1) * 0.045 : 0, now, 0.12);
    },
    collision(intensity = 1) { const level = Math.max(0, Math.min(1.5, intensity)); const severe = level >= 0.85; tone(severe ? 72 : level >= 0.45 ? 96 : 138, severe ? 0.28 : 0.16, "square", 0.12 + level * 0.09); if (severe) tone(48, 0.34, "sawtooth", 0.13); else tone(165 - level * 45, 0.13, "triangle", 0.08 + level * 0.05); },
    finish() { tone(523, 0.12); setTimeout(() => tone(659, 0.12), 110); setTimeout(() => tone(784, 0.22), 220); },
    toggle() {
      enabled = !enabled;
      if (master && context) master.gain.setTargetAtTime(enabled ? 0.22 : 0, context.currentTime, 0.04);
      return enabled;
    },
    get enabled() { return enabled; }
  };
}
