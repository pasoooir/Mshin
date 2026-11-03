import test from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import path from "node:path";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

test("production modules have resolved imports, clean domain boundaries, no cycles and bounded size", () => {
  const output = execFileSync(process.execPath, ["scripts/analyze-module-boundaries.mjs", "--check"], {
    cwd: root,
    encoding: "utf8"
  });
  assert.match(output, /Architecture check passed:/);
});
