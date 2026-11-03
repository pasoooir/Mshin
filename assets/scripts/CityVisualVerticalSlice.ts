import { _decorator, Component, Material, MeshRenderer, Node, Color, Texture2D, Vec4, primitives, resources, utils, Vec3 } from "cc";

const { ccclass } = _decorator;

/**
 * Native Cocos 3.8.6 city art-direction vertical slice.
 * A deterministic sample block for validating silhouette, scale and material
 * separation before the complete authored asset family is produced.
 * Flat materials are placeholders; final production art requires PBR textures.
 */
@ccclass("MshinCityVisualVerticalSlice")
export class CityVisualVerticalSlice extends Component {
  private materials = new Map<string, Material>();
  private meshes = new Map<string, any>();
  private texturedNodes = new Map<string, MeshRenderer[]>();
  private readonly texturePaths: Record<string, string> = {
    grass: "city/textures/generated/grass",
    asphalt: "city/textures/generated/asphalt",
    sidewalk: "city/textures/generated/sidewalk",
    brick: "city/textures/generated/brick",
    concrete: "city/textures/generated/concrete",
    roof: "city/textures/generated/roof"
  };

  start(): void { this.buildSampleDistrict(); }

  private buildSampleDistrict(): void {
    this.node.destroyAllChildren();
    this.materials.clear();
    this.meshes.clear();
    this.texturedNodes.clear();
    this.box("Grass terrain", 46, 0.35, 34, 0, -0.2, 0, "grass");
    this.box("Road asphalt", 46, 0.16, 7.2, 0, 0.02, 0, "asphalt");
    this.box("North sidewalk", 46, 0.22, 1.25, 0, 0.12, -4.15, "sidewalk");
    this.box("South sidewalk", 46, 0.22, 1.25, 0, 0.12, 4.15, "sidewalk");
    for (let i = 0; i < 11; i++) this.box("Lane dash " + i, 1.5, 0.03, 0.12, -20 + i * 4, 0.12, 0, "roadMarking");
    this.buildHouse(-15, -10);
    this.buildApartment(-4, -10);
    this.buildShop(10, -10);
    this.buildFactory(17, 10);
    this.buildPark(-13, 10);
    this.buildStreetFurniture();
    this.loadRuntimeTextures();
  }

  /** Load validated PNG assets imported by Cocos from assets/resources. */
  private loadRuntimeTextures(): void {
    for (const [materialKey, resourcePath] of Object.entries(this.texturePaths)) {
      resources.load(resourcePath, Texture2D, (error, texture) => {
        if (error || !texture) {
          console.warn("[MshinCity] Texture unavailable:", resourcePath, error);
          return;
        }
        const renderers = this.texturedNodes.get(materialKey) ?? [];
        for (const renderer of renderers) {
          const material = renderer.getMaterial(0);
          if (!material) continue;
          material.setProperty("mainTexture", texture);
          const repeat = materialKey === "grass" ? 8 : materialKey === "asphalt" ? 5 : 2;
          material.setProperty("tilingOffset", new Vec4(repeat, repeat, 0, 0));
        }
      });
    }
  }

  private buildHouse(x: number, z: number): void {
    const root = this.group("Residential House", x, 0, z);
    this.part(root, "House plaster body", 6.2, 3.5, 5.2, 0, 1.9, 0, "plaster");
    this.part(root, "Pitched roof mass", 6.8, 0.55, 5.8, 0, 3.95, 0, "roof");
    this.part(root, "Roof ridge", 0.22, 0.42, 6, 0, 4.35, 0, "roofDark");
    this.part(root, "Porch", 2.2, 0.22, 1.4, 0, 0.25, 3.1, "trim");
    this.part(root, "Front door", 1.05, 2.1, 0.12, 0, 1.25, 2.67, "wood");
    this.windowGrid(root, 2, 2, 1.25, 1.05, 1.7, 2.25, 2.67);
    this.part(root, "Chimney", 0.65, 1.15, 0.65, 2.05, 4.4, -1.45, "brick");
  }

