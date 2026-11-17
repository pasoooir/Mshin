import test from "node:test";
import assert from "node:assert/strict";
import { createHmac } from "node:crypto";
import worker, { createLoginNonce, consumeLoginNonce } from "../src/worker.js";

const secret = "mshin-worker-test-secret-at-least-32-characters";
function tokenFor(playerId = 100001) {
  const now = Math.floor(Date.now() / 1000);
  const header = Buffer.from(JSON.stringify({ alg: "HS256", typ: "JWT" })).toString("base64url");
  const payload = Buffer.from(JSON.stringify({
    iss: "mshin-auth", aud: "mshin-json-api", sub: String(playerId),
    player_id: playerId, iat: now, exp: now + 900
  })).toString("base64url");
  const input = header + "." + payload;
  return input + "." + createHmac("sha256", secret).update(input).digest("base64url");
}

test("forwards a valid bearer session to the serialized API coordinator", async () => {
  let forwardedPlayerId = null;
  const env = {
    AUTH_TOKEN_SECRET: secret,
    GAME_ORIGIN: "https://pasoooir.github.io",
    API_COORDINATOR: {
      idFromName(name) { assert.equal(name, "mshin-global-player-market-v1"); return "singleton"; },
      get(id) {
        assert.equal(id, "singleton");
        return { async fetch(request) {
          forwardedPlayerId = request.headers.get("x-mshin-player-id");
          assert.equal(request.headers.get("authorization"), null);
          return Response.json({ user_id: Number(forwardedPlayerId), revision: 0 });
        }};
      }
    }
  };
  const response = await worker.fetch(new Request("https://api.example/v1/profile", {
    headers: { origin: "https://pasoooir.github.io", authorization: "Bearer " + tokenFor(100002) }
  }), env);
  assert.equal(response.status, 200);
  assert.equal(forwardedPlayerId, "100002");
  assert.deepEqual(await response.json(), { user_id: 100002, revision: 0 });
});

test("rejects missing or forged bearer tokens before reaching the coordinator", async () => {
  let calls = 0;
  const env = {
    AUTH_TOKEN_SECRET: secret,
    API_COORDINATOR: { idFromName() { calls += 1; return "id"; }, get() { calls += 1; return { fetch() { calls += 1; } }; } }
  };
  const response = await worker.fetch(new Request("https://api.example/v1/profile", {
    headers: { authorization: "Bearer forged" }
  }), env);
  assert.equal(response.status, 401);
  assert.equal(calls, 0);
});

test("rejects browser origins outside the configured GitHub Pages origin", async () => {
  const response = await worker.fetch(new Request("https://api.example/v1/profile", {
    headers: { origin: "https://attacker.example", authorization: "Bearer " + tokenFor() }
  }), { AUTH_TOKEN_SECRET: secret });
  assert.equal(response.status, 403);
  assert.deepEqual(await response.json(), { error: "origin_not_allowed" });
});


test("issues cryptographically random login nonces and consumes each nonce only once", async () => {
  const rows = new Map();
  const database = {
    prepare(sql) {
      return {
        bind(...values) {
          return {
            async run() {
              if (sql.startsWith("DELETE FROM auth_nonces WHERE expires_at")) {
                let changes = 0;
                for (const [hash, row] of rows) {
                  if (row.expires_at <= values[0]) { rows.delete(hash); changes += 1; }
                }
                return { meta: { changes } };
              }
              if (sql.startsWith("INSERT INTO auth_nonces")) {
                rows.set(values[0], { expires_at: values[1] });
                return { meta: { changes: 1 } };
              }
              if (sql.startsWith("DELETE FROM auth_nonces WHERE nonce_hash")) {
                const row = rows.get(values[0]);
                if (row && row.expires_at > values[1]) {
                  rows.delete(values[0]);
                  return { meta: { changes: 1 } };
                }
                return { meta: { changes: 0 } };
              }
              throw new Error("unexpected_sql");
            }
          };
        }
      };
    }
  };
  const nonce = await createLoginNonce(database);
  assert.match(nonce, /^[A-Za-z0-9_-]{40,60}$/);
  assert.equal(await consumeLoginNonce(database, nonce), true);
  assert.equal(await consumeLoginNonce(database, nonce), false);
});
