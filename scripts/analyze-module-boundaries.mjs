import { readdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const sourceExtensions = new Set([".js", ".mjs", ".cjs", ".ts"]);
const ignored = new Set([".git", "node_modules", "dist", "coverage"]);
const normalize = value => value.split(path.sep).join("/");

async function walk(directory) {
  const found = [];
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    if (ignored.has(entry.name)) continue;
    const absolute = path.join(directory, entry.name);
    if (entry.isDirectory()) found.push(...await walk(absolute));
    else if (sourceExtensions.has(path.extname(entry.name))) found.push(absolute);
  }
  return found;
}

function domain(file) {
  const value = normalize(file);
  if (/(^|\/)city(\/|[-.]|$)|city\.html$/.test(value)) return "city";
  if (value.startsWith("src/") || value.startsWith("assets/scripts/")) return "racing";
  return "shared";
}

function resolveLocalImport(from, specifier) {
  if (!specifier.startsWith(".")) return null;
  return path.posix.normalize(path.posix.join(path.posix.dirname(from), specifier));
}

const sourceFiles = (await walk(root))
  .map(file => normalize(path.relative(root, file)))
  .sort();
const modules = [];
const edges = [];

for (const file of sourceFiles) {
  const source = await readFile(path.join(root, file), "utf8");
  const imports = new Set();
  const pattern = /(?:\bfrom\s*|\bimport\s*\(|\bimport\s*)["']([^"']+)["']/g;
  for (const match of source.matchAll(pattern)) {
    const target = resolveLocalImport(file, match[1]);
    if (target) imports.add(target);
  }
  modules.push({ path: file, domain: domain(file), bytes: Buffer.byteLength(source), localImports: [...imports].sort() });
  for (const target of imports) {
    edges.push({ from: file, to: target, fromDomain: domain(file), toDomain: domain(target) });
  }
}

const htmlFiles = ["index.html", "city.html"];
const entryPoints = [];
for (const file of htmlFiles) {
  try {
    const html = await readFile(path.join(root, file), "utf8");
    const refs = [...html.matchAll(/(?:src|href)=["']([^"']+\.(?:js|mjs|css))["']/g)]
      .map(match => match[1])
      .filter(ref => !/^(?:https?:|data:|#)/.test(ref));
    entryPoints.push({ html: file, domain: domain(file), references: [...new Set(refs)].sort() });
  } catch {}
}

const report = {
  schemaVersion: 1,
  sourceFileCount: modules.length,
  entryPoints,
  modules,
  dependencyEdges: edges,
  crossDomainEdges: edges.filter(edge => edge.fromDomain !== edge.toDomain),
  largestModules: [...modules].sort((a, b) => b.bytes - a.bytes).slice(0, 12)
};

const json = JSON.stringify(report, null, 2) + "\n";
const outputIndex = process.argv.indexOf("--write");
if (outputIndex >= 0) {
  const destination = process.argv[outputIndex + 1] || "docs/architecture-dependency-map.json";
  await writeFile(path.resolve(root, destination), json);
  console.log("Wrote " + destination + ": " + modules.length + " source files, " + edges.length + " local import edges, " + report.crossDomainEdges.length + " cross-domain edges.");
} else {
  console.log(JSON.stringify({
    sourceFileCount: report.sourceFileCount,
    entryPoints: report.entryPoints,
    dependencyEdgeCount: edges.length,
    crossDomainEdges: report.crossDomainEdges,
    largestModules: report.largestModules
  }, null, 2));
}
