import test from "node:test";
import assert from "node:assert/strict";
import worker from "../workers.js";

const env = {};
const pagesOrigin = "https://pasoooir.github.io";

async function call(path, { method = "GET", origin = pagesOrigin } = {}) {
  return worker.fetch(new Request(`https://mshin-api.example.workers.dev${path}`, {
    method,
    headers: origin ? { Origin: origin } : {},
  }), env);
}

test("health endpoint reports service and versions", async () => {
  const response = await call("/api/v1/health");
  assert.equal(response.status, 200);
  assert.equal(response.headers.get("access-control-allow-origin"), pagesOrigin);
  assert.equal(response.headers.get("x-content-type-options"), "nosniff");
  assert.deepEqual(await response.json(), {
    ok: true, service: "mshin-game-api", apiVersion: "1", gameVersion: "0.4.0",
  });
});

test("config exposes ten worlds and fifty stages without claiming server persistence", async () => {
  const response = await call("/api/v1/config");
  const data = await response.json();
  assert.equal(response.status, 200);
  assert.equal(data.worlds.length, 10);
  assert.equal(data.totalStages, 50);
  assert.deepEqual(data.storage, { mode: "local-first", serverPersistence: false });
});

test("unknown routes return a JSON 404", async () => {
  const response = await call("/api/v1/unknown");
  assert.equal(response.status, 404);
  assert.deepEqual(await response.json(), { error: "not_found" });
});

test("non-GET methods are rejected", async () => {
  const response = await call("/api/v1/config", { method: "POST" });
  assert.equal(response.status, 405);
  assert.deepEqual(await response.json(), { error: "method_not_allowed" });
});

test("untrusted origins are rejected without CORS permission", async () => {
  const response = await call("/api/v1/config", { origin: "https://attacker.example" });
  assert.equal(response.status, 403);
  assert.equal(response.headers.get("access-control-allow-origin"), null);
  assert.deepEqual(await response.json(), { error: "origin_not_allowed" });
});

test("preflight is accepted only for configured origins", async () => {
  const good = await call("/api/v1/config", { method: "OPTIONS" });
  assert.equal(good.status, 204);
  assert.equal(good.headers.get("access-control-allow-methods"), "GET, OPTIONS");
  const bad = await call("/api/v1/config", { method: "OPTIONS", origin: "https://attacker.example" });
  assert.equal(bad.status, 403);
});

test("requests without Origin remain usable for server-side health checks", async () => {
  const response = await call("/api/v1/health", { origin: null });
  assert.equal(response.status, 200);
  assert.equal(response.headers.get("access-control-allow-origin"), null);
});
