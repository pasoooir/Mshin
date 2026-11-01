/**
 * Independent multi-pointer input state for the race HUD.
 *
 * Pointer ownership is tracked per control, not globally. A steering pointer can
 * never release a pedal pointer, and releasing one pedal cannot clear another.
 */
const CONTROL_NAMES = Object.freeze(["steering", "throttle", "brake", "turbo"]);

const clamp = (value, min, max) => Math.max(min, Math.min(max, value));

export function createInputStateManager() {
  const pointers = new Map(CONTROL_NAMES.map((name) => [name, new Map()]));
  let steering = 0;

  function set(control, pointerId, value = true) {
    const owned = pointers.get(control);
    if (!owned || !Number.isFinite(pointerId)) return false;

    if (control === "steering") {
      const normalized = clamp(Number(value) || 0, -1, 1);
      if (normalized === 0) owned.delete(pointerId);
      else owned.set(pointerId, normalized);
      steering = normalized;
    } else {
      owned.set(pointerId, Boolean(value));
    }
    return true;
  }

  function release(control, pointerId) {
    const owned = pointers.get(control);
    if (!owned || !owned.has(pointerId)) return false;
    owned.delete(pointerId);
    if (control === "steering") {
      const remaining = [...owned.values()];
      steering = remaining.length ? remaining[remaining.length - 1] : 0;
    }
    return true;
  }

  function releasePointer(pointerId) {
    let released = false;
    for (const control of CONTROL_NAMES) {
      released = release(control, pointerId) || released;
    }
    return released;
  }

  function releaseAll() {
    for (const owned of pointers.values()) owned.clear();
    steering = 0;
  }

  function snapshot() {
    const pressed = (control) => [...pointers.get(control).values()].some(Boolean);
    return Object.freeze({
      steering,
      throttle: pressed("throttle") ? 1 : 0,
      brake: pressed("brake") ? 1 : 0,
      turbo: pressed("turbo"),
      activePointers: Object.freeze(Object.fromEntries(
        CONTROL_NAMES.map((control) => [control, pointers.get(control).size])
      ))
    });
  }

  function pointerCount() {
    return CONTROL_NAMES.reduce((sum, control) => sum + pointers.get(control).size, 0);
  }

  return Object.freeze({ set, release, releasePointer, releaseAll, snapshot, pointerCount });
}
