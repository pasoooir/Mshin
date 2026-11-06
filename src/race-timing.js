/** Race-clock helpers shared by player and AI finish-line detection. */
export function crossedFinishLine(previousDistance, distanceTravelled, trackLength) {
  return Number.isFinite(previousDistance)
    && Number.isFinite(distanceTravelled)
    && Number.isFinite(trackLength)
    && trackLength > 0
    && distanceTravelled >= 0
    && previousDistance + distanceTravelled >= trackLength;
}

export function finishLineFraction(previousDistance, distanceTravelled, trackLength) {
  if (!crossedFinishLine(previousDistance, distanceTravelled, trackLength)) return null;
  return Math.round(Math.max(0, Math.min(1, (trackLength - previousDistance) / Math.max(distanceTravelled, Number.EPSILON))) * 1e12) / 1e12;
}

export function finishTimestamp(raceElapsed, deltaSeconds, previousDistance, distanceTravelled, trackLength) {
  const fraction = finishLineFraction(previousDistance, distanceTravelled, trackLength);
  if (fraction === null || !Number.isFinite(raceElapsed) || !Number.isFinite(deltaSeconds)) return null;
  return raceElapsed + deltaSeconds * fraction;
}

/** Each entrant owns an independent stopwatch, all started at the same GO timestamp. */
export function createRaceClock() { return { startedAt: null, elapsed: 0, finishTime: null, running: false }; }
export function startRaceClock(clock, timestamp) { return { startedAt: Number.isFinite(timestamp) ? timestamp : 0, elapsed: 0, finishTime: null, running: true }; }
export function advanceRaceClock(clock, deltaSeconds) {
  if (!clock || !clock.running || !Number.isFinite(deltaSeconds)) return clock?.elapsed ?? 0;
  clock.elapsed = Math.max(0, clock.elapsed + Math.max(0, deltaSeconds));
  return clock.elapsed;
}
export function finishRaceClock(clock, exactFinishTime = clock?.elapsed ?? 0) {
  if (!clock) return 0;
  const finishTime = Number.isFinite(exactFinishTime) ? Math.max(0, exactFinishTime) : clock.elapsed;
  clock.elapsed = finishTime; clock.finishTime = finishTime; clock.running = false; return finishTime;
}
