export interface PlayerProgress {
  unlockedStage: number;
  completed: number[];
  bestTimes: Record<string, number>;
}

export const MAX_STAGES = 50;

export function freshProgress(): PlayerProgress {
  return { unlockedStage: 1, completed: [], bestTimes: {} };
}

export function normalizeProgress(value: unknown): PlayerProgress {
  if (!value || typeof value !== "object" || Array.isArray(value)) return freshProgress();
  const raw = value as Partial<PlayerProgress>;
  const completed = Array.isArray(raw.completed)
    ? [...new Set(raw.completed.filter((id): id is number =>
        Number.isInteger(id) && id >= 1 && id <= MAX_STAGES))]
    : [];
  const unlockedStage = Number.isInteger(raw.unlockedStage)
    ? Math.max(1, Math.min(MAX_STAGES, raw.unlockedStage as number))
    : 1;
  const bestTimes: Record<string, number> = {};
  if (raw.bestTimes && typeof raw.bestTimes === "object" && !Array.isArray(raw.bestTimes)) {
    for (const [key, value] of Object.entries(raw.bestTimes)) {
      const id = Number(key);
      if (Number.isInteger(id) && id >= 1 && id <= MAX_STAGES &&
          typeof value === "number" && Number.isFinite(value) && value > 0) {
        bestTimes[String(id)] = value;
      }
    }
  }
  return { unlockedStage, completed, bestTimes };
}

/** All 50 stages are intentionally selectable; completion is tracked separately. */
export function isStageSelectable(id: number): boolean {
  return Number.isInteger(id) && id >= 1 && id <= MAX_STAGES;
}

export function completeProgress(current: unknown, stageId: number, elapsedSeconds: number): PlayerProgress {
  if (!isStageSelectable(stageId)) throw new RangeError("Stage id must be between 1 and 50.");
  if (!Number.isFinite(elapsedSeconds) || elapsedSeconds <= 0) {
    throw new RangeError("Elapsed time must be a finite positive number.");
  }
  const progress = normalizeProgress(current);
  if (!progress.completed.includes(stageId)) progress.completed.push(stageId);
  progress.unlockedStage = Math.max(progress.unlockedStage, Math.min(MAX_STAGES, stageId + 1));
  const key = String(stageId);
  const previous = progress.bestTimes[key];
  if (previous === undefined || elapsedSeconds < previous) progress.bestTimes[key] = elapsedSeconds;
  return progress;
}
