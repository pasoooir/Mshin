import { cityTileToWorld } from "./city-world-scale.js";

/**
 * Lightweight staged construction visuals for the mobile city renderer.
 * Stages: site preparation, foundations, structural frame, crane lifts,
 * facade/finishing. The final building mesh is intentionally hidden until
 * the simulation removes item.construction.
 */
export function createCityConstructionRenderer(THREE, parent) {
  const shared = {
    ground: new THREE.MeshStandardMaterial({ color: "#a98255", roughness: 1 }),
    concrete: new THREE.MeshStandardMaterial({ color: "#aeb8b7", roughness: 0.94 }),
    steel: new THREE.MeshStandardMaterial({ color: "#657985", metalness: 0.72, roughness: 0.38 }),
    safety: new THREE.MeshStandardMaterial({ color: "#f0b83e", roughness: 0.82 }),
    dark: new THREE.MeshStandardMaterial({ color: "#344650", roughness: 0.88 }),
    timber: new THREE.MeshStandardMaterial({ color: "#9a7047", roughness: 0.9 }),
    glass: new THREE.MeshStandardMaterial({ color: "#91cbd0", transparent: true, opacity: 0.48, roughness: 0.25 })
  };

  const box = (group, w, h, d, material, x, y, z, cast = true) => {
    const mesh = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), material);
    mesh.position.set(x, y, z);
    mesh.castShadow = cast;
    mesh.receiveShadow = true;
    group.add(mesh);
    return mesh;
  };

  function makeWorker(site, index) {
    const worker = new THREE.Group();
    worker.position.set(-0.62 + index * 0.62, 0.12, index === 1 ? -0.32 : 0.38);
    const shirt = new THREE.MeshStandardMaterial({
      color: ["#e87945", "#328e91", "#e0b447"][index],
      roughness: 0.86
    });
    const body = new THREE.Mesh(new THREE.CylinderGeometry(0.13, 0.17, 0.4, 7), shirt);
    body.position.y = 0.43;
    worker.add(body);
    const head = new THREE.Mesh(new THREE.SphereGeometry(0.105, 8, 7), shared.ground);
    head.position.y = 0.72;
    worker.add(head);
    const helmet = new THREE.Mesh(new THREE.SphereGeometry(0.13, 8, 5, 0, Math.PI * 2, 0, Math.PI * 0.52), shared.safety);
    helmet.position.y = 0.78;
    worker.add(helmet);
    const armPivot = new THREE.Group();
    armPivot.position.set(0.1, 0.57, 0);
    const arm = new THREE.Mesh(new THREE.CylinderGeometry(0.045, 0.05, 0.32, 6), shirt);
    arm.position.y = -0.14;
    armPivot.add(arm);
    const handle = new THREE.Mesh(new THREE.CylinderGeometry(0.018, 0.022, 0.58, 5), shared.timber);
    handle.position.set(0.06, -0.35, 0);
    handle.rotation.z = -0.22;
    armPivot.add(handle);
    const tool = new THREE.Mesh(new THREE.BoxGeometry(0.16, 0.11, 0.045), shared.dark);
    tool.position.set(0.13, -0.62, 0);
    armPivot.add(tool);
    worker.add(armPivot);
    const legs = new THREE.Group();
    for (const side of [-1, 1]) {
      const leg = new THREE.Mesh(new THREE.BoxGeometry(0.09, 0.24, 0.11), shared.dark);
      leg.position.set(side * 0.07, 0.11, 0);
      legs.add(leg);
    }
    worker.add(legs);
    worker.userData = { armPivot, legs, phase: index * 2.05, shirt };
    site.add(worker);
    return worker;
  }

  function makeCrane(site) {
    const crane = new THREE.Group();
    crane.position.set(0.7, 0, -0.68);
    const mast = box(crane, 0.13, 3.7, 0.13, shared.safety, 0, 1.85, 0);
    mast.material = shared.steel;
    box(crane, 0.22, 0.18, 0.22, shared.dark, 0, 3.72, 0);
    const boom = new THREE.Group();
    boom.position.set(0, 3.7, 0);
    box(boom, 2.55, 0.12, 0.12, shared.safety, 0.9, 0, 0);
    box(boom, 0.72, 0.12, 0.12, shared.steel, -0.38, 0, 0);
    box(boom, 0.1, 0.32, 0.1, shared.dark, -0.62, -0.18, 0);
    const cable = new THREE.Group();
    cable.position.set(1.55, -0.08, 0);
    const wire = new THREE.Mesh(new THREE.CylinderGeometry(0.012, 0.012, 0.85, 5), shared.dark);
    wire.position.y = -0.42;
    cable.add(wire);
    const hook = box(cable, 0.18, 0.12, 0.16, shared.safety, 0, -0.88, 0);
    hook.castShadow = false;
    boom.add(cable);
    crane.add(boom);
    site.add(crane);
    return { crane, boom, cable };
  }

  function createSite(item) {
    const group = new THREE.Group();
    group.position.set(cityTileToWorld(item.x), 0, cityTileToWorld(item.y));
    group.userData.constructionSite = true;
    group.userData.sourceItem = item;
    const width = Math.max(1.8, Number(item.footprint?.width) || 2.15);
    const depth = Math.max(1.8, Number(item.footprint?.depth) || 2.15);
    box(group, width, 0.12, depth, shared.ground, 0, 0.08, 0, false);

    const fenceMaterial = shared.safety;
    const fenceHeight = 0.72;
    for (const x of [-width / 2, width / 2]) {
      for (const z of [-depth / 2, depth / 2]) box(group, 0.07, fenceHeight, 0.07, fenceMaterial, x, fenceHeight / 2, z, false);
    }
    for (const z of [-depth / 2, depth / 2]) box(group, width, 0.065, 0.065, fenceMaterial, 0, 0.48, z, false);
    for (const x of [-width / 2, width / 2]) box(group, 0.065, 0.065, depth, fenceMaterial, x, 0.48, 0, false);

    const foundation = new THREE.Group();
    box(foundation, width * 0.78, 0.28, depth * 0.78, shared.concrete, 0, 0.23, 0);
    group.add(foundation);

    const frame = new THREE.Group();
    const floorCount = Math.max(2, Math.min(8, Math.ceil((Number(item.heightMeters) || 12) / 4)));
    const floorHeight = 0.62;
    for (let floor = 0; floor < floorCount; floor++) {
      const y = 0.42 + floor * floorHeight;
      for (const x of [-width * 0.34, width * 0.34]) {
        for (const z of [-depth * 0.34, depth * 0.34]) box(frame, 0.09, floorHeight, 0.09, shared.steel, x, y + floorHeight / 2, z);
      }
      box(frame, width * 0.72, 0.07, 0.07, shared.steel, 0, y + floorHeight, -depth * 0.34);
      box(frame, width * 0.72, 0.07, 0.07, shared.steel, 0, y + floorHeight, depth * 0.34);
      box(frame, 0.07, 0.07, depth * 0.72, shared.steel, -width * 0.34, y + floorHeight, 0);
      box(frame, 0.07, 0.07, depth * 0.72, shared.steel, width * 0.34, y + floorHeight, 0);
    }
    group.add(frame);

    const facade = new THREE.Group();
    const facadePanel = new THREE.Mesh(new THREE.BoxGeometry(width * 0.68, floorCount * floorHeight, depth * 0.68), shared.glass);
    facadePanel.position.y = 0.42 + floorCount * floorHeight / 2;
    facade.add(facadePanel);
    group.add(facade);

    const workers = [0, 1, 2].map(index => makeWorker(group, index));
    const crane = makeCrane(group);

    const labelCanvas = document.createElement("canvas");
    labelCanvas.width = 512;
    labelCanvas.height = 112;
    const labelContext = labelCanvas.getContext("2d");
    const labelTexture = new THREE.CanvasTexture(labelCanvas);
    labelTexture.colorSpace = THREE.SRGBColorSpace;
    const label = new THREE.Sprite(new THREE.SpriteMaterial({ map: labelTexture, transparent: true, depthTest: false }));
    label.position.set(0, Math.max(3.1, floorCount * floorHeight + 2.1), 0);
    label.scale.set(3.8, 0.84, 1);
    label.renderOrder = 30;
    group.add(label);

    group.userData = {
      ...group.userData,
      workers, crane, foundation, frame, facade,
      labelContext, labelTexture, labelCanvas, label,
      lastLabel: "",
      phaseObjects: { foundation, frame, facade }
    };
    parent.add(group);
    return group;
  }

  function update() {
    const now = performance.now() / 1000;
    for (const site of parent.children) {
      if (!site.userData?.constructionSite) continue;
      const item = site.userData.sourceItem;
      const construction = item?.construction || {};
      const duration = Math.max(1, Number(construction.duration) || 45);
      const remaining = Math.max(0, Math.min(duration, Number(construction.remaining) || 0));
      const progress = Math.max(0, Math.min(1, 1 - remaining / duration));
      const stage = progress < 0.15 ? 0 : progress < 0.35 ? 1 : progress < 0.62 ? 2 : progress < 0.84 ? 3 : 4;
      const labels = ["آماده‌سازی زمین", "فونداسیون و بتن‌ریزی", "اسکلت و ستون‌ها", "جرثقیل و نصب طبقات", "نماکاری و تکمیل"];
      const { foundation, frame, facade, crane, workers, labelContext, labelTexture, lastLabel } = site.userData;
      foundation.visible = progress >= 0.15;
      frame.visible = progress >= 0.35;
      facade.visible = progress >= 0.84;
      crane.crane.visible = progress >= 0.35 && progress < 0.98;
      crane.boom.rotation.y = Math.sin(now * 0.24) * 0.7;
      crane.cable.position.y = -0.08 - (0.25 + (Math.sin(now * 1.15) + 1) * 0.5) * 0.85;
      frame.scale.y = Math.max(0.025, Math.min(1, (progress - 0.28) / 0.48));
      facade.scale.y = Math.max(0.025, Math.min(1, (progress - 0.78) / 0.22));
      for (const worker of workers) {
        const phase = now * (stage === 3 ? 1.8 : 3.1) + worker.userData.phase;
        worker.userData.armPivot.rotation.z = stage === 3 ? Math.sin(phase) * 0.28 : Math.sin(phase) * 0.82 - 0.25;
        worker.userData.legs.rotation.x = Math.sin(phase * 0.6) * (stage === 0 ? 0.16 : 0.06);
        worker.position.y = 0.12 + Math.max(0, Math.sin(phase * 2)) * 0.025;
      }
      const seconds = Math.ceil(remaining);
      const labelText = seconds + "|" + stage;
      if (labelText !== lastLabel) {
        labelContext.clearRect(0, 0, 512, 112);
        labelContext.fillStyle = "#102638";
        labelContext.beginPath();
        labelContext.roundRect(5, 5, 502, 102, 20);
        labelContext.fill();
        labelContext.strokeStyle = "#f4c765";
        labelContext.lineWidth = 5;
        labelContext.stroke();
        labelContext.fillStyle = "#fff0c4";
        labelContext.textAlign = "center";
        labelContext.textBaseline = "middle";
        labelContext.font = "bold 25px system-ui";
        labelContext.fillText(labels[stage], 256, 37);
        labelContext.font = "bold 31px system-ui";
        labelContext.fillText("⏱ " + seconds + "s", 256, 78);
        labelTexture.needsUpdate = true;
        site.userData.lastLabel = labelText;
      }
    }
  }

  function dispose() {
    for (const site of [...parent.children]) {
      if (!site.userData?.constructionSite) continue;
      parent.remove(site);
      site.traverse(object => {
        object.geometry?.dispose?.();
        if (object.material && !Object.values(shared).includes(object.material)) {
          if (Array.isArray(object.material)) object.material.forEach(material => material.dispose?.());
          else object.material.dispose?.();
        }
      });
      site.userData.labelTexture?.dispose?.();
    }
    Object.values(shared).forEach(material => material.dispose());
  }

  return { createSite, update, dispose };
}
