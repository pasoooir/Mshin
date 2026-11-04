/** Procedural construction-site visuals shared by the city Three.js renderer. */
export function createCityConstructionRenderer(THREE, buildings) {
  function createConstructionSite(item) {
    const group = new THREE.Group();
    group.position.set((item.x - 15.5) * 2, 0, (item.y - 15.5) * 2);
    group.userData.constructionSite = true;
    group.userData.sourceItem = item;
    const ground = new THREE.Mesh(new THREE.BoxGeometry(1.9, 0.16, 1.9), new THREE.MeshStandardMaterial({ color: "#b88c55", roughness: 1 }));
    ground.position.y = 0.16; ground.receiveShadow = true; group.add(ground);
    const safety = new THREE.MeshStandardMaterial({ color: "#f1b84f", roughness: 0.82 });
    const dark = new THREE.MeshStandardMaterial({ color: "#384a50", roughness: 0.9 });
    const wood = new THREE.MeshStandardMaterial({ color: "#9b7047", roughness: 0.95 });
    for (let i = 0; i < 4; i++) {
      const x = i % 2 ? 0.84 : -0.84, z = i > 1 ? 0.84 : -0.84;
      const post = new THREE.Mesh(new THREE.BoxGeometry(0.075, 0.82, 0.075), safety);
      post.position.set(x, 0.58, z); group.add(post);
    }
    for (const z of [-0.84, 0.84]) {
      const rail = new THREE.Mesh(new THREE.BoxGeometry(1.75, 0.075, 0.075), safety);
      rail.position.set(0, 0.48, z); group.add(rail);
    }
    const workers = [];
    for (let i = 0; i < 3; i++) {
      const worker = new THREE.Group();
      worker.position.set(-0.52 + i * 0.52, 0.25, i === 1 ? -0.18 : 0.24);
      const shirt = new THREE.MeshStandardMaterial({ color: ["#e87945", "#328e91", "#e0b447"][i], roughness: 0.85 });
      const body = new THREE.Mesh(new THREE.CylinderGeometry(0.13, 0.17, 0.42, 7), shirt);
      body.position.y = 0.42; worker.add(body);
      const head = new THREE.Mesh(new THREE.SphereGeometry(0.115, 8, 7), new THREE.MeshStandardMaterial({ color: "#d8a47e", roughness: 0.9 }));
      head.position.y = 0.72; worker.add(head);
      const helmet = new THREE.Mesh(new THREE.SphereGeometry(0.13, 8, 5, 0, Math.PI * 2, 0, Math.PI * 0.52), safety);
      helmet.position.y = 0.78; worker.add(helmet);
      const armPivot = new THREE.Group(); armPivot.position.set(0.1, 0.57, 0.02);
      const arm = new THREE.Mesh(new THREE.CylinderGeometry(0.045, 0.05, 0.34, 6), shirt);
      arm.position.y = -0.13; arm.rotation.z = -0.3; armPivot.add(arm);
      const handle = new THREE.Mesh(new THREE.CylinderGeometry(0.018, 0.022, 0.62, 5), wood);
      handle.position.set(0.04, -0.34, 0.02); handle.rotation.z = -0.28; armPivot.add(handle);
      if (i === 1) {
        const pickHead = new THREE.Mesh(new THREE.BoxGeometry(0.38, 0.075, 0.07), dark);
        pickHead.position.set(0.12, -0.62, 0.02);
        pickHead.rotation.z = -0.12;
        armPivot.add(pickHead);
      } else {
        const blade = new THREE.Mesh(new THREE.BoxGeometry(0.17, 0.12, 0.045), dark);
        blade.position.set(0.12, -0.62, 0.02);
        armPivot.add(blade);
      }
      worker.add(armPivot);
      const legs = new THREE.Mesh(new THREE.BoxGeometry(0.24, 0.22, 0.16), dark);
      legs.position.y = 0.1; worker.add(legs);
      worker.userData.armPivot = armPivot;
      worker.userData.phase = i * 2.1;
      workers.push(worker); group.add(worker);
    }
    const labelCanvas = document.createElement("canvas");
    labelCanvas.width = 256; labelCanvas.height = 80;
    const labelContext = labelCanvas.getContext("2d");
    const labelTexture = new THREE.CanvasTexture(labelCanvas);
    labelTexture.colorSpace = THREE.SRGBColorSpace;
    const label = new THREE.Sprite(new THREE.SpriteMaterial({ map: labelTexture, transparent: true, depthTest: false }));
    label.position.set(0, 2.15, 0); label.scale.set(2.25, 0.7, 1); label.renderOrder = 20;
    group.add(label);
    group.userData.workers = workers;
    group.userData.labelContext = labelContext;
    group.userData.labelTexture = labelTexture;
    group.userData.labelCanvas = labelCanvas;
    group.userData.lastSeconds = -1;
    return group;
  }

  function updateConstructionAnimations() {
    const now = performance.now() / 1000;
    for (const site of buildings.children) {
      if (!site.userData.constructionSite) continue;
      const item = site.userData.sourceItem;
      const remaining = Math.max(0, Math.ceil(item?.construction?.remaining || 0));
      if (remaining !== site.userData.lastSeconds) {
        const context = site.userData.labelContext;
        context.clearRect(0, 0, 256, 80);
        context.fillStyle = "#102638";
        context.beginPath(); context.roundRect(5, 5, 246, 70, 16); context.fill();
        context.strokeStyle = "#f4c765"; context.lineWidth = 5; context.stroke();
        context.fillStyle = "#fff0c4"; context.font = "bold 30px system-ui"; context.textAlign = "center"; context.textBaseline = "middle";
        context.fillText("⏱ " + remaining + "s", 128, 42);
        site.userData.labelTexture.needsUpdate = true;
        site.userData.lastSeconds = remaining;
      }
      for (const worker of site.userData.workers) {
        const phase = now * 3.2 + worker.userData.phase;
        worker.userData.armPivot.rotation.z = Math.sin(phase) * 0.82 - 0.25;
        worker.position.y = 0.25 + Math.max(0, Math.sin(phase * 2)) * 0.035;
      }
    }
  }

  function disposeSite(site) {
    site?.userData?.labelTexture?.dispose?.();
  }

  return { createSite: createConstructionSite, update: updateConstructionAnimations, disposeSite };
}
