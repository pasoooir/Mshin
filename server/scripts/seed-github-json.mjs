import { GitHubJsonStore } from "../src/json-store.mjs";

const repository = process.env.GITHUB_JSON_REPOSITORY || "";
const token = process.env.GITHUB_JSON_TOKEN || "";
const branch = process.env.GITHUB_JSON_BRANCH || "main";
if (!repository || !token) {
  throw new Error("Set GITHUB_JSON_REPOSITORY and GITHUB_JSON_TOKEN before seeding private player data.");
}

const store = new GitHubJsonStore({ repository, token, branch });
const seeds = [
  {
    path: "players/100001.json",
    value: { schema_version: 1, user_id: 100001, revision: 0, created_at: null, updated_at: null, market_account: null, game_state: null }
  },
  {
    path: "players/100002.json",
    value: { schema_version: 1, user_id: 100002, revision: 0, created_at: null, updated_at: null, market_account: null, game_state: null }
  },
  {
    path: "market/listings.json",
    value: { schema_version: 1, listings: [] }
  }
];

const missing = [];
for (const entry of seeds) {
  const existing = await store.readJson(entry.path);
  if (existing === null) missing.push(entry);
}
if (missing.length) {
  const result = await store.writeMany(missing);
  console.log("Created private JSON seed files:", result.files.join(", "));
  console.log("Git commit:", result.commit_sha);
} else {
  console.log("All player and market JSON files already exist; nothing was overwritten.");
}
