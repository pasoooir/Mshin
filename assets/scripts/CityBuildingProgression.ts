import { _decorator, Component } from "cc";
import {
  advanceCityBuildingProgression,
  cityBuildingProgress,
  createCityBuildingProgression,
  startCityBuildingUpgrade,
  type CityBuildingProgressionState,
  type CityBuildingState
} from "../../src/city/core/building-progression.js";

const { ccclass, property } = _decorator;

/**
 * Cocos adapter for the engine-independent city building lifecycle.
 * Attach to the root node of a placed building.
 */
@ccclass("MshinCityBuildingProgression")
export class CityBuildingProgression extends Component {
  @property({ tooltip: "Initial construction duration in seconds." })
  constructionDuration = 30;

  @property({ tooltip: "Maximum supported building level." })
  maxLevel = 5;

  @property({ tooltip: "Construction time for each upgrade, in seconds." })
  upgradeDuration = 12;

  private progression: CityBuildingProgressionState | null = null;

  onLoad(): void {
    this.progression = createCityBuildingProgression({
      constructionDuration: this.constructionDuration,
      maxLevel: this.maxLevel,
      upgradeDuration: this.upgradeDuration
    });
  }

  update(deltaTime: number): void {
    if (!this.progression) return;
    this.progression = advanceCityBuildingProgression(this.progression, deltaTime);
  }

  get state(): CityBuildingState {
    return this.progression?.state ?? "constructing";
  }

  get level(): number {
    return this.progression?.level ?? 1;
  }

  get constructionProgress(): number {
    return this.progression ? cityBuildingProgress(this.progression) : 0;
  }

  get secondsRemaining(): number {
    return this.progression?.secondsRemaining ?? Math.max(0, this.constructionDuration);
  }

  /** Starts a new construction cycle without changing the building level. */
  beginConstruction(durationSeconds = this.constructionDuration): void {
    const duration = Number.isFinite(durationSeconds) ? Math.max(0, durationSeconds) : 0;
    const currentLevel = this.progression?.level ?? 1;
    this.constructionDuration = duration;
    this.progression = createCityBuildingProgression({
      constructionDuration: duration,
      maxLevel: this.maxLevel,
      upgradeDuration: this.upgradeDuration
    });
    this.progression.level = Math.min(Math.max(1, currentLevel), this.progression.maxLevel);
  }

  /** Starts the next upgrade cycle, or returns false if the building cannot upgrade. */
  upgrade(): boolean {
    if (!this.progression) return false;
    const next = startCityBuildingUpgrade(this.progression);
    if (!next) return false;
    this.progression = next;
    return true;
  }
}
