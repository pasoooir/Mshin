import { MshinApiCoordinator } from "./api.js";

const GOOGLE_ISSUERS = new Set(["accounts.google.com", "https://accounts.google.com"]);
const TOKEN_ISSUER = "mshin-auth";
const TOKEN_AUDIENCE = "mshin-json-api";
const encoder = new TextEncoder();
let jwksCache = null;
let jwksExpiresAt = 0;

function json(data, status = 200, origin = "") {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
      "x-content-type-options": "nosniff",
      ...(origin ? { "access-control-allow-origin": origin, "vary": "Origin" } : {})
    }
  });
}
function decodeBase64Url(value) {
  const padded = value.replace(/-/g, "+").replace(/_/g, "/") + "=".repeat((4 - value.length % 4) % 4);
  const binary = atob(padded);
  return Uint8Array.from(binary, character => character.charCodeAt(0));
}
function decodeJsonPart(value) {
  return JSON.parse(new TextDecoder().decode(decodeBase64Url(value)));
}
async function getGoogleKeys() {
  if (jwksCache && Date.now() < jwksExpiresAt) return jwksCache;
  const response = await fetch("https://www.googleapis.com/oauth2/v3/certs", { cf: { cacheTtl: 300, cacheEverything: true } });
  if (!response.ok) throw new Error("google_keys_unavailable");
  const payload = await response.json();
  jwksCache = payload.keys || [];
  jwksExpiresAt = Date.now() + 5 * 60 * 1000;
  return jwksCache;
}
async function verifyGoogleIdToken(idToken, expectedAudience, expectedNonce) {
  if (typeof idToken !== "string" || idToken.length > 12000) throw new Error("invalid_id_token");
  const parts = idToken.split(".");
  if (parts.length !== 3) throw new Error("invalid_id_token");
  const header = decodeJsonPart(parts[0]);
  const claims = decodeJsonPart(parts[1]);
  if (header.alg !== "RS256" || !header.kid) throw new Error("invalid_google_signature");
  if (!GOOGLE_ISSUERS.has(claims.iss) || claims.aud !== expectedAudience || (claims.azp && claims.azp !== expectedAudience)) throw new Error("invalid_google_audience");
  const now = Math.floor(Date.now() / 1000);
  if (!Number.isInteger(claims.exp) || !Number.isInteger(claims.iat) || claims.exp <= now || claims.iat > now + 60) throw new Error("expired_google_token");
  if (typeof claims.sub !== "string" || !claims.sub || claims.sub.length > 255) throw new Error("invalid_google_subject");
  if (!expectedNonce || claims.nonce !== expectedNonce) throw new Error("invalid_nonce");
  const jwk = (await getGoogleKeys()).find(key => key.kid === header.kid && key.kty === "RSA");
  if (!jwk) {
    jwksCache = null;
    throw new Error("google_signing_key_not_found");
  }
  const publicKey = await crypto.subtle.importKey("jwk", jwk, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["verify"]);
  const valid = await crypto.subtle.verify({ name: "RSASSA-PKCS1-v1_5" }, publicKey, decodeBase64Url(parts[2]), encoder.encode(parts[0] + "." + parts[1]));
  if (!valid) throw new Error("invalid_google_signature");
  return claims.sub;
}
function base64UrlBytes(bytes) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}
async function hashHex(value) {
  const digest = await crypto.subtle.digest("SHA-256", encoder.encode(value));
  return Array.from(new Uint8Array(digest), byte => byte.toString(16).padStart(2, "0")).join("");
}
async function createLoginNonce(database) {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  const nonce = base64UrlBytes(bytes);
  const now = Math.floor(Date.now() / 1000);
  const expiresAt = now + 300;
  await database.prepare("DELETE FROM auth_nonces WHERE expires_at <= ?").bind(now).run();
  await database.prepare("INSERT INTO auth_nonces (nonce_hash, expires_at) VALUES (?, ?)").bind(await hashHex(nonce), expiresAt).run();
  return nonce;
}
async function consumeLoginNonce(database, nonce) {
  if (typeof nonce !== "string" || nonce.length < 32 || nonce.length > 128) return false;
  const result = await database.prepare("DELETE FROM auth_nonces WHERE nonce_hash = ? AND expires_at > ?").bind(await hashHex(nonce), Math.floor(Date.now() / 1000)).run();
  return Number(result?.meta?.changes || 0) === 1;
}

