import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const source = await readFile(new URL("../src/city/city-building-high-gfx.js", import.meta.url), "utf8");

test("city building families use restrained real-world architectural color palettes", () => {
  for (const family of ["home", "shop", "industrial", "administrative", "service", "power", "water", "sewage", "waste", "police", "fire", "health", "education"]) {
    assert.match(source, new RegExp("^\\s*" + family + ": \\[", "m"), family + " palette must be defined");
  }
  assert.match(source, /wall:"#d8c8ad"/, "residential palette should use natural plaster/stone hues");
  assert.match(source, /roof:"#555b60"/, "residential roofs should use believable slate/metal tones");
  assert.match(source, /accent:"#657d78"/, "architectural accents should remain material-led and restrained");
  assert.doesNotMatch(source, /#ff3fa4|#00f5d4|#35e7ff|#ffb52e|#a7ff32/i, "neon palette colors must not remain in building family definitions");
});

test("architectural palette update does not remove full 3D building geometry or shadow behavior", () => {
  for (const marker of ["addGableRoof", "addHipRoof", "addFlatRoof", "addWindows", "addDoor", "castShadow = cast", "receiveShadow = true"]) {
    assert.ok(source.includes(marker), marker + " must remain available");
  }
});
