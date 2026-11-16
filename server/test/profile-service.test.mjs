import test from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { createApp, signAccessToken } from "../src/index.mjs";
import { GitHubJsonStore } from "../src/json-store.mjs";

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


test("GitHub JSON storage commits multiple player and market files in one Git commit", async () => {
  const calls = [];
  const fakeFetch = async (url, options = {}) => {
    const method = options.method || "GET";
    calls.push({ url, method, body: options.body ? JSON.parse(options.body) : null });
    let payload = {};
    if (url.endsWith("/git/ref/heads/main")) payload = { object: { sha: "base-commit" } };
    else if (url.endsWith("/git/commits/base-commit")) payload = { tree: { sha: "base-tree" } };
    else if (url.endsWith("/git/blobs")) payload = { sha: "blob-" + calls.length };
    else if (url.endsWith("/git/trees")) payload = { sha: "new-tree" };
    else if (url.endsWith("/git/commits") && method === "POST") payload = { sha: "new-commit" };
    else if (url.endsWith("/git/refs/heads/main") && method === "PATCH") payload = { ref: "refs/heads/main" };
    else throw new Error("unexpected GitHub API request " + method + " " + url);
    return new Response(JSON.stringify(payload), { status: 200, headers: { "content-type": "application/json" } });
  };
  const store = new GitHubJsonStore({
    repository: "pasoooir/mshin-player-data",
    token: "github-token-for-unit-test-123456",
    fetchImpl: fakeFetch
  });
  const result = await store.writeMany([
    { path: "players/100001.json", value: { user_id: 100001, game_state: null } },
    { path: "players/100002.json", value: { user_id: 100002, game_state: null } },
    { path: "market/listings.json", value: { schema_version: 1, listings: [] } }
  ]);
  assert.equal(result.commit_sha, "new-commit");
  const treeCall = calls.find(call => call.url.endsWith("/git/trees"));
  assert.equal(treeCall.body.tree.length, 3);
  const commitCall = calls.find(call => call.url.endsWith("/git/commits") && call.method === "POST");
  assert.deepEqual(commitCall.body.parents, ["base-commit"]);
  assert.equal(calls.filter(call => call.url.endsWith("/git/refs/heads/main") && call.method === "PATCH").length, 1);
});

test("GitHub JSON storage rejects path traversal and duplicate paths", async () => {
  const store = new GitHubJsonStore({
    repository: "pasoooir/mshin-player-data",
    token: "github-token-for-unit-test-123456",
    fetchImpl: async () => { throw new Error("network must not be called"); }
  });
  await assert.rejects(store.writeMany([{ path: "../outside.json", value: {} }]), /invalid_json_storage_path/);
  await assert.rejects(store.writeMany([
    { path: "players/100001.json", value: {} },
    { path: "players/100001.json", value: {} }
  ]), /duplicate_json_storage_path/);
});

test("production refuses filesystem JSON storage", () => {
  assert.throws(() => createApp({
    authSecret: secret,
    nodeEnv: "production",
    jsonStore: { kind: "filesystem-json", readJson: async () => null, writeMany: async () => {} }
  }), /Production requires a dedicated private GitHub JSON repository/);
});

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
  const writes = await Promise.all([
    json(f.base + "/v1/profile", f.token(100001), "PUT", { expected_revision: 0, game_state: { coins: 1 } }),
    json(f.base + "/v1/profile", f.token(100001), "PUT", { expected_revision: 0, game_state: { coins: 999 } })
  ]);
  assert.deepEqual(writes.map(result => result.status).sort(), [200, 409]);
  assert.equal((await json(f.base + "/v1/profile", f.token(100001))).body.revision, 1);
});

test("email fields are rejected and never written to JSON", async t => {
  const f = await fixture(); t.after(f.close);
  const result = await json(f.base + "/v1/profile", f.token(100001), "PUT", {
    expected_revision: 0, game_state: { city: "A", profile: { email: "private@example.test" } }
  });
  assert.equal(result.status, 400);
  await assert.rejects(readFile(path.join(f.directory, "players", "100001.json")));
});

test("development identity returns its configured numeric player id", async t => {
  const f = await fixture(); t.after(f.close);
  const result = await json(f.base + "/v1/dev/session", null, "POST", { identity: "admin" });
  assert.equal(result.status, 200);
  assert.equal(result.body.user_id, 100001);
  assert.ok(result.body.access_token);
  const second = await json(f.base + "/v1/dev/session", null, "POST", { identity: "player2" });
  assert.equal(second.status, 200);
  assert.equal(second.body.user_id, 100002);
  assert.ok(second.body.access_token);
});

test("dev identity endpoint is unavailable when disabled or in production", async t => {
  const f = await fixture({
    devAuthEnabled: true,
    nodeEnv: "production",
    jsonStore: { kind: "github-private-json", readJson: async () => null, writeMany: async () => {} }
  }); t.after(f.close);
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
