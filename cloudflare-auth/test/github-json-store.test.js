import test from "node:test";
import assert from "node:assert/strict";
import { GitHubJsonStore } from "../src/github-json-store.js";

test("accepts only a private repository with an existing configured branch", async () => {
  const calls = [];
  const store = new GitHubJsonStore({
    repository: "pasoooir/mshin-player-data",
    token: "test-token-that-is-long-enough-for-validation",
    branch: "main",
    fetchImpl: async (url) => {
      calls.push(String(url));
      if (String(url).endsWith("/git/ref/heads/main")) {
        return Response.json({ object: { sha: "commit-sha" } });
      }
      return Response.json({ private: true });
    }
  });
  const result = await store.verifyPrivateRepository();
  assert.equal(result.private, true);
  assert.equal(result.branch, "main");
  assert.equal(calls.length, 2);
});

test("rejects a public repository before any player data access", async () => {
  let calls = 0;
  const store = new GitHubJsonStore({
    repository: "pasoooir/mshin-player-data",
    token: "test-token-that-is-long-enough-for-validation",
    fetchImpl: async () => { calls += 1; return Response.json({ private: false }); }
  });
  await assert.rejects(store.verifyPrivateRepository(), /github_json_repository_must_be_private/);
  assert.equal(calls, 1);
});

test("rejects traversal and malformed repository names", async () => {
  const store = new GitHubJsonStore({
    repository: "pasoooir/mshin-player-data",
    token: "test-token-that-is-long-enough-for-validation",
    fetchImpl: async () => { throw new Error("must_not_fetch"); }
  });
  await assert.rejects(store.readJson("../players/100001.json"), /invalid_json_storage_path/);
  assert.throws(() => new GitHubJsonStore({
    repository: "pasoooir/../public",
    token: "test-token-that-is-long-enough-for-validation"
  }), /invalid_github_json_repository/);
});