  private buildApartment(x: number, z: number): void {
    const root = this.group("Residential Midrise", x, 0, z);
    this.part(root, "Apartment main mass", 7.2, 9.2, 6.4, 0, 4.75, 0, "warmWhite");
    this.part(root, "Apartment side wing", 1.25, 7.6, 6.45, 4.15, 3.95, 0, "plaster");
    this.part(root, "Roof cap", 7.65, 0.42, 6.85, 0, 9.55, 0, "roofDark");
    this.part(root, "Roof penthouse", 2.5, 1.1, 2.2, -1.6, 10.25, -1.25, "concrete");
    this.windowGrid(root, 4, 4, 0.82, 1.05, 1.18, 2.45, 3.25);
    for (let floor = 0; floor < 4; floor++) this.part(root, "Balcony slab " + floor, 7.45, 0.12, 0.65, 0, 1.35 + floor * 2.05, 3.45, "concrete");
  }

  private buildShop(x: number, z: number): void {
    const root = this.group("Commercial Shop", x, 0, z);
    this.part(root, "Shop body", 7.4, 3.8, 5.6, 0, 2.05, 0, "shopBlue");
    this.part(root, "Shop fascia", 7.55, 0.55, 0.2, 0, 3.55, 2.9, "shopGold");
    this.part(root, "Display glazing", 5.6, 2.1, 0.12, 0, 1.8, 2.88, "glass");
    this.part(root, "Striped awning", 7.9, 0.2, 1.25, 0, 3.0, 3.35, "awning");
    this.part(root, "Side service door", 0.9, 2.0, 0.12, 3.0, 1.2, 2.88, "wood");
  }

  private buildFactory(x: number, z: number): void {
    const root = this.group("Industrial Factory", x, 0, z);
    this.part(root, "Factory hall", 10.5, 4.5, 8.2, 0, 2.45, 0, "concrete");
    this.part(root, "Factory roof", 10.9, 0.5, 8.6, 0, 4.95, 0, "metal");
    this.part(root, "Loading bay", 3.1, 2.6, 0.18, 2.25, 1.55, 4.2, "metal");
    this.part(root, "Safety stripe", 3.1, 0.22, 0.08, 2.25, 0.35, 4.31, "safety");
    this.part(root, "Stack one", 0.85, 5.2, 0.85, -3.65, 7.35, -2.4, "pipe");
    this.part(root, "Stack cap one", 1.15, 0.28, 1.15, -3.65, 10.05, -2.4, "safety");
    this.part(root, "Stack two", 0.72, 3.8, 0.72, -1.8, 6.65, -2.4, "metal");
    this.part(root, "Storage tank", 2.2, 2.8, 2.2, 3.35, 6.1, -2.2, "pipe");
    this.part(root, "Tank top", 2.35, 0.22, 2.35, 3.35, 7.62, -2.2, "safety");
    this.part(root, "Pipe run", 4.8, 0.28, 0.28, 0.5, 5.65, -2.35, "pipe");
  }

  private buildPark(x: number, z: number): void {
    const root = this.group("Pocket Park", x, 0, z);
    this.part(root, "Park lawn", 10, 0.16, 8, 0, 0.12, 0, "parkGrass");
    this.part(root, "Path", 1.25, 0.08, 7.4, 0, 0.22, 0, "sidewalk");
    this.part(root, "Bench seat", 2.0, 0.18, 0.55, -2.2, 0.65, 1.2, "wood");
    this.part(root, "Bench back", 2.0, 0.85, 0.16, -2.2, 1.05, 1.5, "wood");
    this.tree(root, -3.2, 0, -2.1);
    this.tree(root, 3.1, 0, -2.0);
    this.tree(root, 2.8, 0, 2.5);
  }

  private buildStreetFurniture(): void {
    for (const x of [-18, -6, 6, 18]) {
      this.box("Street lamp post", 0.12, 4.2, 0.12, x, 2.2, 5.25, "lamp");
      this.box("Street lamp arm", 1.1, 0.12, 0.12, x + 0.45, 4.2, 5.25, "lamp");
      this.box("Street lamp head", 0.55, 0.2, 0.42, x + 0.8, 4.08, 5.25, "lampGlow");
    }
  }

