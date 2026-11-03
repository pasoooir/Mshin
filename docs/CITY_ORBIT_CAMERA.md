# Native city orbit camera

## Component

`assets/scripts/CityOrbitCamera.ts` adds a native Cocos Creator 3.8.6 orbit and zoom controller.

- Attach `MshinCityOrbitCamera` to the scene's Camera node.
- Assign a pivot Node positioned at the center of the playable city to the `target` property.
- Set the Camera's initial world position before entering Play; the component derives its initial yaw, elevation and distance from that transform.
- One-finger drag rotates continuously through 360 degrees and adjusts elevation within the configured limits.
- Two-finger pinch zooms in/out; camera distance is clamped by `minRadius` and `maxRadius`.
- The controller unregisters its global touch listener when disabled or destroyed.

## Integration boundary

The repository currently contains no serialized `.scene` asset (only `assets/scenes/.gitkeep`). This component is therefore delivered as a reusable native runtime component, not as a claim that the city scene or APK is already wired. A Cocos Creator Editor import, camera-pivot assignment, scene preview and Android device test remain required.

## Acceptance checks

1. Camera completes a full horizontal revolution without a yaw clamp.
2. One-finger vertical movement remains between the configured minimum and maximum elevation.
3. Pinch-in and pinch-out adjust distance without crossing configured radius bounds.
4. A two-finger gesture does not also rotate the camera.
5. Disabling the component removes the touch listener.
6. Missing or destroyed target is handled without runtime exceptions.
7. Verify gestures on a physical Android device after scene integration.
