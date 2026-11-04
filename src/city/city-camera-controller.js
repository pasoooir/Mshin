const MIN_ZOOM = 0.05;
const MAX_ZOOM = 1.5;
const ORBIT_SENSITIVITY = 0.009;
const TAP_SLOP = 5;
const INERTIA_MAX_SPEED = 0.18;
const INERTIA_MAX_DURATION_MS = 900;
const MIN_PITCH = 0.24;
const MAX_PITCH = 0.96;
const PITCH_SENSITIVITY = 0.004;
const clamp = (value, min, max) => Math.max(min, Math.min(max, value));
const midpoint = ([a, b]) => ({ x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 });
const distance = ([a, b]) => Math.max(1, Math.hypot(b.x - a.x, b.y - a.y));
const angle = ([a, b]) => Math.atan2(b.y - a.y, b.x - a.x);
const angleDelta = (next, previous) => Math.atan2(Math.sin(next - previous), Math.cos(next - previous));

/**
 * Owns the city viewport's pointer lifecycle and camera gestures.
 * Camera coordinates and raycast anchors are world-space; pointer coordinates are CSS pixels.
 */
export function createCityCameraController({
  canvas, camera, getRenderer, getTileAt, onTap, onChange,
  isCameraLocked = () => false
}) {
  const pointers = new Map();
  const originalTouchAction = canvas.style.touchAction;
  let gesture = null;
  let inertiaTimer = 0;
  let focusFrame = 0;
  let pendingFling = 0;
  let inertiaActive = false;
  let lastInertiaVelocity = 0;

  const pair = () => [...pointers.values()].slice(0, 2);
  const renderer = () => getRenderer();
  const groundAt = point => renderer()?.groundPointAt?.(point.x, point.y) ?? null;
  const focusAt = point => renderer()?.focusPointAt?.(point.x, point.y) ?? groundAt(point);
  const update = () => {
    renderer()?.updateCamera?.(camera);
    onChange?.();
  };
  const shiftTarget = (before, after) => {
    if (!before || !after) return;
    camera.targetX = (Number.isFinite(camera.targetX) ? camera.targetX : 0) + before.x - after.x;
    camera.targetZ = (Number.isFinite(camera.targetZ) ? camera.targetZ : 0) + before.z - after.z;
  };

  function stopFocus() {
    if (focusFrame && typeof cancelAnimationFrame === "function") cancelAnimationFrame(focusFrame);
    focusFrame = 0;
    if (Number.isFinite(camera.currentTargetX)) camera.targetX = camera.currentTargetX;
    if (Number.isFinite(camera.currentTargetY)) camera.targetY = camera.currentTargetY;
    if (Number.isFinite(camera.currentTargetZ)) camera.targetZ = camera.currentTargetZ;
    camera.currentTargetX = undefined;
    camera.currentTargetY = undefined;
    camera.currentTargetZ = undefined;
  }

  function animateFocus(point) {
    const startX = Number.isFinite(camera.currentTargetX) ? camera.currentTargetX : (camera.targetX || 0);
    const startY = Number.isFinite(camera.currentTargetY) ? camera.currentTargetY : (camera.targetY || 0);
    const startZ = Number.isFinite(camera.currentTargetZ) ? camera.currentTargetZ : (camera.targetZ || 0);
    const targetY = Number.isFinite(point.y) ? point.y : 0;
    camera.targetX = point.x;
    camera.targetY = targetY;
    camera.targetZ = point.z;
    if (typeof requestAnimationFrame !== "function") {
      camera.currentTargetX = point.x;
      camera.currentTargetY = targetY;
      camera.currentTargetZ = point.z;
      update();
      return;
    }
    camera.currentTargetX = startX;
    camera.currentTargetY = startY;
    camera.currentTargetZ = startZ;
    const started = performance.now();
    const tick = now => {
      const t = clamp((now - started) / 420, 0, 1);
      const eased = 1 - Math.pow(1 - t, 3);
      camera.currentTargetX = startX + (point.x - startX) * eased;
      camera.currentTargetY = startY + (targetY - startY) * eased;
      camera.currentTargetZ = startZ + (point.z - startZ) * eased;
      update();
      if (t < 1) focusFrame = requestAnimationFrame(tick);
      else {
        focusFrame = 0;
        camera.currentTargetX = undefined;
        camera.currentTargetY = undefined;
        camera.currentTargetZ = undefined;
        update();
      }
    };
    update();
    focusFrame = requestAnimationFrame(tick);
  }

  function stopInertia() {
    if (inertiaTimer) clearTimeout(inertiaTimer);
    inertiaTimer = 0;
    inertiaActive = false;
    lastInertiaVelocity = 0;
  }

  function startInertia(velocity) {
    if (!Number.isFinite(velocity) || Math.abs(velocity) < 0.0008) return;
    let speed = clamp(velocity * 0.72, -INERTIA_MAX_SPEED, INERTIA_MAX_SPEED);
    let previousTime = 0;
    const startedAt = typeof performance !== "undefined" ? performance.now() : Date.now();
    inertiaActive = true;
    const tick = () => {
      const now = typeof performance !== "undefined" ? performance.now() : Date.now();
      const elapsed = previousTime ? clamp(now - previousTime, 8, 40) : 16;
      previousTime = now;
      const frameScale = elapsed / 16.667;
      camera.orbit = (camera.orbit || 0) + speed * frameScale;
      speed *= Math.pow(0.84, frameScale);
      lastInertiaVelocity = speed;
      update();
      if (Math.abs(speed) > 0.00035 && now - startedAt < INERTIA_MAX_DURATION_MS) {
        inertiaTimer = setTimeout(tick, 16);
      } else {
        inertiaTimer = 0;
        inertiaActive = false;
        lastInertiaVelocity = 0;
      }
    };
    inertiaTimer = setTimeout(tick, 16);
  }

  function beginGesture(suppressTap = false) {
    if (pointers.size >= 2) {
      const points = pair();
      const center = midpoint(points);
      gesture = {
        mode: "pinch-orbit",
        lastMidpoint: center,
        lastAngle: angle(points),
        lastDistance: distance(points),
        baseDistance: distance(points),
        baseZoom: Number.isFinite(camera.zoom) ? camera.zoom : 0.72,
        baseOrbit: Number.isFinite(camera.orbit) ? camera.orbit : 0,
        baseMidpoint: center,
        baseAngle: angle(points),
        lastAppliedRotation: 0,
        anchor: groundAt(center),
        velocity: 0,
        lastMoveTime: 0
      };
    } else if (pointers.size === 1) {
      const point = pair()[0];
      gesture = {
        mode: "pan",
        start: { x: point.x, y: point.y },
        anchor: groundAt(point),
        cameraX: camera.x || 0,
        cameraY: camera.y || 0,
        moved: suppressTap
      };
    } else gesture = null;
  }

  function pointerDown(event) {
    if (event.pointerType === "mouse" && event.button !== 0) return;
    if (pointers.has(event.pointerId)) return;
    stopInertia();
    stopFocus();
    pendingFling = 0;
    event.preventDefault();
    pointers.set(event.pointerId, {
      id: event.pointerId,
      x: event.clientX,
      y: event.clientY,
      startX: event.clientX,
      startY: event.clientY
    });
    try { canvas.setPointerCapture(event.pointerId); } catch {}
    beginGesture(pointers.size > 1);
  }

  function pointerMove(event) {
    const pointer = pointers.get(event.pointerId);
    if (!pointer) return;
    event.preventDefault();
    pointer.x = event.clientX;
    pointer.y = event.clientY;

    if (pointers.size >= 2 && gesture?.mode === "pinch-orbit" && !isCameraLocked()) {
      const points = pair();
      const center = midpoint(points);
      const nextAngle = angle(points);
      const nextDistance = distance(points);
      const gestureState = gesture;
      const now = Number.isFinite(event.timeStamp) ? event.timeStamp : 0;
      const elapsed = gestureState.lastMoveTime && now > gestureState.lastMoveTime
        ? clamp(now - gestureState.lastMoveTime, 8, 50) : 16.667;

      // Derive orbit from the gesture baseline. Pointer events arrive one finger at
      // a time, so incremental angle accumulation can introduce transient azimuth
      // drift during a pure vertical two-finger translation.
      const totalRotation = (center.x - gestureState.baseMidpoint.x) * ORBIT_SENSITIVITY
        + angleDelta(nextAngle, gestureState.baseAngle);
      const rotation = totalRotation - gestureState.lastAppliedRotation;
      camera.orbit = gestureState.baseOrbit + totalRotation;
      gestureState.lastAppliedRotation = totalRotation;
      // Multiplicative distance ratio makes zoom independent of the starting span.
      // Derive zoom from the gesture baseline, not the previously clamped value.
      // This prevents asynchronous per-pointer move events from causing irreversible
      // zoom jumps when both fingers translate together and the temporary span collapses.
      camera.zoom = clamp(gestureState.baseZoom * nextDistance / gestureState.baseDistance, MIN_ZOOM, MAX_ZOOM);
      // Vertical translation of the two-finger midpoint adjusts camera elevation.
      // Rebase is continuous across pointer events and clamped to a usable city view.
      const pitch = Number.isFinite(camera.pitch) ? camera.pitch : 0.51;
      camera.pitch = clamp(pitch - (center.y - gestureState.lastMidpoint.y) * PITCH_SENSITIVITY, MIN_PITCH, MAX_PITCH);
      // Velocity is measured from the net gesture displacement, not the transient
      // one-finger intermediate vector. A pure vertical two-finger translation must
      // not leave a horizontal fling when the second finger catches up.
      const measuredVelocity = totalRotation / (elapsed / 16.667);
      gestureState.velocity = Number.isFinite(measuredVelocity) ? measuredVelocity : 0;
      gestureState.lastMidpoint = center;
      gestureState.lastAngle = nextAngle;
      gestureState.lastDistance = nextDistance;
      gestureState.lastMoveTime = now;

      update();
      shiftTarget(gestureState.anchor, groundAt(center));
      update();
      return;
    }

    if (pointers.size === 1 && gesture?.mode === "pan") {
      pendingFling = 0;
      if (Math.hypot(pointer.x - gesture.start.x, pointer.y - gesture.start.y) > TAP_SLOP) gesture.moved = true;
      if (!gesture.moved || isCameraLocked()) return;
      const hit = groundAt(pointer);
      if (gesture.anchor && hit) {
        shiftTarget(gesture.anchor, hit);
        update();
      } else {
        camera.x = gesture.cameraX + pointer.x - gesture.start.x;
        camera.y = gesture.cameraY + pointer.y - gesture.start.y;
        update();
      }
    }
  }

  function finishPointer(event, cancelled = false) {
    const pointer = pointers.get(event.pointerId);
    if (!pointer) return;
    const previousCount = pointers.size;
    const previousMode = gesture?.mode;
    if (previousMode === "pinch-orbit" && previousCount === 2) {
      pendingFling = cancelled ? 0 : gesture.velocity;
    }
    const isTap = !cancelled && event.type === "pointerup" && previousCount === 1
      && previousMode === "pan" && !gesture.moved
      && Math.hypot(event.clientX - pointer.startX, event.clientY - pointer.startY) <= TAP_SLOP;

    if (isTap) {
      const screenPoint = { x: event.clientX, y: event.clientY };
      const hit = focusAt(screenPoint);
      if (hit && !isCameraLocked()) {
        camera.x = 0;
        camera.y = 0;
        animateFocus(hit);
      }
      const tile = renderer()?.tileAt(event.clientX, event.clientY) ?? getTileAt?.(event.clientX, event.clientY);
      onTap?.(tile?.x ?? -1, tile?.y ?? -1);
    }

    pointers.delete(event.pointerId);
    try {
      if (canvas.hasPointerCapture(event.pointerId)) canvas.releasePointerCapture(event.pointerId);
    } catch {}

    const transitionedFromPinch = previousMode === "pinch-orbit" && previousCount === 2 && pointers.size === 1;
    beginGesture(transitionedFromPinch);
    if (pointers.size === 0) {
      if (!cancelled && pendingFling) startInertia(pendingFling);
      pendingFling = 0;
    }
  }

  function pointerUp(event) { finishPointer(event, false); }
  function pointerCancel(event) { finishPointer(event, true); }

  function wheel(event) {
    stopFocus();
    event.preventDefault();
    const point = { x: event.clientX, y: event.clientY };
    const anchor = groundAt(point);
    camera.zoom = clamp((camera.zoom || 0.72) * Math.exp(-event.deltaY * 0.0015), MIN_ZOOM, MAX_ZOOM);
    update();
    shiftTarget(anchor, groundAt(point));
    update();
  }

  canvas.style.touchAction = "none";
  canvas.addEventListener("pointerdown", pointerDown, { passive: false });
  canvas.addEventListener("pointermove", pointerMove, { passive: false });
  canvas.addEventListener("pointerup", pointerUp);
  canvas.addEventListener("pointercancel", pointerCancel);
  canvas.addEventListener("lostpointercapture", pointerCancel);
  canvas.addEventListener("wheel", wheel, { passive: false });

  return {
    getState: () => ({
      pointers: pointers.size,
      gesture: gesture?.mode ?? "idle",
      zoom: camera.zoom,
      orbit: camera.orbit || 0,
      pitch: Number.isFinite(camera.pitch) ? camera.pitch : 0.51,
      inertiaActive,
      lastInertiaVelocity,
      pendingFling
    }),
    cancelMotion() {
      stopInertia();
      stopFocus();
      pendingFling = 0;
    },
    destroy() {
      canvas.removeEventListener("pointerdown", pointerDown);
      canvas.removeEventListener("pointermove", pointerMove);
      canvas.removeEventListener("pointerup", pointerUp);
      canvas.removeEventListener("pointercancel", pointerCancel);
      canvas.removeEventListener("lostpointercapture", pointerCancel);
      canvas.removeEventListener("wheel", wheel);
      stopInertia();
      stopFocus();
      for (const id of pointers.keys()) {
        try { if (canvas.hasPointerCapture(id)) canvas.releasePointerCapture(id); } catch {}
      }
      pointers.clear();
      gesture = null;
      pendingFling = 0;
      canvas.style.touchAction = originalTouchAction;
    }
  };
}
