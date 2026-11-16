import test from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { createApp, signAccessToken } from "../src/index.mjs";

const secret = "test-only-secret-that-is-long-enough-123456";
async function fixture(options = {}) {
  const directory = await mkdtemp(path.join(os.tmpdir(), "mshin-json-"));
  const server = createApp({
    dataDir: directory,
    authSecret: secret,
    devAuthEnabled: true,
    devIdentities: new Map([["admin", 100001], ["player2", 100002]]),
    ...options
  });
  await new Promise(resolve => server.listen(0, "127.0.0.1", resolve));
  const base = "http://127.0.0.1:" + server.address().port;
  const token = id => signAccessToken(id, secret);
  return { directory, server, base, token, close: async () => { server.closeAllConnections(); await new Promise(resolve => server.close(resolve)); await rm(directory, { recursive: true, force: true }); } };
}
async function json(url, token, method = "GET", body) {
  const response = await fetch(url, {
    method,
    headers: { ...(token ? { authorization: "Bearer " + token } : {}), ...(body ? { "content-type": "application/json" } : {}) },
    body: body ? JSON.stringify(body) : undefined
  });
  return { status: response.status, body: await response.json() };
}

test("profile files are isolated by numeric player id", async t => {
  const f = await fixture(); t.after(f.close);
  const a = await json(f.base + "/v1/profile", f.token(100001), "PUT", { expected_revision: 0, game_state: { city: "A", coins: 900 } });
  const b = await json(f.base + "/v1/profile", f.token(100002), "PUT", { expected_revision: 0, game_state: { city: "B", coins: 40 } });
  assert.equal(a.status, 200); assert.equal(b.status, 200);
  assert.equal((await json(f.base + "/v1/profile", f.token(100001))).body.game_state.city, "A");
  assert.equal((await json(f.base + "/v1/profile", f.token(100002))).body.game_state.city, "B");
  assert.notEqual(path.basename(path.join(f.directory, "players", "100001.json")), path.basename(path.join(f.directory, "players", "100002.json")));
});

test("optimistic revision rejects stale concurrent writes", async t => {
  const f = await fixture(); t.after(f.close);
  const first = await json(f.base + "/v1/profile", f.token(100001), "PUT", { expected_revision: 0, game_state: { coins: 1 } });
  assert.equal(first.status, 200);
  const stale = await json(f.base + "/v1/profile", f.token(100001), "PUT", { expected_revision: 0, game_state: { coins: 999 } });
  assert.equal(stale.status, 409);
  assert.equal(stale.body.revision, 1);
  assert.equal((await json(f.base + "/v1/profile", f.token(100001))).body.game_state.coins, 1);
});

test("email fields are rejected and never written to JSON", async t => {
  const f = await fixture(); t.after(f.close);
  const result = await json(f.base + "/v1/profile", f.token(100001), "PUT", {
    expected_revision: 0, game_state: { city: "A", profile: { email: "private@example.test" } }
  });
  assert.equal(result.status, 400);
  await assert.rejects(readFile(path.join(f.directory, "players", "100001.json")));
});

test("dev identity endpoint is unavailable when disabled or in production", async t => {
  const f = await fixture({ devAuthEnabled: true, nodeEnv: "production" }); t.after(f.close);
  const result = await json(f.base + "/v1/dev/session", null, "POST", { identity: "admin" });
  assert.equal(result.status, 404);
});

test("invalid or expired tokens cannot read profiles", async t => {
  const f = await fixture(); t.after(f.close);
  const invalid = await json(f.base + "/v1/profile", "not-a-token");
  const expired = await json(f.base + "/v1/profile", signAccessToken(100001, secret, 1));
  assert.equal(invalid.status, 401);
  assert.equal(expired.status, 401);
});
