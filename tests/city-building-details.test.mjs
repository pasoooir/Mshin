import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

test("each civic and utility service has its own rooftop geometry", async () => {
  const source = await readFile(new URL("../src/city/city-building-details.js", import.meta.url), "utf8");
  for (const type of ["police", "fire", "health", "education", "power", "water", "sewage", "waste"]) {
    assert.ok(source.includes('type === "' + type + '"'), type + " must have a dedicated model branch");
  }
  assert.ok(source.includes("hose-drying tower"));
  assert.ok(source.includes("Elevated cylindrical reservoir"));
  assert.ok(source.includes("treatment vents"));
  assert.ok(source.includes("collection hoppers"));
  assert.ok(source.includes("transformer insulators"));
  assert.ok(source.includes("School clock"));
  assert.ok(source.includes("Medical cross"));
});