  private tree(parent: Node, x: number, y: number, z: number): void {
    this.makePart(parent, "Tree trunk", 0.35, 1.6, 0.35, x, y + 0.8, z, "wood");
    this.makePart(parent, "Tree lower crown", 2.5, 2.0, 2.5, x, y + 2.0, z, "leafDark");
    this.makePart(parent, "Tree upper crown", 1.9, 1.9, 1.9, x, y + 3.15, z, "leaf");
  }

  private windowGrid(parent: Node, columns: number, rows: number, width: number, height: number, gapX: number, startY: number, frontZ: number): void {
    const total = (columns - 1) * gapX;
    for (let row = 0; row < rows; row++) for (let col = 0; col < columns; col++) {
      const x = -total / 2 + col * gapX;
      const y = startY + row * 1.65;
      this.makePart(parent, "Facade window " + row + "-" + col, width, height, 0.09, x, y, frontZ, "glass");
      this.makePart(parent, "Window sill " + row + "-" + col, width + 0.12, 0.08, 0.14, x, y - height / 2 - 0.04, frontZ + 0.06, "trim");
    }
  }

  private group(name: string, x: number, y: number, z: number): Node {
    const node = new Node(name);
    this.node.addChild(node);
    node.setPosition(x, y, z);
    return node;
  }

  private box(name: string, sx: number, sy: number, sz: number, x: number, y: number, z: number, material: string): Node {
    return this.makePart(this.node, name, sx, sy, sz, x, y, z, material);
  }

  private part(parent: Node, name: string, sx: number, sy: number, sz: number, x: number, y: number, z: number, material: string): Node {
    return this.makePart(parent, name, sx, sy, sz, x, y, z, material);
  }

  private makePart(parent: Node, name: string, sx: number, sy: number, sz: number, x: number, y: number, z: number, materialKey: string): Node {
    const node = new Node(name);
    parent.addChild(node);
    node.setPosition(new Vec3(x, y, z));
    node.setScale(new Vec3(sx, sy, sz));
    const renderer = node.addComponent(MeshRenderer);
    renderer.mesh = this.getBoxMesh();
    renderer.material = this.getMaterial(materialKey);
    if (this.texturePaths[materialKey]) {
      const renderers = this.texturedNodes.get(materialKey) ?? [];
      renderers.push(renderer);
      this.texturedNodes.set(materialKey, renderers);
    }
    return node;
  }

  private getBoxMesh(): any {
    let mesh = this.meshes.get("unit-box");
    if (!mesh) {
      mesh = utils.MeshUtils.createMesh(primitives.box(1, 1, 1));
      this.meshes.set("unit-box", mesh);
    }
    return mesh;
  }

  private getMaterial(key: string): Material {
    let material = this.materials.get(key);
    if (material) return material;
    const colors: Record<string, string> = {
      grass: "#78B94D", parkGrass: "#8CC65B", asphalt: "#374454", roadMarking: "#F3E9B5",
      sidewalk: "#D8D2BE", plaster: "#E7D7B9", warmWhite: "#F1EBDD", brick: "#B96E50",
      roof: "#8B5543", roofDark: "#69473F", trim: "#F7E7C9", glass: "#83C5D8",
      wood: "#98704B", shopBlue: "#267DA0", shopGold: "#E6A34A", awning: "#E86E42",
      concrete: "#929B96", metal: "#596B70", safety: "#E7B84B", pipe: "#7F9B9B",
      leaf: "#2F8B45", leafDark: "#17683A", lamp: "#394A50", lampGlow: "#F5D98B"
    };
    material = new Material();
    material.initialize({
      effectName: "builtin-standard",
      defines: this.texturePaths[key] ? { USE_ALBEDO_MAP: true } : {}
    });
    material.setProperty("albedo", this.texturePaths[key] ? new Color(255, 255, 255, 255) : this.hexColor(colors[key] ?? "#FFFFFF"));
    material.setProperty("roughness", key === "glass" ? 0.24 : 0.82);
    this.materials.set(key, material);
    return material;
  }

  private hexColor(hex: string): Color {
    const value = hex.replace("#", "");
    return new Color(parseInt(value.slice(0, 2), 16), parseInt(value.slice(2, 4), 16), parseInt(value.slice(4, 6), 16), 255);
  }
}
