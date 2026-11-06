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
  return Math.max(0, Math.min(1, (trackLength - previousDistance) / Math.max(distanceTravelled, Number.EPSILON)));
}

export function finishTimestamp(raceElapsed, deltaSeconds, previousDistance, distanceTravelled, trackLength) {
  const fraction = finishLineFraction(previousDistance, distanceTravelled, trackLength);
  if (fraction === null || !Number.isFinite(raceElapsed) || !Number.isFinite(deltaSeconds)) return null;
  return raceElapsed + deltaSeconds * fraction;
}
