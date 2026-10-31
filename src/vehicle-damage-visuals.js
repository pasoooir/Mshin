const clamp=(value,min,max)=>Math.max(min,Math.min(max,value));

/**
 * Convert cumulative, localized panel damage into stable visual cues.
 * Damage points are the same 0..100 scale used by collision-physics.js.
 */
export function getDamageVisuals(damage={}) {
  const panels=["front","rear","left","right"].map(side=>{
    const points=clamp(Number.isFinite(damage[side])?damage[side]:0,0,100);
    return {side,points,strength:clamp(points/34,0,1),dentCount:points>=42?3:points>=15?2:points>=5?1:0};
  });
  const total=clamp(Number.isFinite(damage.total)?damage.total:0,0,100);
  const front=panels[0].strength;
  return {
    panels,
    glassCracks:clamp((Number.isFinite(damage.front)?damage.front:0)/48,0,1),
    smoke:clamp((total-24)/58,0,1),
    heavyDeformation:total>=58,
    disabled:damage.disabled===true
  };
}
