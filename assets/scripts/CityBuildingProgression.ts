import { _decorator, Component } from "cc";

const { ccclass, property } = _decorator;

export type CityBuildingState = "constructing" | "complete";

/**
 * Construction timer and upgrade progression for a placed city building.
 * Attach this component to the root node of each placed building.
 */
@ccclass("MshinCityBuildingProgression")
export class CityBuildingProgression extends Component {
  @property({ tooltip: "Initial construction duration in seconds." })
  constructionDuration = 30;

  @property({ tooltip: "Maximum supported building level." })
  maxLevel = 5;

  @property({ tooltip: "Additional construction time per upgrade level, in seconds." })
  upgradeDuration = 12;

  private remainingSeconds = 0;
  private currentState: CityBuildingState = "constructing";
  private currentLevel = 1;

  get state(): CityBuildingState {
    return this.currentState;
  }

  get level(): number {
    return this.currentLevel;
  }

  get constructionProgress(): number {
    if (this.currentState === "complete") return 1;
    const duration = Math.max(0.001, this.constructionDuration);
    return Math.min(1, Math.max(0, 1 - this.remainingSeconds / duration));
  }

  get secondsRemaining(): number {
    return Math.max(0, this.remainingSeconds);
  }

  onEnable(): void {
    if (this.currentState === "constructing" && this.remainingSeconds <= 0) {
      this.beginConstruction(this.constructionDuration);
    }
  }

  update(deltaTime: number): void {
    if (this.currentState !== "constructing") return;
    this.remainingSeconds = Math.max(0, this.remainingSeconds - Math.max(0, deltaTime));
    if (this.remainingSeconds === 0) {
      this.currentState = "complete";
      console.info("[MshinCity] Building construction completed:", this.node.name);
    }
  }

  /** Starts or restarts construction for this placed building. */
  beginConstruction(durationSeconds = this.constructionDuration): void {
    this.constructionDuration = Math.max(0, durationSeconds);
    this.remainingSeconds = this.constructionDuration;
    this.currentState = this.remainingSeconds === 0 ? "complete" : "constructing";
  }

  /**
   * Starts an upgrade cycle when the building is complete and below max level.
   * Returns false when an upgrade cannot be started.
   */
  upgrade(): boolean {
    if (this.currentState !== "complete" || this.currentLevel >= Math.max(1, this.maxLevel)) {
      return false;
    }

    this.currentLevel += 1;
    this.beginConstruction(this.upgradeDuration);
    console.info("[MshinCity] Building upgrade started:", this.node.name, "level", this.currentLevel);
    return true;
  }
}
