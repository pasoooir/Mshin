import { sys } from "cc";
import { StageDefinition } from "../../src/stage-catalog";
import {
  PlayerProgress,
  completeProgress,
  freshProgress,
  isStageSelectable,
  normalizeProgress,
} from "../../src/progress";

const KEY = "mshin.progress.v1";
export type { PlayerProgress } from "../../src/progress";

export class ProgressStore {
  static load(): PlayerProgress {
    try {
      const raw = sys.localStorage.getItem(KEY);
      if (!raw) return freshProgress();
      return normalizeProgress(JSON.parse(raw) as unknown);
    } catch {
      return freshProgress();
    }
  }

  static save(progress: PlayerProgress): void {
    try {
      sys.localStorage.setItem(KEY, JSON.stringify(normalizeProgress(progress)));
    } catch {
      // Keep the current race playable if browser storage is unavailable or full.
    }
  }

  static isUnlocked(id: number, _progress = ProgressStore.load()): boolean {
    return isStageSelectable(id);
  }

  static complete(stage: StageDefinition, time: number): PlayerProgress {
    const progress = completeProgress(ProgressStore.load(), stage.id, time);
    this.save(progress);
    return progress;
  }
}
