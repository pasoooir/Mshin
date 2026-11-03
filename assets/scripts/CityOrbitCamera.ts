import { _decorator, Component, EventTouch, Input, input, Node, Vec3 } from "cc";

const { ccclass, property } = _decorator;

/**
 * Touch-driven orbit and pinch-zoom camera for the native city scene.
 * Attach to the scene Camera node and assign the city pivot as target.
 * One-finger drag rotates; two-finger pinch changes camera distance.
 */
@ccclass("MshinCityOrbitCamera")
export class CityOrbitCamera extends Component {
  @property({ type: Node, tooltip: "World-space pivot around which the camera orbits." })
  target: Node | null = null;

  @property({ tooltip: "Orbit sensitivity in radians per screen-space unit." })
  sensitivity = 0.008;

  @property({ tooltip: "Minimum camera elevation in degrees." })
  minElevation = 12;

  @property({ tooltip: "Maximum camera elevation in degrees." })
  maxElevation = 72;

  @property({ tooltip: "Closest camera distance during pinch zoom." })
  minRadius = 12;

  @property({ tooltip: "Farthest camera distance during pinch zoom." })
  maxRadius = 90;

  private yaw = 0;
  private elevation = 38 * Math.PI / 180;
  private radius = 42;
  private ready = false;

  onEnable(): void {
    input.on(Input.EventType.TOUCH_MOVE, this.onTouchMove, this);
    this.initializeOrbit();
  }

  onDisable(): void {
    input.off(Input.EventType.TOUCH_MOVE, this.onTouchMove, this);
  }

  lateUpdate(): void {
    if (!this.ready || !this.target || !this.target.isValid) return;
    this.applyOrbit();
  }

  private initializeOrbit(): void {
    if (!this.target || !this.target.isValid) {
      console.warn("[MshinCity] CityOrbitCamera requires a valid target node.");
      this.ready = false;
      return;
    }

    const offset = new Vec3();
    Vec3.subtract(offset, this.node.worldPosition, this.target.worldPosition);
    this.radius = this.clampRadius(offset.length());
    this.yaw = Math.atan2(offset.x, offset.z);
    this.elevation = Math.asin(Math.min(1, Math.max(-1, offset.y / Math.max(this.radius, 0.001))));
    this.elevation = this.clampElevation(this.elevation);
    this.ready = true;
    this.applyOrbit();
  }

  private onTouchMove(event: EventTouch): void {
    if (!this.ready || !this.target || !this.target.isValid) return;

    const touches = event.getAllTouches();
    if (touches.length >= 2) {
      const first = touches[0];
      const second = touches[1];
      const previousA = first.getPreviousLocation();
      const previousB = second.getPreviousLocation();
      const currentA = first.getLocation();
      const currentB = second.getLocation();
      const previousDistance = Math.hypot(previousA.x - previousB.x, previousA.y - previousB.y);
      const currentDistance = Math.hypot(currentA.x - currentB.x, currentA.y - currentB.y);

      if (previousDistance > 0.001 && currentDistance > 0.001) {
        this.radius = this.clampRadius(this.radius * previousDistance / currentDistance);
      }
      return;
    }

    const delta = event.getUIDelta();
    this.yaw -= delta.x * this.sensitivity;
    this.elevation = this.clampElevation(this.elevation + delta.y * this.sensitivity);
  }

  private applyOrbit(): void {
    if (!this.target || !this.target.isValid) return;
    const horizontal = this.radius * Math.cos(this.elevation);
    const position = new Vec3(
      this.target.worldPosition.x + horizontal * Math.sin(this.yaw),
      this.target.worldPosition.y + this.radius * Math.sin(this.elevation),
      this.target.worldPosition.z + horizontal * Math.cos(this.yaw)
    );
    this.node.setWorldPosition(position);
    this.node.lookAt(this.target.worldPosition);
  }

  private clampElevation(value: number): number {
    const min = Math.min(this.minElevation, this.maxElevation) * Math.PI / 180;
    const max = Math.max(this.minElevation, this.maxElevation) * Math.PI / 180;
    return Math.min(max, Math.max(min, value));
  }

  private clampRadius(value: number): number {
    const min = Math.max(1, Math.min(this.minRadius, this.maxRadius));
    const max = Math.max(min, this.maxRadius);
    return Math.min(max, Math.max(min, value));
  }
}
