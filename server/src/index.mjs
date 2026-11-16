import { createServer } from "node:http";
import { createHmac, timingSafeEqual, randomBytes } from "node:crypto";
import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import path from "node:path";
import { handleMarketRequest } from "./market.mjs";

const MAX_BODY_BYTES = 4 * 1024 * 1024;
const TOKEN_ISSUER = "mshin-auth";
const TOKEN_AUDIENCE = "mshin-json-api";

function encode(value) {
  return Buffer.from(JSON.stringify(value)).toString("base64url");
}

export function signAccessToken(playerId, secret, now = Math.floor(Date.now() / 1000)) {
  const header = encode({ alg: "HS256", typ: "JWT" });
  const payload = encode({
    iss: TOKEN_ISSUER,
    aud: TOKEN_AUDIENCE,
    sub: String(playerId),
    player_id: playerId,
    iat: now,
    exp: now + 900
  });
  const input = header + "." + payload;
  const signature = createHmac("sha256", secret).update(input).digest("base64url");
  return input + "." + signature;
}

function verifyAccessToken(token, secret, now = Math.floor(Date.now() / 1000)) {
  if (typeof token !== "string" || token.length > 4096) return null;
  const parts = token.split(".");
  if (parts.length !== 3) return null;
  const input = parts[0] + "." + parts[1];
  const expected = createHmac("sha256", secret).update(input).digest();
  let actual;
  try { actual = Buffer.from(parts[2], "base64url"); } catch { return null; }
  if (actual.length !== expected.length || !timingSafeEqual(actual, expected)) return null;
  try {
    const header = JSON.parse(Buffer.from(parts[0], "base64url").toString("utf8"));
    const claims = JSON.parse(Buffer.from(parts[1], "base64url").toString("utf8"));
    const id = Number(claims.player_id);
    if (header.alg !== "HS256" || claims.iss !== TOKEN_ISSUER || claims.aud !== TOKEN_AUDIENCE) return null;
    if (!Number.isSafeInteger(id) || id < 1 || claims.sub !== String(id)) return null;
    if (!Number.isInteger(claims.iat) || !Number.isInteger(claims.exp) || claims.iat > now + 30 || claims.exp <= now || claims.exp <= claims.iat || claims.exp - claims.iat > 86400) return null;
    return { playerId: id };
  } catch { return null; }
}

function containsForbiddenEmailField(value) {
  if (Array.isArray(value)) return value.some(containsForbiddenEmailField);
  if (!value || typeof value !== "object") return false;
  for (const [key, child] of Object.entries(value)) {
    if (/^(email|email_address|google_email)$/i.test(key)) return true;
    if (containsForbiddenEmailField(child)) return true;
  }
  return false;
}

async function readJsonBody(request) {
  const chunks = [];
  let size = 0;
  for await (const chunk of request) {
    size += chunk.length;
    if (size > MAX_BODY_BYTES) throw Object.assign(new Error("payload_too_large"), { status: 413 });
    chunks.push(chunk);
  }
  if (!size) return {};
  try {
    const value = JSON.parse(Buffer.concat(chunks).toString("utf8"));
    if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error("invalid_json_object");
    return value;
  } catch {
    throw Object.assign(new Error("invalid_json"), { status: 400 });
  }
}

function send(response, status, payload, extraHeaders = {}) {
  response.writeHead(status, {
    "content-type": "application/json; charset=utf-8",
    "cache-control": "no-store",
    "x-content-type-options": "nosniff",
    ...extraHeaders
  });
  response.end(JSON.stringify(payload));
}

function parseDevIdentities(value) {
  const source = value || "admin:100001,player2:100002";
  const identities = new Map();
  for (const entry of source.split(",")) {
    const [name, rawId] = entry.trim().split(":");
    const id = Number(rawId);
    if (name && Number.isSafeInteger(id) && id > 0) identities.set(name, id);
  }
  return identities;
}

