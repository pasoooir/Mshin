/** Controlled, material-aware building color families; values are sRGB hex colors. */
export const CITY_ARCHITECTURAL_PALETTES = {
    home: [
      { wall:"#e2bd83", side:"#bd895b", roof:"#79503d", trim:"#fff0cb", accent:"#71806b", door:"#654b38" },
      { wall:"#d5a66f", side:"#a77c58", roof:"#59443b", trim:"#f5dfb7", accent:"#7d8c91", door:"#594638" },
      { wall:"#efce91", side:"#c49a69", roof:"#855c43", trim:"#fff1d5", accent:"#8b795f", door:"#76543e" },
      { wall:"#b9b5a7", side:"#898b82", roof:"#555b5b", trim:"#dedbd0", accent:"#718078", door:"#4d514c" },
      { wall:"#c9a994", side:"#9d7867", roof:"#5c514d", trim:"#ead7c7", accent:"#7e8270", door:"#684b3c" },
      { wall:"#d5d0c4", side:"#a9a79d", roof:"#6a6b68", trim:"#f0ede4", accent:"#7e918f", door:"#65584b" }
    ],
    shop: [
      { wall:"#e6b879", side:"#b17d50", roof:"#52616a", trim:"#fff0d0", accent:"#667f83", door:"#4e4c45" },
      { wall:"#b9c1bd", side:"#899894", roof:"#4e5b60", trim:"#e2e7df", accent:"#8a735e", door:"#48575a" },
      { wall:"#edc48a", side:"#b7895c", roof:"#775541", trim:"#fff0d4", accent:"#8c765f", door:"#5d493b" },
      { wall:"#b6b2a6", side:"#87877d", roof:"#555754", trim:"#e0ddd2", accent:"#687d72", door:"#4e514b" }
    ],
    industrial: [
      { wall:"#aeb5b2", side:"#7f8987", roof:"#4e5658", trim:"#d8ddda", accent:"#8c795f", door:"#4b5555" },
      { wall:"#c0b8a7", side:"#918a7c", roof:"#5a5d5b", trim:"#e3ddd0", accent:"#73827e", door:"#55534b" },
      { wall:"#a9ada8", side:"#7c8581", roof:"#4a5252", trim:"#d5d8d1", accent:"#9a805e", door:"#4b514d" }
    ],
    administrative: [
      { wall:"#c7c9c2", side:"#969d9b", roof:"#4d585d", trim:"#e9e8df", accent:"#71878a", door:"#48565a" },
      { wall:"#b9c4c3", side:"#87999a", roof:"#46565d", trim:"#e2e9e5", accent:"#9b876c", door:"#46575a" },
      { wall:"#d0c8b9", side:"#a19889", roof:"#5a5b58", trim:"#eee7d9", accent:"#7d8980", door:"#59534a" }
    ],
    service: [
      { wall:"#c6c9c1", side:"#929a91", roof:"#555d5a", trim:"#e6e8df", accent:"#74877c", door:"#4d5a53" },
      { wall:"#c8c0ad", side:"#9b8e79", roof:"#5d5a53", trim:"#e9e1d1", accent:"#8c8069", door:"#5d5143" },
      { wall:"#b8c5c4", side:"#87999a", roof:"#4b5b60", trim:"#e0e9e5", accent:"#728d91", door:"#45595c" }
    ],
    power: [
      { wall:"#aeb8b5", side:"#7e8c89", roof:"#4b5558", trim:"#d9e0dc", accent:"#9a835e", door:"#4a5654" },
      { wall:"#c0b8a8", side:"#928879", roof:"#555957", trim:"#e4ddcf", accent:"#75867c", door:"#565147" }
    ],
    water: [
      { wall:"#b8c8c7", side:"#829a9b", roof:"#4b6065", trim:"#e2ece7", accent:"#6d9695", door:"#455e62" },
      { wall:"#c7cfc5", side:"#929f93", roof:"#52605c", trim:"#e7ede2", accent:"#819a8c", door:"#4e6258" }
    ],
    sewage: [
      { wall:"#b7b8aa", side:"#858b7c", roof:"#51564f", trim:"#dedfd1", accent:"#8a866d", door:"#505548" },
      { wall:"#c4bca9", side:"#938875", roof:"#5a5750", trim:"#e6dece", accent:"#8a8067", door:"#5c5143" }
    ],
    waste: [
      { wall:"#b8b9a8", side:"#858c72", roof:"#55594b", trim:"#e0dfce", accent:"#8c8a65", door:"#535743" },
      { wall:"#c5b9a4", side:"#95846c", roof:"#5d574d", trim:"#e8dfce", accent:"#8c8064", door:"#5e5141" }
    ],
    police: [
      { wall:"#b9c3c8", side:"#87949c", roof:"#46545f", trim:"#e3e9e9", accent:"#647d91", door:"#465563" },
      { wall:"#c7c9c4", side:"#929b9b", roof:"#505b62", trim:"#e9e9e0", accent:"#74858a", door:"#4b5b60" }
    ],
    fire: [
      { wall:"#c5b5a6", side:"#94786b", roof:"#56514e", trim:"#e7d9ca", accent:"#a65f48", door:"#62483e" },
      { wall:"#c9c0ae", side:"#9a8975", roof:"#5b5750", trim:"#e9e2d3", accent:"#a36e4d", door:"#5d4d40" }
    ],
    health: [
      { wall:"#d4d1c6", side:"#a5a69d", roof:"#626a69", trim:"#f0eee5", accent:"#8ca39b", door:"#5a6762" },
      { wall:"#c4cbc6", side:"#929e99", roof:"#53605f", trim:"#e6ebe5", accent:"#7f9b91", door:"#4f625c" }
    ],
    education: [
      { wall:"#e5bd83", side:"#b28a5c", roof:"#665143", trim:"#fff0d1", accent:"#8d8067", door:"#5c4e3f" },
      { wall:"#c0c3b9", side:"#8e968c", roof:"#535c56", trim:"#e3e6dc", accent:"#7a8c80", door:"#50594f" }
    ]
  };

