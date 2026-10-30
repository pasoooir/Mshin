const API_VERSION = "1";
const GAME_VERSION = "0.4.0";
const DEFAULT_ORIGINS = [
  "https://pasoooir.github.io",
  "http://localhost:8080",
  "http://127.0.0.1:8080",
];

const WORLDS = [
  { id: "green-valley", name: "Green Valley", stages: 5 },
  { id: "desert-storm", name: "Desert Storm", stages: 5 },
  { id: "frozen-world", name: "Frozen World", stages: 5 },
  { id: "tropical-island", name: "Tropical Island", stages: 5 },
  { id: "neon-city", name: "Neon City", stages: 5 },
  { id: "industrial-zone", name: "Industrial Zone", stages: 5 },
  { id: "mountain-rush", name: "Mountain Rush", stages: 5 },
  { id: "ancient-world", name: "Ancient World", stages: 5 },
  { id: "space-racing", name: "Space Racing", stages: 5 },
  { id: "ultimate-championship", name: "Ultimate Championship", stages: 5 },
];

function allowedOrigins(env) {
  const configured = typeof env?.ALLOWED_ORIGINS === "string"
    ? env.ALLOWED_ORIGINS.split(",").map((value) => value.trim()).filter(Boolean)
    : [];
  return new Set([...DEFAULT_ORIGINS, ...configured]);
}

function responseHeaders(origin, env) {
  const headers = new Headers({
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "no-referrer",
    "Cross-Origin-Resource-Policy": "same-site",
    "Vary": "Origin",
  });
  if (origin && allowedOrigins(env).has(origin)) {
    headers.set("Access-Control-Allow-Origin", origin);
    headers.set("Access-Control-Allow-Methods", "GET, OPTIONS");
    headers.set("Access-Control-Allow-Headers", "Content-Type");
    headers.set("Access-Control-Max-Age", "86400");
  }
  return headers;
}

function json(data, status, origin, env) {
  return new Response(JSON.stringify(data), {
    status,
    headers: responseHeaders(origin, env),
  });
}

export default {
  async fetch(request, env = {}) {
    const url = new URL(request.url);
    const origin = request.headers.get("Origin");

    if (request.method === "OPTIONS") {
      if (origin && !allowedOrigins(env).has(origin)) {
        return json({ error: "origin_not_allowed" }, 403, null, env);
      }
      return new Response(null, { status: 204, headers: responseHeaders(origin, env) });
    }

    if (request.method !== "GET") {
      return json({ error: "method_not_allowed" }, 405, origin, env);
    }

    if (origin && !allowedOrigins(env).has(origin)) {
      return json({ error: "origin_not_allowed" }, 403, null, env);
    }

    if (url.pathname === "/api/v1/health") {
      return json({ ok: true, service: "mshin-game-api", apiVersion: API_VERSION, gameVersion: GAME_VERSION }, 200, origin, env);
    }

    if (url.pathname === "/api/v1/config") {
      return json({
        apiVersion: API_VERSION,
        gameVersion: GAME_VERSION,
        storage: { mode: "local-first", serverPersistence: false },
        worlds: WORLDS,
        totalStages: WORLDS.reduce((sum, world) => sum + world.stages, 0),
      }, 200, origin, env);
    }

    return json({ error: "not_found" }, 404, origin, env);
  },
};
