import { _decorator, Component, Graphics, Color } from "cc";
import { VehicleController } from "./VehicleController";
const { ccclass } = _decorator;

/** Lightweight local body deformation cues and impact smoke for the Cocos vehicle. */
@ccclass("MshinVehicleDamageRenderer")
export class VehicleDamageRenderer extends Component {
  private controller: VehicleController | null = null;
  private graphics: Graphics | null = null;
  private elapsed = 0;

  bind(controller: VehicleController): void {
    this.controller = controller;
    this.graphics = this.getComponent(Graphics) ?? this.addComponent(Graphics);
  }

  update(dt: number): void {
    if (!this.controller || !this.graphics) return;
    const g = this.graphics;
    const damage = this.controller.damage;
    g.clear();
    if (damage.total < 8) return;

    const level = damage.total >= 82 ? 4 : damage.total >= 58 ? 3 : damage.total >= 30 ? 2 : 1;
    const alpha = Math.min(210, 55 + damage.total * 1.35);
    // Creases are drawn over the affected quarter, in the car's local coordinate space.
    g.lineWidth = 2 + level * .65;
    g.strokeColor = new Color(35, 25, 24, alpha);
    if (damage.front > 3) {
      g.moveTo(-13, 25); g.lineTo(-7, 30 - level); g.lineTo(1, 26); g.stroke();
      g.moveTo(5, 31); g.lineTo(12, 24 - level); g.stroke();
    }
    if (damage.rear > 3) {
      g.moveTo(-12, -27); g.lineTo(-5, -32 + level); g.lineTo(5, -28); g.stroke();
    }
    if (damage.left > 3) {
      g.moveTo(-14, -12); g.lineTo(-10 + level, -5); g.lineTo(-15, 5); g.stroke();
    }
    if (damage.right > 3) {
      g.moveTo(14, -12); g.lineTo(10 - level, -4); g.lineTo(15, 7); g.stroke();
    }
    if (damage.engine > 12) {
      this.elapsed += Math.max(0, Math.min(dt, .05));
      const pulse = .5 + .5 * Math.sin(this.elapsed * 7);
      const smokeAlpha = Math.min(150, 25 + damage.engine * .9) * pulse;
      g.fillColor = new Color(75, 82, 88, smokeAlpha);
      const drift = Math.sin(this.elapsed * 2.1) * 5;
      g.circle(drift, -43 - pulse * 7, 4 + level * 1.7); g.fill();
      if (level >= 3) {
        g.fillColor = new Color(105, 108, 112, smokeAlpha * .65);
        g.circle(-5 + drift, -52 - pulse * 9, 3 + level); g.fill();
      }
    }
    if (damage.disabled) {
      g.fillColor = new Color(255, 90, 35, 125);
      g.circle(0, 0, 5 + Math.sin(this.elapsed * 10) * 1.5); g.fill();
    }
  }
}
