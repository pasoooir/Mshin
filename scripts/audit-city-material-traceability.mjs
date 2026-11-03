import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const read = relative => readFile(path.join(root, relative), "utf8");

function tableRows(markdown, header) {
  const lines = markdown.split(/\r?\n/);
  const start = lines.findIndex(line => line.trim() === header);
  assert.notEqual(start, -1, `Missing Markdown table header: ${header}`);
  const rows = [];
  for (let index = start + 1; index < lines.length; index += 1) {
    const line = lines[index].trim();
    if (!line.startsWith("|")) break;
    if (/^\|[\s:|-]+\|$/.test(line)) continue;
    rows.push(line.split("|").slice(1, -1).map(cell => cell.trim()));
  }
  return rows;
}

function idsIn(value) {
  return [...value.matchAll(/\b[A-Z][A-Z0-9]+(?:-[A-Z0-9]+)+\b/g)].map(match => match[0]);
}

const [registry, catalog, mapRegister, materialAudit, readiness] = await Promise.all([
  read("docs/CAPITAL_REGION_V1_ITEM_RECIPE_REGISTRY.md"),
  read("docs/CAPITAL_REGION_V1_CONTENT_CATALOG.md"),
  read("docs/CAPITAL_REGION_MAP_LAYOUT_DECISION_REGISTER.md"),
  read("docs/CITY_V1_MATERIAL_TO_CASH_TRACEABILITY_AUDIT.md"),
  read("docs/CITY_DESIGN_PACKAGE_READINESS_AND_TRACEABILITY_AUDIT.md")
]);

const itemRows = tableRows(registry, "| Item ID | Concept | Category | Unit | Status | Role |");
const recipeRows = tableRows(registry, "| Recipe ID | Building | Inputs | Outputs | Duration | Status |");
const consumerRows = tableRows(registry, "| Consumer ID | Consumes | Trigger | Priority | Failure behavior |");

const items = new Map(itemRows.map(([id, , , , status]) => [id, status]));
const recipes = new Map(recipeRows.map(([id, building, inputs, outputs, duration, status]) => [
  id, { building, inputs, outputs, duration, status }
]));
const consumers = new Map(consumerRows.map(([id, consumes]) => [id, consumes]));

assert.ok(items.size > 0, "Item registry table is empty.");
assert.ok(recipes.size > 0, "Recipe registry table is empty.");
assert.ok(consumers.size > 0, "Consumer registry table is empty.");

for (const [recipeId, recipe] of recipes) {
  for (const itemId of [...idsIn(recipe.inputs), ...idsIn(recipe.outputs)]) {
    assert.ok(items.has(itemId), `${recipeId} references undeclared item ${itemId}`);
  }
}
for (const [consumerId, consumes] of consumers) {
  for (const itemId of idsIn(consumes)) {
    assert.ok(items.has(itemId), `${consumerId} references undeclared item ${itemId}`);
  }
}

const producers = new Map();
for (const [recipeId, recipe] of recipes) {
  for (const itemId of idsIn(recipe.outputs)) {
    const list = producers.get(itemId) ?? [];
    list.push({ recipeId, status: recipe.status });
    producers.set(itemId, list);
  }
}

const cementProducers = producers.get("MAT-CEMENT") ?? [];
assert.equal(items.get("MAT-CEMENT"), "V1-Required", "MAT-CEMENT catalog status changed unexpectedly.");
assert.ok(cementProducers.some(producer => producer.recipeId === "REC-CEMENT-01" && producer.status === "Candidate"),
  "Expected the documented MAT-CEMENT / REC-CEMENT-01 status conflict.");
assert.equal(consumers.has("CONS-BUILD-FOUNDATION"), true);
assert.ok(consumers.get("CONS-BUILD-FOUNDATION").includes("MAT-CEMENT"),
  "Foundation consumer no longer declares MAT-CEMENT; review the audit.");

for (const recipeId of ["REC-RAW-METAL-01", "REC-RAW-WOOD-01"]) {
  const recipe = recipes.get(recipeId);
  assert.ok(recipe, `Missing required raw-item recipe ${recipeId}`);
  assert.match(recipe.inputs, /Operating resources TBD/,
    `${recipeId} operating-input contract changed; review the audit.`);
}

for (const key of ["REQUIRED-ITEM-PRODUCER-COVERAGE", "RAW-ITEM-OPERATING-SOURCE"]) {
  assert.ok(mapRegister.includes(key), `Map decision register is missing ${key}`);
}
assert.ok(materialAudit.includes("MAT-CEMENT` is explicitly **V1-Required**"));
assert.ok(materialAudit.includes("REC-CEMENT-01` is **Candidate**"));
assert.ok(materialAudit.includes("Operating resources TBD"));
assert.ok(readiness.includes("4.8 Required item producer coverage"));

const catalogRows = tableRows(catalog, "| ID | Name | Status | Footprint | Access | Contract |")
  .concat(tableRows(catalog, "| ID | Name | Status | Footprint | Contract |"));
assert.ok(catalogRows.length > 0, "Building catalog tables could not be parsed.");

console.log("PASS: canonical item, recipe and consumer references are internally resolvable.");
console.log("KNOWN BLOCKER: MAT-CEMENT is V1-Required, but REC-CEMENT-01 is Candidate.");
console.log("KNOWN BLOCKER: REC-RAW-METAL-01 and REC-RAW-WOOD-01 retain undefined operating inputs.");
console.log("PASS: both blockers are explicitly tracked in the material audit, readiness audit and map decision register.");
console.log("No gameplay status or implementation scope is changed by this audit.");
