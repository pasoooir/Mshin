import { readFile, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const packagePath = path.join(root, "package.json");
const manifestPath = path.join(root, "manifest.webmanifest");
const pkg = JSON.parse(await readFile(packagePath, "utf8"));
const manifest = JSON.parse(await readFile(manifestPath, "utf8"));

if (!/^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$/.test(pkg.version ?? "")) {
  throw new Error("package.json must contain a valid semantic version");
}

if (manifest.version !== pkg.version) {
  manifest.version = pkg.version;
  await writeFile(manifestPath, JSON.stringify(manifest, null, 2) + "\n");
  console.log("Synchronized manifest.webmanifest to package.json version " + pkg.version);
} else {
  console.log("Version markers already synchronized: " + pkg.version);
}
