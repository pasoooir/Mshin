const DEFAULT_PITCH = Math.atan2(38, Math.hypot(48, 48));
const MIN_PITCH = 0.24;
const MAX_PITCH = 0.96;

/** Apply the city camera pose from one shared target, azimuth, elevation and zoom state. */
export function updateCityCameraTransform(camera, cam, viewportHeight) {
  const worldScale = Math.max(1, Number(viewportHeight) || 1) / 50;
  const targetX = Number.isFinite(cam.currentTargetX) ? cam.currentTargetX
    : Number.isFinite(cam.targetX) ? cam.targetX : -(cam.x || 0) / worldScale;
  const targetY = Number.isFinite(cam.currentTargetY) ? cam.currentTargetY
    : Number.isFinite(cam.targetY) ? cam.targetY : 0;
  const targetZ = Number.isFinite(cam.currentTargetZ) ? cam.currentTargetZ
    : Number.isFinite(cam.targetZ) ? cam.targetZ : -(cam.y || 0) / worldScale;
  const orbit = Number.isFinite(cam.orbit) ? cam.orbit : 0;
  const pitch = Math.max(MIN_PITCH, Math.min(MAX_PITCH,
    Number.isFinite(cam.pitch) ? cam.pitch : DEFAULT_PITCH));
  const orbitAngle = Math.PI / 4 + orbit;
  const orbitRadius = Math.hypot(48, 48);
  const horizontalRadius = orbitRadius * Math.cos(pitch);
  const verticalOffset = orbitRadius * Math.sin(pitch);
  camera.position.set(
    targetX + Math.sin(orbitAngle) * horizontalRadius,
    targetY + verticalOffset,
    targetZ + Math.cos(orbitAngle) * horizontalRadius
  );
  camera.lookAt(targetX, targetY, targetZ);
  camera.updateProjectionMatrix();
  camera.updateMatrixWorld(true);
  return { orbit, pitch, targetX, targetY, targetZ };
}
