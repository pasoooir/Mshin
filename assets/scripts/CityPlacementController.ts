import { _decorator, Camera, Component, EventTouch, geometry, Input, instantiate, input, Node, Prefab, Vec3 } from "cc";
import { CityBuildingProgression } from "./CityBuildingProgression";
import { CityOrbitCamera } from "./CityOrbitCamera";

const { ccclass, property } = _decorator;

@ccclass("MshinCityPlacementController")
export class CityPlacementController extends Component {
  @property({ type: Camera }) cityCamera: Camera | null = null;
  @property({ type: Prefab }) buildingPrefab: Prefab | null = null;
  @property({ type: Node }) placementRoot: Node | null = null;
  @property({ type: CityOrbitCamera }) orbitCamera: CityOrbitCamera | null = null;
  @property groundHeight = 0;
  @property gridSize = 1;
  @property maxPlacementDistance = 180;
  @property constructionDuration = 30;
  @property occupancyTolerance = 0.35;

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

  beginPlacement(): boolean {
    if (!this.cityCamera?.isValid || !this.buildingPrefab || !this.placementRoot?.isValid) return false;
    this.cancelPlacement();
    this.preview = instantiate(this.buildingPrefab);
    this.preview.name = this.buildingPrefab.name + " Preview";
    this.preview.setParent(this.placementRoot);
    this.preview.setScale(0.92, 0.92, 0.92);
    this.placementArmed = true;
    this.previewValid = false;
    this.orbitCamera?.setPlacementMode(true);
    return true;
  }

  cancelPlacement(): void {
    this.placementArmed = false;
    this.previewValid = false;
    if (this.preview?.isValid) this.preview.destroy();
    this.preview = null;
    this.orbitCamera?.setPlacementMode(false);
  }

  private onTouchMove(event: EventTouch): void {
    if (this.placementArmed) this.updatePreview(event);
  }

  private onTouchEnd(event: EventTouch): void {
    if (!this.placementArmed) return;
    this.updatePreview(event);
    if (!this.previewValid || !this.preview?.isValid || !this.placementRoot?.isValid) return;
    if (this.isOccupied(this.previewPosition)) {
      this.invalidatePreview();
      return;
    }
    const building = instantiate(this.buildingPrefab!);
    building.name = this.buildingPrefab!.name;
    building.setParent(this.placementRoot);
    building.setWorldPosition(this.previewPosition);
    building.addComponent(CityBuildingProgression).beginConstruction(this.constructionDuration);
    this.cancelPlacement();
  }

  private onTouchCancel(): void {
    this.invalidatePreview();
  }

  private isOccupied(position: Vec3): boolean {
    if (!this.placementRoot?.isValid) return true;
    const tolerance = Math.max(0.01, this.occupancyTolerance);
    const spacing = Math.max(0, this.gridSize);
    for (const child of this.placementRoot.children) {
      if (child === this.preview || !child.isValid || !child.active) continue;
      // Only placed buildings reserve a cell; roads, trees, lamps and scenery do not.
      if (!child.getComponent(CityBuildingProgression)) continue;
      const occupied = child.worldPosition;
      if (spacing > 0) {
        if (Math.round(occupied.x / spacing) === Math.round(position.x / spacing)
          && Math.round(occupied.z / spacing) === Math.round(position.z / spacing)) return true;
      } else if (Math.hypot(occupied.x - position.x, occupied.z - position.z) < tolerance) return true;
    }
    return false;
  }

  private updatePreview(event: EventTouch): void {
    if (!this.cityCamera?.isValid || !this.preview?.isValid) return;
    const location = event.getLocation();
    this.cityCamera.screenPointToRay(this.ray, location.x, location.y);
    const directionY = this.ray.d.y;
    if (Math.abs(directionY) < 0.0001) return this.invalidatePreview();
    const distance = (this.groundHeight - this.ray.o.y) / directionY;
    if (distance < 0 || distance > this.maxPlacementDistance) return this.invalidatePreview();
    Vec3.scaleAndAdd(this.hitPoint, this.ray.o, this.ray.d, distance);
    const spacing = Math.max(0, this.gridSize);
    this.previewPosition.set(
      spacing > 0 ? Math.round(this.hitPoint.x / spacing) * spacing : this.hitPoint.x,
      this.groundHeight,
      spacing > 0 ? Math.round(this.hitPoint.z / spacing) * spacing : this.hitPoint.z
    );
    this.preview.setWorldPosition(this.previewPosition);
    this.preview.active = true;
    this.previewValid = !this.isOccupied(this.previewPosition);
  }

  private invalidatePreview(): void {
    this.previewValid = false;
    if (this.preview?.isValid) this.preview.active = false;
  }
}
