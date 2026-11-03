/** Engine-independent, serializable root state for one offline city. */
export interface CityState {
  readonly schemaVersion: 1;
  readonly cityId: string;
  readonly name: string;
  readonly seed: number;
  readonly simulationTick: number;
}

export interface CreateCityStateInput {
  cityId: string;
  name: string;
  seed: number;
}

function requireNonEmpty(value: string, field: string): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new TypeError(`${field} must be a non-empty string`);
  }
  return value.trim();
}

/** Creates a new city without depending on browser, Cocos, or wall-clock APIs. */
export function createCityState(input: CreateCityStateInput): CityState {
  if (!input || typeof input !== "object") throw new TypeError("City input is required");
  if (!Number.isSafeInteger(input.seed)) throw new RangeError("City seed must be a safe integer");
  return Object.freeze({
    schemaVersion: 1 as const,
    cityId: requireNonEmpty(input.cityId, "cityId"),
    name: requireNonEmpty(input.name, "name"),
    seed: input.seed >>> 0,
    simulationTick: 0
  });
}

/** Advances authoritative simulation time by exactly one tick, returning a new state. */
export function advanceCityTick(state: CityState): CityState {
  if (!state || state.schemaVersion !== 1 || !Number.isSafeInteger(state.simulationTick) || state.simulationTick < 0) {
    throw new TypeError("Invalid city state");
  }
  if (state.simulationTick >= Number.MAX_SAFE_INTEGER) throw new RangeError("City simulation tick overflow");
  return Object.freeze({ ...state, simulationTick: state.simulationTick + 1 });
}
