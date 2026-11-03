import { access, readdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const sourceExtensions = new Set([".js", ".mjs", ".cjs", ".ts"]);
const ignored = new Set([".git", "node_modules", "dist", "coverage", ".test-build"]);
const DEFAULT_MAX_MODULE_BYTES = 40_000;
const MODULE_SIZE_BUDGETS = {
  "src/web-game.js": 100_000,
  "src/city/city-view.js": 42_000,
  "src/race-renderer-3d.js": 50_000,
  "src/city/city-three-renderer.js": 35_000
};
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
  if (value === "city.html" || value.startsWith("src/city/") || value.startsWith("assets/scripts/City")) return "city";
  if (value.startsWith("src/shared/") || value.startsWith("shared/")) return "shared";
  if (value.startsWith("src/") || value.startsWith("assets/scripts/") || value === "index.html") return "racing";
  return "shared";
}

function resolveLocalImport(from, specifier) {
  if (!specifier.startsWith(".")) return null;
  const clean = specifier.split(/[?#]/, 1)[0];
  return path.posix.normalize(path.posix.join(path.posix.dirname(from), clean));
}

async function resolveExistingTarget(candidate) {
  const clean = path.posix.normalize(candidate).replace(/^\.\//, "");
  const attempts = [
    clean,
    // NodeNext TypeScript source commonly imports the emitted .js specifier.
    // Resolve that specifier to its .ts source counterpart for static analysis.
    ...(clean.endsWith(".js") ? [clean.slice(0, -3) + ".ts"] : []),
    ...[".js", ".mjs", ".cjs", ".ts", ".json", ".css", ".svg"].map(extension => clean + extension),
    ...["index.js", "index.mjs", "index.ts"].map(index => path.posix.join(clean, index))
  ];
  for (const relative of attempts) {
    const absolute = path.resolve(root, relative);
    if (absolute !== root && !absolute.startsWith(root + path.sep)) continue;
    try {
      await access(absolute);
      return normalize(path.relative(root, absolute));
    } catch {}
  }
  return null;
}

function findCircularDependencies(files, edges) {
  const graph = new Map(files.map(file => [file, []]));
  for (const edge of edges) {
    if (graph.has(edge.from) && graph.has(edge.to)) graph.get(edge.from).push(edge.to);
  }
  const visited = new Set();
  const active = new Set();
  const stack = [];
  const cycles = new Map();
  function visit(file) {
    if (active.has(file)) {
      const start = stack.indexOf(file);
      const cycle = [...stack.slice(start), file];
      const key = [...new Set(cycle.slice(0, -1))].sort().join("|");
      if (!cycles.has(key)) cycles.set(key, cycle);
      return;
    }
    if (visited.has(file)) return;
    visited.add(file);
    active.add(file);
    stack.push(file);
    for (const dependency of graph.get(file) || []) visit(dependency);
    stack.pop();
    active.delete(file);
  }
  for (const file of files) visit(file);
  return [...cycles.values()];
}

const sourceFiles = (await walk(root))
  .map(file => normalize(path.relative(root, file)))
  .sort();
const productionFiles = sourceFiles.filter(file => file.startsWith("src/") || file.startsWith("assets/scripts/"));
const modules = [];
const edges = [];
const unresolvedLocalImports = [];

for (const file of sourceFiles) {
  const source = await readFile(path.join(root, file), "utf8");
  const imports = new Set();
  const pattern = /(?:\bfrom\s*|\bimport\s*\(|\bimport\s*)["']([^"']+)["']/g;
  for (const match of source.matchAll(pattern)) {
    const candidate = resolveLocalImport(file, match[1]);
    if (!candidate) continue;
    const target = await resolveExistingTarget(candidate);
    if (!target) {
      if (productionFiles.includes(file)) unresolvedLocalImports.push({ from: file, specifier: match[1], resolved: candidate });
      continue;
    }
    imports.add(target);
    if (productionFiles.includes(file)) {
      edges.push({ from: file, to: target, fromDomain: domain(file), toDomain: domain(target) });
    }
  }
  modules.push({ path: file, domain: domain(file), bytes: Buffer.byteLength(source), localImports: [...imports].sort() });
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

const crossDomainEdges = edges.filter(edge => edge.fromDomain !== edge.toDomain);
const forbiddenCrossDomainEdges = crossDomainEdges.filter(edge =>
  (edge.fromDomain === "shared" && edge.toDomain !== "shared")
  || (edge.fromDomain !== "shared" && edge.toDomain !== "shared" && edge.fromDomain !== edge.toDomain)
);
const circularDependencies = findCircularDependencies(productionFiles, edges);
const oversizedModules = modules
  .filter(module => productionFiles.includes(module.path))
  .filter(module => module.bytes > (MODULE_SIZE_BUDGETS[module.path] || DEFAULT_MAX_MODULE_BYTES))
  .map(module => ({
    path: module.path,
    bytes: module.bytes,
    budget: MODULE_SIZE_BUDGETS[module.path] || DEFAULT_MAX_MODULE_BYTES
  }));
const report = {
  schemaVersion: 2,
  sourceFileCount: modules.length,
  productionModuleCount: productionFiles.length,
  entryPoints,
  modules,
  dependencyEdges: edges,
  crossDomainEdges,
  unresolvedLocalImports,
  forbiddenCrossDomainEdges,
  circularDependencies,
  oversizedModules,
  moduleSizeBudgets: { default: DEFAULT_MAX_MODULE_BYTES, exceptions: MODULE_SIZE_BUDGETS }
};
report.passed = unresolvedLocalImports.length === 0
  && forbiddenCrossDomainEdges.length === 0
  && circularDependencies.length === 0
  && oversizedModules.length === 0;

const args = process.argv.slice(2);
const writeIndex = args.indexOf("--write");
if (writeIndex >= 0) {
  const destination = args[writeIndex + 1] || "docs/architecture-dependency-map.json";
  await writeFile(path.resolve(root, destination), JSON.stringify(report, null, 2) + "\n");
  console.log("Wrote " + destination + ": " + productionFiles.length + " production modules, " + edges.length + " import edges.");
}

if (args.includes("--check")) {
  if (!report.passed) {
    console.error("Architecture check failed: " + JSON.stringify({
      unresolvedLocalImports,
      forbiddenCrossDomainEdges,
      circularDependencies,
      oversizedModules
    }, null, 2));
    process.exitCode = 1;
  } else {
    console.log("Architecture check passed: " + productionFiles.length + " production modules, " + edges.length + " local edges, no unresolved imports, forbidden domain edges, cycles or size-budget violations.");
  }
} else if (writeIndex < 0) {
  console.log(JSON.stringify({
    sourceFileCount: report.sourceFileCount,
    productionModuleCount: report.productionModuleCount,
    entryPoints,
    dependencyEdgeCount: edges.length,
    crossDomainEdges,
    unresolvedLocalImports,
    forbiddenCrossDomainEdges,
    circularDependencies,
    oversizedModules,
    largestModules: [...modules].sort((a, b) => b.bytes - a.bytes).slice(0, 12)
  }, null, 2));
}
