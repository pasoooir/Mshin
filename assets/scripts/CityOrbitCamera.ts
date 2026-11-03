import { _decorator, Component, EventTouch, Input, input, Node, Vec3 } from "cc";

const { ccclass, property } = _decorator;

/**
 * Touch-driven orbit camera for the native city scene.
 * Attach to the scene Camera node and assign the city pivot as target.
 * Horizontal dragging is unbounded so players can rotate through 360 degrees.
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
    if (!this.target) {
      console.warn("[MshinCity] CityOrbitCamera requires a target node.");
      this.ready = false;
      return;
    }

    const offset = new Vec3();
    Vec3.subtract(offset, this.node.worldPosition, this.target.worldPosition);
    this.radius = Math.max(8, offset.length());
    this.yaw = Math.atan2(offset.x, offset.z);
    this.elevation = Math.asin(Math.min(1, Math.max(-1, offset.y / this.radius)));
    this.elevation = this.clampElevation(this.elevation);
    this.ready = true;
    this.applyOrbit();
  }

  private onTouchMove(event: EventTouch): void {
    if (!this.ready || !this.target) return;
    const delta = event.getUIDelta();
    this.yaw -= delta.x * this.sensitivity;
    this.elevation = this.clampElevation(this.elevation + delta.y * this.sensitivity);
  }

  private applyOrbit(): void {
    if (!this.target) return;
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
    const min = this.minElevation * Math.PI / 180;
    const max = this.maxElevation * Math.PI / 180;
    return Math.min(max, Math.max(min, value));
  }
}