import { cityTileToWorld, getBuildingVisualScale } from "./city-world-scale.js";
/**
 * High-graphics procedural buildings for Mshin city (SimCity BuildIt inspired style).
 * Natural mineral palettes, multi-style roofs, rich facades, roof props, and readable silhouettes
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

  // ─── Controlled natural architectural palettes ──────────────────────────
  const serviceTypes = new Set(["power", "water", "sewage", "waste", "police", "fire", "health", "education", "service"]);
  const paletteKey = serviceTypes.has(type) ? (CITY_ARCHITECTURAL_PALETTES[type] ? type : "service") : type;
  const paletteList = CITY_ARCHITECTURAL_PALETTES[paletteKey] || CITY_ARCHITECTURAL_PALETTES.home;
  const palette = paletteList[(seed + level) % paletteList.length];

  // Per-building mineral variation is deterministic and deliberately subtle:
  // the facade family stays coherent while avoiding identical flat RGB swatches.
  function naturalColour(hex, hueRange = 0.012, saturationRange = 0.07, lightnessRange = 0.055) {
    const value = new THREE.Color(hex);
    value.offsetHSL(
      (rand() - 0.5) * hueRange,
      (rand() - 0.5) * saturationRange,
      (rand() - 0.5) * lightnessRange
    );
    return value;
  }
  const wallColour = naturalColour(palette.wall, 0.008, 0.055, 0.045);
  const sideColour = naturalColour(palette.side, 0.01, 0.06, 0.055);
  const roofColour = naturalColour(palette.roof, 0.006, 0.05, 0.045);
  const trimColour = naturalColour(palette.trim, 0.006, 0.035, 0.035);
  const accentColour = naturalColour(palette.accent, 0.012, 0.08, 0.05);
  const doorColour = naturalColour(palette.door, 0.008, 0.055, 0.04);

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
    add(new THREE.BoxGeometry(0.06, ridgeH * 0.92, d * 0.98), mat(wallColour, { roughness: 0.88 }), -hw + 0.02, baseY + ridgeH * 0.46, 0, 0, false);
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
    add(new THREE.BoxGeometry(0.17, 0.96, 0.05), doorMat, 0, 0.76, bodyD / 2 + 0.03, 0, false);
    add(new THREE.BoxGeometry(0.21, 0.06, 0.04), trimMat, 0, 1.27, bodyD / 2 + 0.035, 0, false);
    add(new THREE.BoxGeometry(0.04, 0.04, 0.06), mat("#c0a060", { metalness: 0.4, roughness: 0.45 }), 0.07, 0.72, bodyD / 2 + 0.06, 0, false);
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
    const lawn = mat("#668b4e", { roughness: 0.88, emissive: "#365a32", emissiveIntensity: 0.12 });
    add(new THREE.BoxGeometry(1.78, 0.18, 1.78), lawn, 0, 0.2, 0, 0, false);
    add(new THREE.BoxGeometry(0.28, 0.04, 1.5), mat("#ffe36a", { roughness: 0.78 }), 0.15, 0.3, 0, -0.25, false);
    if (trunkGeometry && canopyGeometry) {
      for (const [tx, tz] of [[-0.45, -0.35], [0.4, 0.3], [-0.2, 0.45]]) {
        const trunk = new THREE.Mesh(trunkGeometry, mat("#8b5b38", { roughness: 0.95 }));
        trunk.position.set(tx, 0.75, tz);
        trunk.scale.set(0.85, 0.9, 0.85);
        group.add(trunk);
        const crown = new THREE.Mesh(canopyGeometry, mat(pick(["#397b4c", "#5c9250", "#4d8564", "#9aa95a", "#5b9a83"]), { roughness: 1 }));
        crown.position.set(tx, 1.4, tz);
        group.add(crown);
        if (canopySmallGeometry) {
          const hi = new THREE.Mesh(canopySmallGeometry, mat("#b0bb73", { roughness: 0.86, emissive: "#617a3d", emissiveIntensity: 0.12 }));
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
      add(new THREE.SphereGeometry(0.06, 6, 5), mat(pick(["#bd7180", "#d8b65c", "#9272a5", "#78aebb", "#c98250"])), fx, 0.38, fz, 0, false);
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
    color: wallColour,
    roughness: 0.70,
    normalScale: facadeSurf.normalMap ? new THREE.Vector2(0.35, 0.35) : undefined
  });
  const sideWall = new THREE.MeshStandardMaterial({
    ...facadeSurf,
    color: sideColour,
    roughness: 0.73,
    normalScale: facadeSurf.normalMap ? new THREE.Vector2(0.3, 0.3) : undefined
  });
  const roofMat = new THREE.MeshStandardMaterial({
    ...(roofSurface || {}),
    color: roofColour,
    roughness: 0.68,
    normalScale: roofSurface?.normalMap ? new THREE.Vector2(0.45, 0.45) : undefined
  });
  const trimMat = mat(trimColour, { roughness: 0.65 });
  const accentMat = mat(accentColour, { roughness: 0.7 });
  const doorMat = mat(doorColour, { roughness: 0.75 });
  const glassMat = mat("#a9cbd0", {
    roughness: 0.12,
    metalness: 0.08,
    emissive: "#526f79",
    emissiveIntensity: 0.12,
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
    add(new THREE.BoxGeometry(0.9, 0.08, 0.22), mat("#688a52", { roughness: 0.82 }), 0, 0.32, bodyD / 2 + 0.28, 0, false);
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
      add(new THREE.SphereGeometry(0.12, 8, 6), mat("#718d62", { roughness: 0.82 }), gx, roofBaseY + 0.30, -0.30, 0, false);
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
