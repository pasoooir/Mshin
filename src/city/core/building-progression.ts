export type CityBuildingState = "constructing" | "complete";

export interface CityBuildingProgressionConfig {
  constructionDuration?: number;
  upgradeDuration?: number;
  maxLevel?: number;
}

export interface CityBuildingProgressionState {
  state: CityBuildingState;
  level: number;
  maxLevel: number;
  constructionDuration: number;
  upgradeDuration: number;
  secondsRemaining: number;
}

function nonNegativeFinite(value: number | undefined, fallback: number): number {
  return typeof value === "number" && Number.isFinite(value) ? Math.max(0, value) : fallback;
}

export function createCityBuildingProgression(
  config: CityBuildingProgressionConfig = {}
): CityBuildingProgressionState {
  const constructionDuration = nonNegativeFinite(config.constructionDuration, 30);
  return {
    state: constructionDuration === 0 ? "complete" : "constructing",
    level: 1,
    maxLevel: Math.max(1, Math.floor(nonNegativeFinite(config.maxLevel, 5))),
    constructionDuration,
    upgradeDuration: nonNegativeFinite(config.upgradeDuration, 12),
    secondsRemaining: constructionDuration
  };
}

export function cityBuildingProgress(state: CityBuildingProgressionState): number {
  if (state.state === "complete") return 1;
  if (state.constructionDuration <= 0) return 1;
  return Math.min(1, Math.max(0, 1 - state.secondsRemaining / state.constructionDuration));
}

export function advanceCityBuildingProgression(
  state: CityBuildingProgressionState,
  deltaSeconds: number
): CityBuildingProgressionState {
  if (state.state === "complete") return state;
  const delta = typeof deltaSeconds === "number" && Number.isFinite(deltaSeconds)
    ? Math.max(0, deltaSeconds)
    : 0;
  const secondsRemaining = Math.max(0, state.secondsRemaining - delta);
  return {
    ...state,
    secondsRemaining,
    state: secondsRemaining === 0 ? "complete" : "constructing"
  };
}

export function startCityBuildingUpgrade(
  state: CityBuildingProgressionState
): CityBuildingProgressionState | null {
  if (state.state !== "complete" || state.level >= state.maxLevel) return null;
  const duration = state.upgradeDuration;
  return {
    ...state,
    level: state.level + 1,
    constructionDuration: duration,
    secondsRemaining: duration,
    state: duration === 0 ? "complete" : "constructing"
  };
}
