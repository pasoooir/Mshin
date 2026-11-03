import { _decorator, Camera, Component, EventTouch, geometry, Input, instantiate, input, Node, Prefab, Vec3 } from "cc";
import { CityBuildingProgression } from "./CityBuildingProgression";
import {
  intersectCityPlacementGround,
  snapCityPlacementPoint
} from "../../src/city/core/placement-geometry.js";

const { ccclass, property } = _decorator;

/**
 * Single-pointer touch placement controller for the native city scene.
 * Assign a camera, a building prefab and a world-space placement root.
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
  private readonly previewPosition = new Vec3();
  private placementArmed = false;
  private previewValid = false;
  private activeTouchId: number | null = null;

  onEnable(): void {
    input.on(Input.EventType.TOUCH_START, this.onTouchStart, this);
    input.on(Input.EventType.TOUCH_MOVE, this.onTouchMove, this);
    input.on(Input.EventType.TOUCH_END, this.onTouchEnd, this);
    input.on(Input.EventType.TOUCH_CANCEL, this.onTouchCancel, this);
  }

  onDisable(): void {
    input.off(Input.EventType.TOUCH_START, this.onTouchStart, this);
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
    this.activeTouchId = null;
    if (this.preview && this.preview.isValid) this.preview.destroy();
    this.preview = null;
  }

  private onTouchStart(event: EventTouch): void {
    if (this.placementArmed && this.activeTouchId === null) {
      this.activeTouchId = event.getID();
    }
  }

  private onTouchMove(event: EventTouch): void {
    if (this.placementArmed && this.activeTouchId === event.getID()) this.updatePreview(event);
  }

  private onTouchEnd(event: EventTouch): void {
    if (!this.placementArmed || this.activeTouchId !== event.getID()) return;
    this.updatePreview(event);
    this.activeTouchId = null;
    if (!this.previewValid || !this.preview || !this.preview.isValid || !this.placementRoot || !this.buildingPrefab) return;

    const building = instantiate(this.buildingPrefab);
    building.name = this.buildingPrefab.name;
    building.setParent(this.placementRoot);
    building.setWorldPosition(this.previewPosition);
    const progression = building.addComponent(CityBuildingProgression);
    progression.beginConstruction(this.constructionDuration);
    this.cancelPlacement();
  }

  private onTouchCancel(event: EventTouch): void {
    if (this.activeTouchId !== event.getID()) return;
    this.activeTouchId = null;
    this.previewValid = false;
    if (this.preview && this.preview.isValid) this.preview.active = false;
  }


  private isOccupied(position: Vec3): boolean {
    if (!this.placementRoot || !this.placementRoot.isValid) return true;
    const occupants = this.placementRoot.children
      .filter(child => child !== this.preview && child.isValid && child.active && child.getComponent(CityBuildingProgression))
      .map(child => ({ x: child.worldPosition.x, z: child.worldPosition.z }));
    const tolerance = Number.isFinite(this.occupancyTolerance) ? Math.max(0.01, this.occupancyTolerance) : 0.35;
    return isCityPlacementOccupied({
      x: position.x,
      y: position.y,
      z: position.z
    }, occupants, this.gridSize, tolerance);
  }

  private updatePreview(event: EventTouch): void {
    if (!this.cityCamera || !this.cityCamera.isValid || !this.preview || !this.preview.isValid) return;
    const location = event.getLocation();
    this.cityCamera.screenPointToRay(this.ray, location.x, location.y);
    const intersection = intersectCityPlacementGround({
      origin: { x: this.ray.o.x, y: this.ray.o.y, z: this.ray.o.z },
      direction: { x: this.ray.d.x, y: this.ray.d.y, z: this.ray.d.z }
    }, this.groundHeight, this.maxPlacementDistance);
    if (!intersection) {
      this.previewValid = false;
      this.preview.active = false;
      return;
    }

    const snapped = snapCityPlacementPoint(intersection, this.gridSize);
    if (!snapped) {
      this.previewValid = false;
      this.preview.active = false;
      return;
    }
    this.previewPosition.set(snapped.x, snapped.y, snapped.z);
    this.preview.setWorldPosition(this.previewPosition);
    this.preview.active = true;
    this.previewValid = true;
  }
}
