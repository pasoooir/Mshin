#!/usr/bin/env node
/**
 * Verifies the committed CC0 racing textures. This script is intentionally
 * offline: it never downloads files or contacts an external asset host.
 */
import { readFile, stat } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const expected = [
  "asphalt_03_diff_1k.jpg",
  "grass_ground_diff_1k.jpg",
  "sand_01_diff_1k.jpg",
  "snow_03_diff_1k.jpg",
  "rocky_terrain_02_diff_1k.jpg",
  "concrete_floor_02_diff_1k.jpg",
  "bark_brown_02_diff_1k.jpg",
  "leafy_grass_diff_1k.jpg"
];

for (const name of expected) {
  const path = join(root, "assets", "textures", name);
  const info = await stat(path);
  if (!info.isFile() || info.size < 1024) throw new Error("Missing or undersized local texture: " + name);
  const bytes = await readFile(path);
  if (bytes[0] !== 0xff || bytes[1] !== 0xd8 || bytes[2] !== 0xff)
    throw new Error("Invalid JPEG header in local texture: " + name);
  console.log("OK " + name + " (" + Math.round(info.size / 1024) + " KiB)");
}
console.log("PASS: all eight CC0 race textures are committed locally; no network access used.");
