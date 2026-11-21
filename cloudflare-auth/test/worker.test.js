import test from "node:test";
import assert from "node:assert/strict";
import { createHmac, generateKeyPairSync, sign as signBytes } from "node:crypto";
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


test("serves a server-generated login nonce without requiring a player token", async () => {
  const rows = new Map();
  const database = {
    prepare(sql) {
      return { bind(...values) { return { async run() {
        if (sql.startsWith("DELETE FROM auth_nonces WHERE expires_at")) {
          for (const [key, value] of rows) if (value <= values[0]) rows.delete(key);
          return { meta: { changes: 0 } };
        }
        if (sql.startsWith("INSERT INTO auth_nonces")) {
          rows.set(values[0], values[1]);
          return { meta: { changes: 1 } };
        }
        throw new Error("unexpected_sql");
      } }; } };
    }
  };
  const response = await worker.fetch(new Request("https://api.example/v1/auth/nonce", {
    headers: { origin: "https://pasoooir.github.io" }
  }), { IDENTITIES: database, GAME_ORIGIN: "https://pasoooir.github.io" });
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.match(body.nonce, /^[A-Za-z0-9_-]{40,60}$/);
  assert.equal(body.expires_in, 300);
  assert.equal(rows.size, 1);
});


test("completes Google OIDC nonce, signature, identity allocation and issued-session verification", async () => {
  const origin = "https://pasoooir.github.io";
  const clientId = "mshin-web-client.apps.googleusercontent.com";
  const { publicKey, privateKey } = generateKeyPairSync("rsa", { modulusLength: 2048 });
  const jwk = { ...publicKey.export({ format: "jwk" }), kid: "mshin-ci-google-key", alg: "RS256", use: "sig" };
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async url => {
    assert.match(String(url), /googleapis\\.com\\/oauth2\\/v3\\/certs/);
    return Response.json({ keys: [jwk] });
  };

  const nonces = new Map();
  const identities = new Map();
  let nextPlayerId = 100001;
  const database = {
    prepare(sql) {
      return {
        bind(...values) {
          return {
            async run() {
              if (sql.startsWith("DELETE FROM auth_nonces WHERE expires_at")) {
                let changes = 0;
                for (const [hash, expiry] of nonces) {
                  if (expiry <= values[0]) { nonces.delete(hash); changes += 1; }
                }
                return { meta: { changes } };
              }
              if (sql.startsWith("INSERT INTO auth_nonces")) {
                nonces.set(values[0], values[1]);
                return { meta: { changes: 1 } };
              }
              if (sql.startsWith("DELETE FROM auth_nonces WHERE nonce_hash")) {
                const expiry = nonces.get(values[0]);
                if (expiry && expiry > values[1]) {
                  nonces.delete(values[0]);
                  return { meta: { changes: 1 } };
                }
                return { meta: { changes: 0 } };
              }
              if (sql.startsWith("INSERT INTO player_identities")) {
                if (!identities.has(values[0])) identities.set(values[0], nextPlayerId++);
                return { meta: { changes: 1 } };
              }
              throw new Error("unexpected_sql: " + sql);
            },
            async first() {
              if (sql.startsWith("SELECT player_id FROM player_identities")) {
                const playerId = identities.get(values[0]);
                return playerId ? { player_id: playerId } : null;
              }
              throw new Error("unexpected_sql: " + sql);
            }
          };
        }
      };
    }
  };

  const createGoogleToken = (nonce, claims = {}) => {
    const now = Math.floor(Date.now() / 1000);
    const header = Buffer.from(JSON.stringify({ alg: "RS256", typ: "JWT", kid: jwk.kid })).toString("base64url");
    const payload = Buffer.from(JSON.stringify({
      iss: "https://accounts.google.com",
      aud: clientId,
      azp: clientId,
      sub: "stable-google-subject-for-ci",
      iat: now,
      exp: now + 300,
      nonce,
      ...claims
    })).toString("base64url");
    const input = header + "." + payload;
    return input + "." + signBytes("RSA-SHA256", Buffer.from(input), privateKey).toString("base64url");
  };

  try {
    const env = {
      IDENTITIES: database,
      GOOGLE_CLIENT_ID: clientId,
      AUTH_TOKEN_SECRET: secret,
      GAME_ORIGIN: origin
    };
    const nonceResponse = await worker.fetch(new Request("https://api.example/v1/auth/nonce", {
      headers: { origin }
    }), env);
    assert.equal(nonceResponse.status, 200);
    const { nonce } = await nonceResponse.json();
    assert.equal(typeof nonce, "string");

    const idToken = createGoogleToken(nonce);
    const loginResponse = await worker.fetch(new Request("https://api.example/v1/auth/google", {
      method: "POST",
      headers: { origin, "content-type": "application/json" },
      body: JSON.stringify({ id_token: idToken, nonce })
    }), env);
    assert.equal(loginResponse.status, 200);
    const login = await loginResponse.json();
    assert.equal(login.user_id, 100001);
    assert.equal(login.token_type, "Bearer");
    assert.equal(login.expires_in, 86400);
    assert.equal(typeof login.access_token, "string");

    const replayResponse = await worker.fetch(new Request("https://api.example/v1/auth/google", {
      method: "POST",
      headers: { origin, "content-type": "application/json" },
      body: JSON.stringify({ id_token: idToken, nonce })
    }), env);
    assert.equal(replayResponse.status, 401);
    assert.equal((await replayResponse.json()).error, "invalid_nonce");
    assert.equal(identities.size, 1);

    let routedPlayerId = null;
    const profileResponse = await worker.fetch(new Request("https://api.example/v1/profile", {
      headers: { origin, authorization: "Bearer " + login.access_token }
    }), {
      ...env,
      API_COORDINATOR: {
        idFromName(name) { assert.equal(name, "mshin-global-player-market-v1"); return "single-test-object"; },
        get(id) {
          assert.equal(id, "single-test-object");
          return { async fetch(request) {
            routedPlayerId = request.headers.get("x-mshin-player-id");
            assert.equal(request.headers.get("authorization"), null);
            return Response.json({ user_id: Number(routedPlayerId), revision: 0 });
          }};
        }
      }
    });
    assert.equal(profileResponse.status, 200);
    assert.equal(routedPlayerId, "100001");
    assert.deepEqual(await profileResponse.json(), { user_id: 100001, revision: 0 });

    const wrongAudienceNonceResponse = await worker.fetch(new Request("https://api.example/v1/auth/nonce", {
      headers: { origin }
    }), env);
    const wrongAudienceNonce = (await wrongAudienceNonceResponse.json()).nonce;
    const wrongAudienceResponse = await worker.fetch(new Request("https://api.example/v1/auth/google", {
      method: "POST",
      headers: { origin, "content-type": "application/json" },
      body: JSON.stringify({
        id_token: createGoogleToken(wrongAudienceNonce, { aud: "another-client.apps.googleusercontent.com" }),
        nonce: wrongAudienceNonce
      })
    }), env);
    assert.equal(wrongAudienceResponse.status, 401);
    assert.equal((await wrongAudienceResponse.json()).error, "invalid_google_audience");
  } finally {
    globalThis.fetch = originalFetch;
  }
});
