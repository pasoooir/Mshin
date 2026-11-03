import { _decorator, Camera, Component, EventTouch, geometry, Input, instantiate, input, Node, Prefab, Vec3 } from "cc";
import { CityBuildingProgression } from "./CityBuildingProgression";

const { ccclass, property } = _decorator;

/**
 * Touch placement controller for the native city scene.
 * Assign a camera, a building prefab and a world-space placement root.
 * The preview follows the ground plane; touch release commits a new building.
 */
@ccclass("MshinCityPlacementController")
export class CityPlacementController extends Component {
  @property({ type: Camera, tooltip: "Scene camera used to project screen touches into the city." })
  cityCamera: Camera | null = null;

  @property({ type: Prefab, tooltip: "Building prefab instantiated when the player places a building." })
  buildingPrefab: Prefab | null = null;

  @property({ type: Node, tooltip: "Parent node for preview and placed buildings." })
  placementRoot: Node | null = null;

  @property({ tooltip: "World-space height of the placement ground plane." })
  groundHeight = 0;

  @property({ tooltip: "Grid spacing in world units. Use zero to disable snapping." })
  gridSize = 1;

  @property({ tooltip: "Maximum ray distance accepted for placement." })
  maxPlacementDistance = 180;

  @property({ tooltip: "Initial construction duration assigned to placed buildings." })
  constructionDuration = 30;

  private preview: Node | null = null;
  private readonly ray = new geometry.Ray();
  private readonly hitPoint = new Vec3();
  private readonly previewPosition = new Vec3();
  private placementArmed = false;
  private previewValid = false;

  onEnable(): void {
    input.on(Input.EventType.TOUCH_MOVE, this.onTouchMove, this);
    input.on(Input.EventType.TOUCH_END, this.onTouchEnd, this);
    input.on(Input.EventType.TOUCH_CANCEL, this.onTouchCancel, this);
  }

  onDisable(): void {
    input.off(Input.EventType.TOUCH_MOVE, this.onTouchMove, this);
    input.off(Input.EventType.TOUCH_END, this.onTouchEnd, this);
    input.off(Input.EventType.TOUCH_CANCEL, this.onTouchCancel, this);
    this.cancelPlacement();
  }

  /** Arms placement and creates a local preview instance. */
  beginPlacement(): boolean {
    if (!this.cityCamera || !this.cityCamera.isValid || !this.buildingPrefab || !this.placementRoot || !this.placementRoot.isValid) {
      console.warn("[MshinCity] Placement requires a valid camera, prefab and placement root.");
      return false;
    }
    this.cancelPlacement();
    this.preview = instantiate(this.buildingPrefab);
    this.preview.name = this.buildingPrefab.name + " Preview";
    this.preview.setParent(this.placementRoot);
    this.preview.setScale(0.92, 0.92, 0.92);
    this.placementArmed = true;
    this.previewValid = false;
    return true;
  }

  /** Cancels placement and removes the preview without committing a building. */
  cancelPlacement(): void {
    this.placementArmed = false;
    this.previewValid = false;
    if (this.preview && this.preview.isValid) this.preview.destroy();
    this.preview = null;
  }

  private onTouchMove(event: EventTouch): void {
    if (this.placementArmed) this.updatePreview(event);
  }

  private onTouchEnd(event: EventTouch): void {
    if (!this.placementArmed) return;
    this.updatePreview(event);
    if (!this.previewValid || !this.preview || !this.preview.isValid || !this.placementRoot) return;

    const building = instantiate(this.buildingPrefab!);
    building.name = this.buildingPrefab!.name;
    building.setParent(this.placementRoot);
    building.setWorldPosition(this.previewPosition);
    const progression = building.addComponent(CityBuildingProgression);
    progression.beginConstruction(this.constructionDuration);
    this.cancelPlacement();
  }

  private onTouchCancel(): void {
    // Keep the placement tool armed, but hide a stale preview until the next valid move.
    this.previewValid = false;
    if (this.preview && this.preview.isValid) this.preview.active = false;
  }

  private updatePreview(event: EventTouch): void {
    if (!this.cityCamera || !this.cityCamera.isValid || !this.preview || !this.preview.isValid) return;
    const location = event.getLocation();
    this.cityCamera.screenPointToRay(this.ray, location.x, location.y);

    const directionY = this.ray.d.y;
    if (Math.abs(directionY) < 0.0001) {
      this.previewValid = false;
      this.preview.active = false;
      return;
    }

    const distance = (this.groundHeight - this.ray.o.y) / directionY;
    if (distance < 0 || distance > this.maxPlacementDistance) {
      this.previewValid = false;
      this.preview.active = false;
      return;
    }

    Vec3.scaleAndAdd(this.hitPoint, this.ray.o, this.ray.d, distance);
    const spacing = Math.max(0, this.gridSize);
    if (spacing > 0) {
      this.previewPosition.set(
        Math.round(this.hitPoint.x / spacing) * spacing,
        this.groundHeight,
        Math.round(this.hitPoint.z / spacing) * spacing
      );
    } else {
      this.previewPosition.set(this.hitPoint.x, this.groundHeight, this.hitPoint.z);
    }

    this.preview.setWorldPosition(this.previewPosition);
    this.preview.active = true;
    this.previewValid = true;
  }
}
