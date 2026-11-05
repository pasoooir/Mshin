#!/usr/bin/env node
/**
 * Downloads the real Poly Haven CC0 diffuse maps used by the mobile race renderer.
 * Run: npm run assets:race-textures
 */
import { mkdir, writeFile, stat } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const output = join(root, "assets", "textures");
const assets = [
  ["asphalt_03_diff_1k.jpg", "asphalt_03"],
  ["grass_ground_diff_1k.jpg", "grass_ground"],
  ["sand_01_diff_1k.jpg", "sand_01"],
  ["snow_03_diff_1k.jpg", "snow_03"],
  ["rocky_terrain_02_diff_1k.jpg", "rocky_terrain_02"],
  ["concrete_floor_02_diff_1k.jpg", "concrete_floor_02"],
  ["bark_brown_02_diff_1k.jpg", "bark_brown_02"],
  ["leafy_grass_diff_1k.jpg", "leafy_grass"]
];
const base = "https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k";
await mkdir(output, { recursive: true });
for (const [filename, asset] of assets) {
  const destination = join(output, filename);
  try {
    const existing = await stat(destination);
    if (existing.size > 1024) {
      console.log("[race-textures] already present:", filename);
      continue;
    }
  } catch {}
  const url = `${base}/${asset}/${filename}`;
  const response = await fetch(url, { signal: AbortSignal.timeout(30000) });
  if (!response.ok) throw new Error(`Download failed (${response.status}): ${url}`);
  const bytes = Buffer.from(await response.arrayBuffer());
  if (bytes.length < 1024 || bytes[0] !== 0xff || bytes[1] !== 0xd8 || bytes[2] !== 0xff) {
    throw new Error(`Invalid JPEG response for ${filename}`);
  }
  await writeFile(destination, bytes);
  console.log("[race-textures] downloaded", filename, `${(bytes.length / 1024).toFixed(1)} KiB`);
}
console.log("[race-textures] all eight real CC0 diffuse maps are ready.");
