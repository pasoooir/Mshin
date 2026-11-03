/** Small deterministic PRNG for reproducible city simulation and save replay. */
export interface SeededRandom {
  nextUint32(): number;
  next(): number;
}

export function createSeededRandom(seed: number): SeededRandom {
  if (!Number.isSafeInteger(seed)) throw new RangeError("Random seed must be a safe integer");
  let state = seed >>> 0;

  const nextUint32 = (): number => {
    state = (state + 0x6d2b79f5) >>> 0;
    let value = state;
    value = Math.imul(value ^ (value >>> 15), value | 1);
    value ^= value + Math.imul(value ^ (value >>> 7), value | 61);
    return (value ^ (value >>> 14)) >>> 0;
  };
  return {
    nextUint32,
    next: () => nextUint32() / 0x1_0000_0000
  };
}