export function createApp({
  dataDir = process.env.MSHIN_DATA_DIR || "./data",
  authSecret = process.env.AUTH_TOKEN_SECRET || "",
  devAuthEnabled = process.env.DEV_AUTH_ENABLED === "true",
  nodeEnv = process.env.NODE_ENV || "development",
  devIdentities = parseDevIdentities(process.env.DEV_IDENTITIES),
  allowedOrigins = (process.env.ALLOWED_ORIGINS || "https://pasoooir.github.io").split(",").map(x => x.trim()).filter(Boolean)
} = {}) {
  if (authSecret.length < 32) throw new Error("AUTH_TOKEN_SECRET must contain at least 32 characters");
  const playersDir = path.resolve(dataDir, "players");
  const locks = new Map();

  async function withPlayerLock(playerId, operation) {
    const previous = locks.get(playerId) || Promise.resolve();
    let release;
    const current = new Promise(resolve => { release = resolve; });
    locks.set(playerId, current);
    await previous;
    try { return await operation(); }
    finally {
      release();
      if (locks.get(playerId) === current) locks.delete(playerId);
    }
  }

  function profilePath(playerId) {
    return path.join(playersDir, String(playerId) + ".json");
  }

  async function readProfile(playerId) {
    try {
      const text = await readFile(profilePath(playerId), "utf8");
      const profile = JSON.parse(text);
      if (profile.user_id !== playerId || containsForbiddenEmailField(profile)) {
        throw new Error("stored_profile_invalid");
      }
      return profile;
    } catch (error) {
      if (error.code !== "ENOENT") throw error;
      return {
        schema_version: 1,
        user_id: playerId,
        revision: 0,
        created_at: null,
        updated_at: null,
        game_state: null
      };
    }
  }

  async function writeProfile(playerId, profile) {
    await mkdir(playersDir, { recursive: true });
    const target = profilePath(playerId);
    const temporary = target + "." + process.pid + "." + randomBytes(6).toString("hex") + ".tmp";
    await writeFile(temporary, JSON.stringify(profile), { encoding: "utf8", flag: "wx", mode: 0o600 });
    await rename(temporary, target);
  }

  const server = createServer(async (request, response) => {
    const origin = request.headers.origin;
    if (origin && allowedOrigins.includes(origin)) {
      response.setHeader("access-control-allow-origin", origin);
      response.setHeader("vary", "Origin");
      response.setHeader("access-control-allow-headers", "authorization, content-type, if-match");
      response.setHeader("access-control-allow-methods", "GET, PUT, POST, OPTIONS");
    } else if (origin) {
      send(response, 403, { error: "origin_not_allowed" });
      return;
    }
    if (request.method === "OPTIONS") {
      response.writeHead(204);
      response.end();
      return;
    }

    const url = new URL(request.url, "http://localhost");
    if (request.method === "GET" && url.pathname === "/healthz") {
      send(response, 200, { ok: true, service: "mshin-json-profile-service", storage: "filesystem-json" });
      return;
    }

    if (request.method === "POST" && url.pathname === "/v1/dev/session") {
      if (!devAuthEnabled || nodeEnv === "production") {
        send(response, 404, { error: "not_found" });
        return;
      }
      try {
        const body = await readJsonBody(request);
        const identity = String(body.identity || "");
        const playerId = devIdentities.get(identity);
        if (!playerId) {
          send(response, 401, { error: "unknown_dev_identity" });
          return;
        }
        send(response, 200, {
          user_id: playerId,
          access_token: signAccessToken(playerId, authSecret),
          token_type: "Bearer",
          expires_in: 900,
          identity
        });
      } catch (error) {
        send(response, error.status || 400, { error: error.message || "bad_request" });
      }
      return;
    }

    if (url.pathname === "/v1/market" || url.pathname.startsWith("/v1/market/")) {
      const authorization = request.headers.authorization || "";
      const match = authorization.match(/^Bearer\s+(.+)$/i);
      const session = match ? verifyAccessToken(match[1], authSecret) : null;
      if (!session) {
        send(response, 401, { error: "unauthorized" });
        return;
      }
      await handleMarketRequest({
        request, response, url, session, dataDir, readProfile, writeProfile,
        withPlayerLock, readJsonBody, send
      });
      return;
    }

    if (url.pathname === "/v1/profile" && (request.method === "GET" || request.method === "PUT")) {
      const authorization = request.headers.authorization || "";
      const match = authorization.match(/^Bearer\s+(.+)$/i);
      const session = match ? verifyAccessToken(match[1], authSecret) : null;
      if (!session) {
        send(response, 401, { error: "unauthorized" });
        return;
      }
      const playerId = session.playerId;
      if (request.method === "GET") {
        try {
          const profile = await readProfile(playerId);
          send(response, 200, profile, { etag: '"' + profile.revision + '"' });
        } catch {
          send(response, 500, { error: "profile_read_failed" });
        }
        return;
      }
      try {
        const body = await readJsonBody(request);
        if (!Number.isSafeInteger(body.expected_revision) || body.expected_revision < 0) {
          send(response, 400, { error: "expected_revision_required" });
          return;
        }
        if (!body.game_state || typeof body.game_state !== "object" || Array.isArray(body.game_state)) {
          send(response, 400, { error: "game_state_must_be_object" });
          return;
        }
        if (containsForbiddenEmailField(body.game_state)) {
          send(response, 400, { error: "email_fields_are_forbidden" });
          return;
        }
        const result = await withPlayerLock(0, async () => {
          const current = await readProfile(playerId);
          if (body.expected_revision !== current.revision) {
            return { conflict: true, revision: current.revision };
          }
          const now = new Date().toISOString();
          const incomingState = structuredClone(body.game_state);
          let marketAccount = current.market_account;
          if (marketAccount && typeof marketAccount === "object") {
            incomingState.economy ??= {};
            incomingState.economy.simoleons = marketAccount.simoleons;
          } else {
            const initialBalance = Number(incomingState.economy?.simoleons);
            marketAccount = {
              simoleons: Number.isSafeInteger(initialBalance) && initialBalance >= 0 ? initialBalance : 0
            };
          }
          const next = {
            schema_version: 1,
            user_id: playerId,
            revision: current.revision + 1,
            created_at: current.created_at || now,
            updated_at: now,
            market_account: marketAccount,
            game_state: incomingState
          };
          await writeProfile(playerId, next);
          return { profile: next };
        });
        if (result.conflict) {
          send(response, 409, { error: "revision_conflict", revision: result.revision });
          return;
        }
        send(response, 200, result.profile, { etag: '"' + result.profile.revision + '"' });
      } catch (error) {
        send(response, error.status || 500, { error: error.status ? error.message : "profile_write_failed" });
      }
      return;
    }

    send(response, 404, { error: "not_found" });
  });

  return server;
}

if (import.meta.url === new URL(process.argv[1] || "", "file:").href) {
  const port = Number(process.env.PORT || 8788);
  const server = createApp();
  server.listen(port, "0.0.0.0", () => {
    console.log("[Mshin JSON API] listening on " + port);
    console.log("[Mshin JSON API] data directory: " + path.resolve(process.env.MSHIN_DATA_DIR || "./data"));
    console.log("[Mshin JSON API] development auth: " + (process.env.DEV_AUTH_ENABLED === "true" && process.env.NODE_ENV !== "production" ? "enabled" : "disabled"));
  });
}
