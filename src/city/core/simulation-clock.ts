export type SimulationSpeed = 0 | 1 | 2 | 4;

export interface SimulationClockOptions {
  tickSeconds?: number;
  maxTicksPerAdvance?: number;
  initialSpeed?: SimulationSpeed;
}

export interface SimulationAdvance {
  ticksRun: number;
  firstTick: number | null;
  lastTick: number | null;
  simulatedSeconds: number;
  pendingTicks: number;
  interpolationAlpha: number;
}

/**
 * Fixed-step simulation clock. Excess due ticks are retained as backlog instead
 * of being dropped, while maxTicksPerAdvance prevents a single render frame
 * from monopolizing the main thread after a pause or tab suspension.
 */
export class SimulationClock {
  readonly tickSeconds: number;
  readonly maxTicksPerAdvance: number;
  private accumulatorSeconds = 0;
  private currentTick = 0;
  private currentSpeed: SimulationSpeed;

  constructor(options: SimulationClockOptions = {}) {
    const tickSeconds = options.tickSeconds ?? 1;
    const maxTicks = options.maxTicksPerAdvance ?? 8;
    if (!Number.isFinite(tickSeconds) || tickSeconds <= 0) throw new RangeError("tickSeconds must be greater than zero");
    if (!Number.isSafeInteger(maxTicks) || maxTicks < 1) throw new RangeError("maxTicksPerAdvance must be a positive integer");
    this.tickSeconds = tickSeconds;
    this.maxTicksPerAdvance = maxTicks;
    this.currentSpeed = options.initialSpeed ?? 1;
    this.assertSpeed(this.currentSpeed);
  }

  get tick(): number { return this.currentTick; }
  get speed(): SimulationSpeed { return this.currentSpeed; }
  get isPaused(): boolean { return this.currentSpeed === 0; }
  get pendingTicks(): number { return Math.floor((this.accumulatorSeconds + 1e-9) / this.tickSeconds); }
  get interpolationAlpha(): number { return Math.min(1, this.accumulatorSeconds / this.tickSeconds); }

  setSpeed(speed: SimulationSpeed): void {
    this.assertSpeed(speed);
    this.currentSpeed = speed;
  }

  advance(realDeltaSeconds: number, onTick: (tick: number, tickSeconds: number) => void): SimulationAdvance {
    if (!Number.isFinite(realDeltaSeconds) || realDeltaSeconds < 0) {
      throw new RangeError("realDeltaSeconds must be a finite non-negative number");
    }
    if (typeof onTick !== "function") throw new TypeError("onTick callback is required");

    if (this.currentSpeed > 0) this.accumulatorSeconds += realDeltaSeconds * this.currentSpeed;
    const due = this.pendingTicks;
    const ticksToRun = Math.min(due, this.maxTicksPerAdvance);
    const firstTick = ticksToRun > 0 ? this.currentTick + 1 : null;
    let lastTick: number | null = null;

    for (let index = 0; index < ticksToRun; index += 1) {
      const nextTick = this.currentTick + 1;
      onTick(nextTick, this.tickSeconds);
      this.currentTick = nextTick;
      this.accumulatorSeconds = Math.max(0, this.accumulatorSeconds - this.tickSeconds);
      lastTick = nextTick;
    }

    return {
      ticksRun: ticksToRun,
      firstTick,
      lastTick,
      simulatedSeconds: ticksToRun * this.tickSeconds,
      pendingTicks: this.pendingTicks,
      interpolationAlpha: this.interpolationAlpha
    };
  }

  reset(tick = 0): void {
    if (!Number.isSafeInteger(tick) || tick < 0) throw new RangeError("tick must be a non-negative safe integer");
    this.currentTick = tick;
    this.accumulatorSeconds = 0;
  }

  private assertSpeed(speed: number): asserts speed is SimulationSpeed {
    if (speed !== 0 && speed !== 1 && speed !== 2 && speed !== 4) {
      throw new RangeError("Simulation speed must be 0, 1, 2, or 4");
    }
  }
}