async function issueGameToken(playerId, secret) {
  const now = Math.floor(Date.now() / 1000);
  const header = base64UrlBytes(encoder.encode(JSON.stringify({ alg: "HS256", typ: "JWT" })));
  const payload = base64UrlBytes(encoder.encode(JSON.stringify({ iss: TOKEN_ISSUER, aud: TOKEN_AUDIENCE, sub: String(playerId), player_id: playerId, iat: now, exp: now + 86400 })));
  const input = header + "." + payload;
  const key = await crypto.subtle.importKey("raw", encoder.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const signature = await crypto.subtle.sign("HMAC", key, encoder.encode(input));
  return input + "." + base64UrlBytes(new Uint8Array(signature));
}
async function verifyGameToken(token, secret) {
  if (typeof token !== "string" || token.length > 4096) return null;
  const parts = token.split(".");
  if (parts.length !== 3) return null;
  try {
    const key = await crypto.subtle.importKey("raw", encoder.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["verify"]);
    const valid = await crypto.subtle.verify("HMAC", key, decodeBase64Url(parts[2]), encoder.encode(parts[0] + "." + parts[1]));
    if (!valid) return null;
    const header = decodeJsonPart(parts[0]);
    const claims = decodeJsonPart(parts[1]);
    const playerId = Number(claims.player_id);
    const now = Math.floor(Date.now() / 1000);
    if (header.alg !== "HS256" || claims.iss !== TOKEN_ISSUER || claims.aud !== TOKEN_AUDIENCE ||
        !Number.isSafeInteger(playerId) || playerId < 1 || claims.sub !== String(playerId) ||
        !Number.isInteger(claims.iat) || !Number.isInteger(claims.exp) ||
        claims.iat > now + 30 || claims.exp <= now || claims.exp <= claims.iat || claims.exp - claims.iat > 86400) return null;
    return playerId;
  } catch { return null; }
}

export default {
  async fetch(request, env) {
    const origin = request.headers.get("Origin") || "";
    const allowedOrigin = env.GAME_ORIGIN || "https://pasoooir.github.io";
    if (origin && origin !== allowedOrigin) return json({ error: "origin_not_allowed" }, 403);
    if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: {
      "access-control-allow-origin": allowedOrigin,
      "access-control-allow-methods": "GET, PUT, POST, OPTIONS",
      "access-control-allow-headers": "authorization, content-type, if-match",
      "access-control-max-age": "86400",
      "vary": "Origin"
    }});
    const url = new URL(request.url);
    if (request.method === "GET" && url.pathname === "/healthz") {
      return json({ ok: true, service: "mshin-cloudflare-json-api" }, 200, allowedOrigin);
    }
    if (url.pathname.startsWith("/v1/") && url.pathname !== "/v1/auth/google" && url.pathname !== "/v1/auth/nonce") {
      if (!env.AUTH_TOKEN_SECRET || env.AUTH_TOKEN_SECRET.length < 32 || !env.API_COORDINATOR) {
        return json({ error: "api_service_not_configured" }, 503, allowedOrigin);
      }
      const authorization = request.headers.get("Authorization") || "";
      const parts = authorization.trim().split(" ");
      const token = parts.length === 2 && parts[0].toLowerCase() === "bearer" ? parts[1] : "";
      const playerId = token ? await verifyGameToken(token, env.AUTH_TOKEN_SECRET) : null;
      if (!playerId) return json({ error: "unauthorized" }, 401, allowedOrigin);
      const id = env.API_COORDINATOR.idFromName("mshin-global-player-market-v1");
      const stub = env.API_COORDINATOR.get(id);
      const headers = new Headers(request.headers);
      headers.set("x-mshin-player-id", String(playerId));
      headers.delete("authorization");
      const result = await stub.fetch(new Request(request, { headers }));
      const responseHeaders = new Headers(result.headers);
      responseHeaders.set("access-control-allow-origin", allowedOrigin);
      responseHeaders.set("vary", "Origin");
      return new Response(result.body, { status: result.status, headers: responseHeaders });
    }
    if (request.method === "GET" && url.pathname === "/v1/auth/nonce") {
      if (!env.IDENTITIES) return json({ error: "auth_service_not_configured" }, 503, allowedOrigin);
      try {
        return json({ nonce: await createLoginNonce(env.IDENTITIES), expires_in: 300 }, 200, allowedOrigin);
      } catch {
        return json({ error: "nonce_service_unavailable" }, 503, allowedOrigin);
      }
    }
    if (request.method !== "POST" || url.pathname !== "/v1/auth/google") return json({ error: "not_found" }, 404);
    if (!env.IDENTITIES || !env.GOOGLE_CLIENT_ID || !env.AUTH_TOKEN_SECRET || env.AUTH_TOKEN_SECRET.length < 32) {
      return json({ error: "auth_service_not_configured" }, 503, allowedOrigin);
    }
    try {
      const body = await request.json();
      const googleSub = await verifyGoogleIdToken(body.id_token, env.GOOGLE_CLIENT_ID, body.nonce);
      const digest = await crypto.subtle.digest("SHA-256", encoder.encode(googleSub));
      const subjectHash = Array.from(new Uint8Array(digest), byte => byte.toString(16).padStart(2, "0")).join("");
      await env.IDENTITIES.prepare("INSERT INTO player_identities (google_subject_hash) VALUES (?) ON CONFLICT(google_subject_hash) DO NOTHING").bind(subjectHash).run();
      const identity = await env.IDENTITIES.prepare("SELECT player_id FROM player_identities WHERE google_subject_hash = ? LIMIT 1").bind(subjectHash).first();
      const playerId = Number(identity?.player_id);
      if (!Number.isSafeInteger(playerId) || playerId < 1) throw new Error("identity_allocation_failed");
      const accessToken = await issueGameToken(playerId, env.AUTH_TOKEN_SECRET);
      return json({ user_id: playerId, access_token: accessToken, token_type: "Bearer", expires_in: 86400 }, 200, allowedOrigin);
    } catch (error) {
      const reason = String(error?.message || "authentication_failed");
      const status = reason === "invalid_nonce" || reason.startsWith("invalid_") || reason.startsWith("expired_") ? 401 : 503;
      return json({ error: status === 401 ? reason : "authentication_unavailable" }, status, allowedOrigin);
    }
  }
};


export { MshinApiCoordinator, createLoginNonce, consumeLoginNonce };
