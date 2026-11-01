import { readdirSync } from "node:fs";
import { join, resolve } from "node:path";
import { execFileSync } from "node:child_process";

const roots = ["src", "scripts", "tests"];
const files = ["workers.js", "service-worker.js"];
function walk(directory) {
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) walk(path);
    else if (entry.name.endsWith(".js") || entry.name.endsWith(".mjs") || entry.name.endsWith(".cjs")) files.push(path);
  }
}
for (const root of roots) walk(root);
const unique = [...new Set(files)].sort();
for (const file of unique) execFileSync(process.execPath, ["--check", resolve(file)], { stdio: "inherit" });
console.log("PASS: JavaScript syntax checked for " + unique.length + " files.");
