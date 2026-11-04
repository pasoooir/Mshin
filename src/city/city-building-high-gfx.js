import { cityTileToWorld, getBuildingVisualScale } from "./city-world-scale.js";
/**
 * High-graphics procedural buildings for Mshin city (SimCity BuildIt inspired style).
 * Vibrant palettes, multi-style roofs, rich facades, roof props, and readable silhouettes
 * from any orbit angle. Kept low-poly + instanced-friendly for mobile WebGL.
 */
export function createHighGfxBuilding(THREE, item, shared = {}) {
  const {
    trunkGeometry,
    canopyGeometry,
    canopySmallGeometry,
    brickSurface,
    concreteSurface,
    roofSurface,
    windowMaterials
  } = shared;

  const group = new THREE.Group();
  const x = cityTileToWorld(item.x);
  const z = cityTileToWorld(item.y);
  group.position.set(x, 0, z);
  const visualScale = getBuildingVisualScale(item.type);
  group.scale.set(visualScale.x, visualScale.y, visualScale.z);
  group.userData = { buildingId: item.id, type: item.type, level: item.level || 1 };

  const type = item.type;
  const level = Math.max(1, Math.min(5, item.level || 1));
  const seed = ((item.id || 1) * 2654435761) >>> 0;

  const rand = (() => {
    let s = seed;
    return () => {
      s = (Math.imul(s, 1664525) + 1013904223) >>> 0;
      return s / 4294967296;
    };
  })();

  const pick = (arr) => arr[Math.floor(rand() * arr.length) % arr.length];

  // ─── SimCity BuildIt inspired vibrant palettes ───────────────────────────
  const PALETTES = {
    home: [
      { wall:"#ff3fa4", side:"#a90075", roof:"#35106f", trim:"#fff36b", accent:"#00f5d4", door:"#5a164f" },
      { wall:"#ffb52e", side:"#e94a12", roof:"#174bd6", trim:"#fff8a6", accent:"#ff32c8", door:"#7b2512" },
      { wall:"#35e7ff", side:"#0875d1", roof:"#ff3b9d", trim:"#f7ff73", accent:"#a7ff32", door:"#103b8c" },
      { wall:"#b95cff", side:"#6420c8", roof:"#ffcf24", trim:"#fff4d0", accent:"#00f0c8", door:"#39106f" },
      { wall:"#8dff38", side:"#20a84c", roof:"#ff4b32", trim:"#fff77a", accent:"#ff38b8", door:"#14552b" }
    ],
    shop: [
      { wall:"#ffdb20", side:"#f05a00", roof:"#e90086", trim:"#fffca8", accent:"#00eaff", door:"#7b1457" },
      { wall:"#00e6d0", side:"#007fbd", roof:"#ff3c9f", trim:"#f4ff8a", accent:"#ffb52e", door:"#064b82" },
      { wall:"#ff5b35", side:"#bd164d", roof:"#6424db", trim:"#fff27a", accent:"#24f5ff", door:"#64102c" },
      { wall:"#b9ff24", side:"#299b37", roof:"#ff3c24", trim:"#ffffb0", accent:"#f52dba", door:"#15562b" }
    ],
    industrial: [
      { wall:"#ff9d16", side:"#c92d12", roof:"#3430c9", trim:"#fff15c", accent:"#00f2ff", door:"#7d1c14" },
      { wall:"#22e5d0", side:"#0875a8", roof:"#f51c83", trim:"#faff70", accent:"#ffb51f", door:"#073d70" },
      { wall:"#eaff22", side:"#79b900", roof:"#6424c9", trim:"#fff5a0", accent:"#ff4c24", door:"#315900" }
    ],
    administrative: [
      { wall:"#9d48ff", side:"#4a16b8", roof:"#ffcf20", trim:"#fff9a0", accent:"#00f4e4", door:"#321078" },
      { wall:"#ff4ba8", side:"#b80b75", roof:"#1c50dc", trim:"#fff68a", accent:"#a5ff28", door:"#671052" },
      { wall:"#22dfff", side:"#0876c9", roof:"#fa3296", trim:"#fff8a0", accent:"#ffb51f", door:"#10417b" }
    ],
    service: [
      { wall:"#20e5ff", side:"#0758b8", roof:"#ff3d9b", trim:"#fff77a", accent:"#a4ff25", door:"#103778" },
      { wall:"#ffbd27", side:"#ed4b10", roof:"#5625d8", trim:"#fff8a4", accent:"#00f2db", door:"#77250c" },
      { wall:"#a7ff2c", side:"#15984d", roof:"#f52e70", trim:"#ffff9c", accent:"#26dfff", door:"#15552b" }
    ],
    power: [
      { wall:"#ffe21d", side:"#e85b08", roof:"#bd168b", trim:"#fffba2", accent:"#00efff", door:"#77230a" },
      { wall:"#ff6a22", side:"#c51d39", roof:"#4820c9", trim:"#fff56a", accent:"#a9ff28", door:"#68112b" }
    ],
    water: [
      { wall:"#27eaff", side:"#0877d5", roof:"#4422cf", trim:"#f8ff8a", accent:"#00f4c8", door:"#103c8b" },
      { wall:"#20f4ce", side:"#087d9e", roof:"#ff3d9a", trim:"#fffaa0", accent:"#ffbd25", door:"#07516a" }
    ],
    sewage: [
      { wall:"#a8f52a", side:"#278d36", roof:"#5a20bd", trim:"#fff46b", accent:"#ff4b9c", door:"#205c24" },
      { wall:"#ffbd24", side:"#bd4b0c", roof:"#174ac8", trim:"#fffaa0", accent:"#00f0dc", door:"#6b2a0c" }
    ],
    waste: [
      { wall:"#d9ff20", side:"#72b900", roof:"#e92c78", trim:"#fff9a0", accent:"#00eaff", door:"#426600" },
      { wall:"#ff8c20", side:"#d73516", roof:"#5120c9", trim:"#fff36c", accent:"#23f3c5", door:"#76210d" }
    ],
    police: [
      { wall:"#28dfff", side:"#174fc5", roof:"#18266f", trim:"#fff77a", accent:"#ff3d91", door:"#102c78" },
      { wall:"#568bff", side:"#2536bb", roof:"#ffca22", trim:"#faff9b", accent:"#00f0e2", door:"#17266c" }
    ],
    fire: [
      { wall:"#ff4a24", side:"#bd1235", roof:"#5120bb", trim:"#fff36a", accent:"#ffcf1f", door:"#70101e" },
      { wall:"#ff8b20", side:"#e52b16", roof:"#2927a8", trim:"#fff89a", accent:"#00eaff", door:"#7a210b" }
    ],
    health: [
      { wall:"#ff58b5", side:"#bd247d", roof:"#4423c4", trim:"#fffaa0", accent:"#20f3dc", door:"#70124e" },
      { wall:"#fff02b", side:"#e85a20", roof:"#e82d91", trim:"#ffffff", accent:"#00dfff", door:"#76260e" }
    ],
    education: [
      { wall:"#a94dff", side:"#5120bf", roof:"#ffcf22", trim:"#fff99a", accent:"#00e8dd", door:"#321078" },
      { wall:"#ffb82b", side:"#e94c16", roof:"#1760d8", trim:"#fffaa0", accent:"#f72b9c", door:"#7a270d" }
    ]
  };

  const serviceTypes = new Set(["power", "water", "sewage", "waste", "police", "fire", "health", "education", "service"]);
  const paletteKey = serviceTypes.has(type) ? (PALETTES[type] ? type : "service") : type;
  const paletteList = PALETTES[paletteKey] || PALETTES.home;
  const palette = paletteList[(seed + level) % paletteList.length];

  function mat(color, opts = {}) {
    return new THREE.MeshStandardMaterial({
      color,
      roughness: opts.roughness ?? 0.70,
      metalness: opts.metalness ?? 0.02,
      emissive: opts.emissive ?? "#000000",
      emissiveIntensity: opts.emissiveIntensity ?? 0,
      transparent: opts.transparent ?? false,
      opacity: opts.opacity ?? 1,
      ...(opts.extra || {})
    });
  }

  function add(geometry, material, px, py, pz, ry = 0, cast = true) {
    const mesh = new THREE.Mesh(geometry, material);
    mesh.position.set(px, py, pz);
    mesh.rotation.y = ry;
    mesh.castShadow = cast;
    mesh.receiveShadow = true;
    group.add(mesh);
    return mesh;
  }

  function addGableRoof(w, d, ridgeH, roofMat, trimMat, baseY) {
    const geo = new THREE.BufferGeometry();
    const hw = w / 2, hd = d / 2;
    geo.setAttribute("position", new THREE.Float32BufferAttribute([
      -hw, 0, -hd,  0, ridgeH, -hd,  0, ridgeH,  hd,  -hw, 0,  hd,
       0, ridgeH, -hd,  hw, 0, -hd,  hw, 0,  hd,   0, ridgeH,  hd
    ], 3));
    geo.setIndex([0, 1, 2, 0, 2, 3, 4, 5, 6, 4, 6, 7]);
    geo.computeVertexNormals();
    const roof = new THREE.Mesh(geo, roofMat);
    roof.position.set(0, baseY, 0);
    roof.castShadow = true;
    roof.receiveShadow = true;
    group.add(roof);
    add(new THREE.BoxGeometry(0.08, 0.08, d + 0.06), trimMat, 0, baseY + ridgeH, 0, 0, false);
    add(new THREE.BoxGeometry(0.06, ridgeH * 0.92, d * 0.98), mat(palette.wall, { roughness: 0.88 }), -hw + 0.02, baseY + ridgeH * 0.46, 0, 0, false);
    add(new THREE.BoxGeometry(0.06, ridgeH * 0.92, d * 0.98), mat(palette.side, { roughness: 0.9 }), hw - 0.02, baseY + ridgeH * 0.46, 0, 0, false);
  }

  function addHipRoof(w, d, ridgeH, roofMat, baseY) {
    const geo = new THREE.BufferGeometry();
    const hw = w / 2, hd = d / 2;
    geo.setAttribute("position", new THREE.Float32BufferAttribute([
      -hw, 0, -hd,  hw, 0, -hd,  0, ridgeH, 0,
       hw, 0, -hd,  hw, 0,  hd,  0, ridgeH, 0,
       hw, 0,  hd, -hw, 0,  hd,  0, ridgeH, 0,
      -hw, 0,  hd, -hw, 0, -hd,  0, ridgeH, 0
    ], 3));
    geo.setIndex([0,1,2, 3,4,5, 6,7,8, 9,10,11]);
    geo.computeVertexNormals();
    const roof = new THREE.Mesh(geo, roofMat);
    roof.position.set(0, baseY, 0);
    roof.castShadow = true;
    roof.receiveShadow = true;
    group.add(roof);
  }

  function addFlatRoof(w, d, roofMat, trimMat, baseY, withParapet = true) {
    add(new THREE.BoxGeometry(w, 0.12, d), roofMat, 0, baseY + 0.06, 0, 0, true);
    if (withParapet) {
      const t = 0.07;
      add(new THREE.BoxGeometry(w + 0.08, 0.18, t), trimMat, 0, baseY + 0.18, d / 2, 0, false);
      add(new THREE.BoxGeometry(w + 0.08, 0.18, t), trimMat, 0, baseY + 0.18, -d / 2, 0, false);
      add(new THREE.BoxGeometry(t, 0.18, d), trimMat, w / 2, baseY + 0.18, 0, 0, false);
      add(new THREE.BoxGeometry(t, 0.18, d), trimMat, -w / 2, baseY + 0.18, 0, 0, false);
    }
  }

  function addWindows(bodyW, bodyD, height, glassMat, trimMat, floors, cols) {
    const winW = type === "home" ? 0.20 : 0.20;
    const winH = type === "home" ? 0.55 : 0.55;
    const winGeo = new THREE.BoxGeometry(winW, winH, 0.04);
    const frameGeo = new THREE.BoxGeometry(winW + 0.04, winH + 0.04, 0.03);
    const instances = floors * cols * 4;
    const windows = new THREE.InstancedMesh(winGeo, glassMat, instances);
    const frames = new THREE.InstancedMesh(frameGeo, trimMat, instances);
    const dummy = new THREE.Object3D();
    let idx = 0;
    const floorH = (height - 0.35) / Math.max(1, floors);
    for (let f = 0; f < floors; f++) {
      const y = 0.55 + f * floorH + floorH * 0.35;
      for (let c = 0; c < cols; c++) {
        const u = cols === 1 ? 0 : -bodyW * 0.36 + c * (bodyW * 0.72 / (cols - 1));
        for (const side of [1, -1]) {
          dummy.position.set(u, y, side * (bodyD / 2 + 0.025));
          dummy.rotation.set(0, side < 0 ? Math.PI : 0, 0);
          dummy.scale.set(1, 1, 1);
          dummy.updateMatrix();
          windows.setMatrixAt(idx, dummy.matrix);
          frames.setMatrixAt(idx, dummy.matrix);
          idx++;
        }
        for (const side of [1, -1]) {
          dummy.position.set(side * (bodyW / 2 + 0.025), y, u);
          dummy.rotation.set(0, side > 0 ? Math.PI / 2 : -Math.PI / 2, 0);
          dummy.scale.set(1, 1, 1);
          dummy.updateMatrix();
          windows.setMatrixAt(idx, dummy.matrix);
          frames.setMatrixAt(idx, dummy.matrix);
          idx++;
        }
      }
    }
    windows.count = idx;
    frames.count = idx;
    windows.instanceMatrix.needsUpdate = true;
    frames.instanceMatrix.needsUpdate = true;
    windows.castShadow = false;
    frames.castShadow = false;
    group.add(frames, windows);
  }

  function addDoor(bodyD, doorMat, trimMat) {
    add(new THREE.BoxGeometry(0.17, 0.96, 0.05), doorMat, 0, 0.50, bodyD / 2 + 0.03, 0, false);
    add(new THREE.BoxGeometry(0.21, 0.06, 0.04), trimMat, 0, 0.99, bodyD / 2 + 0.035, 0, false);
    add(new THREE.BoxGeometry(0.04, 0.04, 0.06), mat("#c0a060", { metalness: 0.4, roughness: 0.45 }), 0.07, 0.48, bodyD / 2 + 0.06, 0, false);
  }

  function addBalcony(bodyW, bodyD, y, trimMat, accentMat) {
    const plat = new THREE.BoxGeometry(0.55, 0.06, 0.32);
    const rail = new THREE.BoxGeometry(0.55, 0.05, 0.04);
    for (const face of [
      { x: 0, z: bodyD / 2 + 0.14, ry: 0 },
      { x: 0, z: -bodyD / 2 - 0.14, ry: Math.PI }
    ]) {
      add(plat, trimMat, face.x, y, face.z, face.ry, false);
      add(rail, accentMat, face.x, y + 0.12, face.z + (face.ry === 0 ? 0.14 : -0.14), face.ry, false);
    }
  }

  if (type === "park") {
    const lawn = mat("#39ed43", { roughness: 0.88, emissive: "#168d20", emissiveIntensity: 0.12 });
    add(new THREE.BoxGeometry(1.78, 0.18, 1.78), lawn, 0, 0.2, 0, 0, false);
    add(new THREE.BoxGeometry(0.28, 0.04, 1.5), mat("#ffe36a", { roughness: 0.78 }), 0.15, 0.3, 0, -0.25, false);
    if (trunkGeometry && canopyGeometry) {
      for (const [tx, tz] of [[-0.45, -0.35], [0.4, 0.3], [-0.2, 0.45]]) {
        const trunk = new THREE.Mesh(trunkGeometry, mat("#8b5b38", { roughness: 0.95 }));
        trunk.position.set(tx, 0.75, tz);
        trunk.scale.set(0.85, 0.9, 0.85);
        group.add(trunk);
        const crown = new THREE.Mesh(canopyGeometry, mat(pick(["#16e84a", "#42f52b", "#00c978", "#9bff24", "#00e8a8"]), { roughness: 1 }));
        crown.position.set(tx, 1.4, tz);
        group.add(crown);
        if (canopySmallGeometry) {
          const hi = new THREE.Mesh(canopySmallGeometry, mat("#b0ff38", { roughness: 0.86, emissive: "#38a51b", emissiveIntensity: 0.12 }));
          hi.position.set(tx - 0.15, 1.6, tz - 0.1);
          group.add(hi);
        }
      }
    }
    add(new THREE.BoxGeometry(0.5, 0.08, 0.16), mat("#a06a40", { roughness: 0.8 }), 0.35, 0.42, -0.45, 0.3, false);
    add(new THREE.BoxGeometry(0.08, 0.28, 0.08), mat("#8a5a30"), 0.18, 0.32, -0.45, 0, false);
    add(new THREE.BoxGeometry(0.08, 0.28, 0.08), mat("#8a5a30"), 0.52, 0.32, -0.45, 0, false);
    for (let i = 0; i < 5; i++) {
      const fx = -0.6 + rand() * 1.2;
      const fz = -0.55 + rand() * 0.4;
      add(new THREE.SphereGeometry(0.06, 6, 5), mat(pick(["#ff2f9b", "#ffe51f", "#a83dff", "#13dfff", "#ff6a18"])), fx, 0.38, fz, 0, false);
    }
    return group;
  }

  let height, bodyW, bodyD, floors, cols;
  if (type === "home") {
    height = 2.55 + level * 0.72;
    bodyW = 1.66;
    bodyD = 1.62;
    floors = Math.min(6, 2 + level);
    cols = 4;
  } else if (type === "shop") {
    height = 2.65 + level * 0.48;
    bodyW = 1.76;
    bodyD = 1.70;
    floors = Math.min(4, 2 + Math.floor(level / 2));
    cols = 4;
  } else if (type === "industrial") {
    height = 2.85 + level * 0.52;
    bodyW = 1.78;
    bodyD = 1.76;
    floors = 3 + Math.floor(level / 2);
    cols = 4;
  } else if (type === "administrative") {
    height = 3.0 + level * 0.62;
    bodyW = 1.72;
    bodyD = 1.68;
    floors = 3 + level;
    cols = 4;
  } else {
    // Civic and utility buildings use the same generous contemporary footprint.
    height = 2.65 + level * 0.45;
    bodyW = 1.68;
    bodyD = 1.62;
    floors = 3 + Math.floor(level / 2);
    cols = 4;
  }

  const facadeSurf = (type === "industrial" || type === "administrative") ? (concreteSurface || {}) : (brickSurface || {});
  const wall = new THREE.MeshStandardMaterial({
    ...facadeSurf,
    color: palette.wall,
    roughness: 0.70,
    normalScale: facadeSurf.normalMap ? new THREE.Vector2(0.35, 0.35) : undefined
  });
  const sideWall = new THREE.MeshStandardMaterial({
    ...facadeSurf,
    color: palette.side,
    roughness: 0.73,
    normalScale: facadeSurf.normalMap ? new THREE.Vector2(0.3, 0.3) : undefined
  });
  const roofMat = new THREE.MeshStandardMaterial({
    ...(roofSurface || {}),
    color: palette.roof,
    roughness: 0.68,
    normalScale: roofSurface?.normalMap ? new THREE.Vector2(0.45, 0.45) : undefined
  });
  const trimMat = mat(palette.trim, { roughness: 0.65 });
  const accentMat = mat(palette.accent, { roughness: 0.7 });
  const doorMat = mat(palette.door, { roughness: 0.75 });
  const glassMat = mat("#a8f8ff", {
    roughness: 0.12,
    metalness: 0.08,
    emissive: "#18cfff",
    emissiveIntensity: 0.42,
    transparent: true,
    opacity: 0.88
  });
  if (windowMaterials) windowMaterials.add(glassMat);

  add(new THREE.BoxGeometry(1.78, 0.18, 1.78), mat("#e8e0d0", { roughness: 0.95 }), 0, 0.2, 0, 0, false);

  const body = add(new THREE.BoxGeometry(bodyW, height, bodyD), wall, 0, 0.28 + height / 2, 0);
  body.material = [wall, sideWall, wall, wall, sideWall, sideWall];

  add(new THREE.BoxGeometry(bodyW + 0.12, 0.1, bodyD + 0.12), trimMat, 0, 0.28 + height, 0, 0, false);
  addDoor(bodyD, doorMat, trimMat);
  addWindows(bodyW, bodyD, height, glassMat, trimMat, floors, cols);

  const roofBaseY = 0.28 + height;

  if (type === "home") {
    if (seed % 3 === 0) {
      addHipRoof(bodyW + 0.32, bodyD + 0.32, 0.62 + level * 0.06, roofMat, roofBaseY);
    } else {
      addGableRoof(bodyW + 0.3, bodyD + 0.3, 0.7 + level * 0.08, roofMat, trimMat, roofBaseY);
    }
    const chimX = (seed % 2 === 0 ? 0.35 : -0.35);
    add(new THREE.BoxGeometry(0.18, 0.45, 0.18), mat("#8a7060"), chimX, roofBaseY + 0.85, -0.2);
    add(new THREE.BoxGeometry(0.22, 0.06, 0.22), trimMat, chimX, roofBaseY + 1.1, -0.2, 0, false);
    if (level >= 2) addBalcony(bodyW, bodyD, 0.55 + ((height - 0.35) / floors) * 1.1, trimMat, accentMat);
    if (level >= 3) addBalcony(bodyW, bodyD, 0.55 + ((height - 0.35) / floors) * 2.1, trimMat, accentMat);
    if (level >= 4) addBalcony(bodyW, bodyD, 0.55 + ((height - 0.35) / floors) * 3.1, trimMat, accentMat);
    add(new THREE.BoxGeometry(0.9, 0.08, 0.22), mat("#25e84b", { roughness: 0.82 }), 0, 0.32, bodyD / 2 + 0.28, 0, false);
    add(new THREE.BoxGeometry(0.5, 0.08, 0.22), mat("#d8d0c0"), 0, 0.3, bodyD / 2 + 0.18, 0, false);
  } else if (type === "shop") {
    addFlatRoof(bodyW + 0.2, bodyD + 0.2, roofMat, trimMat, roofBaseY, true);
    const awning = mat(palette.accent, { roughness: 0.75 });
    add(new THREE.BoxGeometry(bodyW * 0.95, 0.08, 0.55), awning, 0, 1.15, bodyD / 2 + 0.22, 0, false);
    for (let s = -2; s <= 2; s++) {
      add(new THREE.BoxGeometry(0.1, 0.09, 0.52), trimMat, s * 0.22, 1.15, bodyD / 2 + 0.22, 0, false);
    }
    add(new THREE.BoxGeometry(bodyW * 0.72, 0.7, 0.05), glassMat, 0, 0.85, bodyD / 2 + 0.04, 0, false);
    add(new THREE.BoxGeometry(bodyW * 0.7, 0.22, 0.08), accentMat, 0, 1.55, bodyD / 2 + 0.08, 0, false);
    add(new THREE.BoxGeometry(0.35, 0.22, 0.28), mat("#b0b8c0"), 0.35, roofBaseY + 0.28, -0.25);
    add(new THREE.CylinderGeometry(0.08, 0.08, 0.06, 8), mat("#9098a0"), 0.35, roofBaseY + 0.42, -0.25, 0, false);
  } else if (type === "industrial") {
    addFlatRoof(bodyW + 0.18, bodyD + 0.18, roofMat, trimMat, roofBaseY, true);
    add(new THREE.CylinderGeometry(0.12, 0.16, 1.35, 10), mat("#4a545c"), 0.5, roofBaseY + 0.7, -0.35);
    add(new THREE.CylinderGeometry(0.14, 0.14, 0.08, 10), mat("#6a747c"), 0.5, roofBaseY + 1.4, -0.35, 0, false);
    add(new THREE.CylinderGeometry(0.28, 0.28, 0.7, 12), mat("#8a9aa0"), -0.4, roofBaseY + 0.4, 0.25);
    add(new THREE.SphereGeometry(0.28, 10, 6, 0, Math.PI * 2, 0, Math.PI / 2), roofMat, -0.4, roofBaseY + 0.75, 0.25, 0, false);
    add(new THREE.BoxGeometry(0.7, 0.35, 0.25), mat("#6a7078"), 0, 0.45, bodyD / 2 + 0.12, 0, false);
  } else if (type === "administrative") {
    addFlatRoof(bodyW + 0.22, bodyD + 0.22, roofMat, trimMat, roofBaseY, true);
    for (const cx of [-0.42, -0.14, 0.14, 0.42]) {
      add(new THREE.CylinderGeometry(0.06, 0.07, height * 0.85, 8), trimMat, cx, 0.35 + height * 0.42, bodyD / 2 + 0.08);
    }
    add(new THREE.BoxGeometry(bodyW + 0.15, 0.18, 0.12), accentMat, 0, roofBaseY + 0.15, bodyD / 2 + 0.05, 0, false);
    add(new THREE.CylinderGeometry(0.025, 0.03, 1.1, 6), mat("#c0c0c0", { metalness: 0.5 }), 0.45, roofBaseY + 0.7, -0.3);
    add(new THREE.BoxGeometry(0.28, 0.16, 0.03), accentMat, 0.58, roofBaseY + 1.05, -0.3, 0, false);
  } else {
    addFlatRoof(bodyW + 0.18, bodyD + 0.18, roofMat, trimMat, roofBaseY, true);
    const roofY = roofBaseY + 0.2;
    if (type === "police") {
      add(new THREE.CylinderGeometry(0.1, 0.12, 0.18, 10), accentMat, 0, roofY + 0.1, 0);
      add(new THREE.SphereGeometry(0.12, 10, 8), mat("#e8f4ff", { emissive: "#4080ff", emissiveIntensity: 0.9 }), 0, roofY + 0.28, 0, 0, false);
      add(new THREE.CylinderGeometry(0.025, 0.03, 0.9, 6), trimMat, 0.4, roofY + 0.5, -0.3);
    } else if (type === "fire") {
      add(new THREE.BoxGeometry(0.32, 1.1, 0.32), accentMat, 0.4, roofY + 0.55, -0.3);
      add(new THREE.BoxGeometry(0.4, 0.1, 0.38), trimMat, 0.4, roofY + 1.15, -0.3, 0, false);
      add(new THREE.CylinderGeometry(0.05, 0.05, 0.7, 8), mat("#c0c0c0"), 0.4, roofY + 1.5, -0.3);
    } else if (type === "health") {
      add(new THREE.BoxGeometry(0.16, 0.7, 0.16), trimMat, 0, roofY + 0.4, 0, 0, false);
      add(new THREE.BoxGeometry(0.7, 0.16, 0.16), trimMat, 0, roofY + 0.4, 0, 0, false);
      add(new THREE.BoxGeometry(0.42, 0.08, 0.42), accentMat, 0, roofY + 0.05, 0, 0, false);
    } else if (type === "education") {
      add(new THREE.CylinderGeometry(0.26, 0.26, 0.12, 16), accentMat, 0, roofY + 0.15, 0);
      add(new THREE.BoxGeometry(0.03, 0.18, 0.03), trimMat, 0, roofY + 0.28, 0.06, 0, false);
      add(new THREE.CylinderGeometry(0.025, 0.03, 0.95, 6), trimMat, 0.4, roofY + 0.5, -0.3);
      add(new THREE.BoxGeometry(0.3, 0.18, 0.04), accentMat, 0.55, roofY + 0.8, -0.3, 0, false);
    } else if (type === "power") {
      for (const px of [-0.3, 0.3]) {
        add(new THREE.CylinderGeometry(0.07, 0.09, 0.4, 8), accentMat, px, roofY + 0.25, 0);
        add(new THREE.CylinderGeometry(0.11, 0.11, 0.07, 8), trimMat, px, roofY + 0.48, 0, 0, false);
      }
      add(new THREE.BoxGeometry(0.85, 0.06, 0.1), trimMat, 0, roofY + 0.55, 0, 0, false);
    } else if (type === "water") {
      add(new THREE.CylinderGeometry(0.32, 0.32, 0.55, 14), accentMat, 0, roofY + 0.3, 0);
      add(new THREE.SphereGeometry(0.32, 12, 7, 0, Math.PI * 2, 0, Math.PI / 2), trimMat, 0, roofY + 0.58, 0, 0, false);
      add(new THREE.CylinderGeometry(0.05, 0.05, 0.55, 8), mat("#60a0c0"), 0.38, roofY + 0.2, 0.3);
    } else if (type === "sewage") {
      for (const px of [-0.28, 0.28]) {
        add(new THREE.CylinderGeometry(0.1, 0.12, 0.5, 10), accentMat, px, roofY + 0.28, 0);
        add(new THREE.TorusGeometry(0.1, 0.03, 6, 12), trimMat, px, roofY + 0.55, 0, 0, false);
      }
    } else if (type === "waste") {
      for (const px of [-0.3, 0, 0.3]) {
        add(new THREE.BoxGeometry(0.2, 0.28, 0.22), accentMat, px, roofY + 0.18, 0);
        add(new THREE.BoxGeometry(0.22, 0.05, 0.24), trimMat, px, roofY + 0.34, 0, 0, false);
      }
    } else {
      add(new THREE.BoxGeometry(0.55, 0.35, 0.08), accentMat, 0, roofY + 0.2, bodyD / 2 + 0.05, 0, false);
    }
  }

  // Premium real-world inspired facade kit: full-height corner glazing,
  // deep horizontal floor bands, entrance canopy and rooftop equipment.
  if (type === "home" || type === "shop" || type === "administrative") {
    const bandY = 0.34 + height * 0.52;
    add(new THREE.BoxGeometry(bodyW + 0.10, 0.075, 0.075), trimMat, 0, bandY, bodyD / 2 + 0.035, 0, false);
    add(new THREE.BoxGeometry(0.075, height * 0.82, 0.075), accentMat, bodyW / 2 - 0.10, 0.36 + height * 0.43, bodyD / 2 + 0.04, 0, false);
    add(new THREE.BoxGeometry(0.075, height * 0.82, 0.075), accentMat, -bodyW / 2 + 0.10, 0.36 + height * 0.43, bodyD / 2 + 0.04, 0, false);
    // A broad, layered entrance canopy gives each building a deliberate street presence.
    add(new THREE.BoxGeometry(bodyW * 0.58, 0.10, 0.34), roofMat, 0, 1.12, bodyD / 2 + 0.20, 0, true);
    add(new THREE.BoxGeometry(bodyW * 0.58, 0.045, 0.36), trimMat, 0, 1.19, bodyD / 2 + 0.20, 0, false);
  }
  if (type === "home" && level >= 3) {
    // Modern villa roof terrace with a glass balustrade and rooftop garden.
    add(new THREE.BoxGeometry(bodyW * 0.76, 0.08, bodyD * 0.48), mat("#526b61", { roughness: 0.92 }), 0, roofBaseY + 0.16, 0, 0, false);
    add(new THREE.BoxGeometry(bodyW * 0.76, 0.045, 0.035), glassMat, 0, roofBaseY + 0.42, bodyD * 0.24, 0, false);
    add(new THREE.BoxGeometry(0.035, 0.045, bodyD * 0.48), glassMat, bodyW * 0.38, roofBaseY + 0.42, 0, 0, false);
    for (const gx of [-0.42, 0.42]) {
      add(new THREE.SphereGeometry(0.12, 8, 6), mat("#22ed63", { roughness: 0.82 }), gx, roofBaseY + 0.30, -0.30, 0, false);
    }
  }
  if (type === "shop") {
    // Wide, premium storefront glazing and a clean illuminated sign fascia.
    add(new THREE.BoxGeometry(bodyW * 0.78, 0.82, 0.045), glassMat, 0, 0.86, bodyD / 2 + 0.065, 0, false);
    add(new THREE.BoxGeometry(bodyW * 0.82, 0.10, 0.055), accentMat, 0, 1.48, bodyD / 2 + 0.09, 0, false);
  }
  add(new THREE.BoxGeometry(0.05, height * 0.75, 0.06), accentMat, -bodyW / 2 - 0.01, 0.35 + height * 0.45, bodyD / 2 + 0.02, 0, false);

  return group;
}
