import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import path from "node:path";
import { randomBytes } from "node:crypto";

function safePath(value) {
  const normalized = String(value || "").replace(/\\/g, "/");
  if (!normalized || normalized.startsWith("/") || normalized.split("/").some(part => !part || part === "." || part === "..")) {
    throw new Error("invalid_json_storage_path");
  }
  return normalized;
}

export function createFilesystemJsonStore(dataDir) {
  const root = path.resolve(dataDir);
  return {
    kind: "filesystem-json",
    async readJson(relativePath) {
      try {
        return JSON.parse(await readFile(path.join(root, safePath(relativePath)), "utf8"));
      } catch (error) {
        if (error.code === "ENOENT") return null;
        throw error;
      }
    },
    async writeMany(entries) {
      const staged = [];
      try {
        for (const entry of entries) {
          const target = path.join(root, safePath(entry.path));
          await mkdir(path.dirname(target), { recursive: true });
          const temporary = target + "." + process.pid + "." + randomBytes(6).toString("hex") + ".tmp";
          await writeFile(temporary, JSON.stringify(entry.value), { encoding: "utf8", flag: "wx", mode: 0o600 });
          staged.push({ target, temporary });
        }
        for (const item of staged) await rename(item.temporary, item.target);
      } catch (error) {
        for (const item of staged) {
          try { await import("node:fs/promises").then(fs => fs.unlink(item.temporary)); } catch {}
        }
        throw error;
      }
    }
  };
}

export class GitHubJsonStore {
  constructor({
    repository,
    token,
    branch = "main",
    apiBase = "https://api.github.com",
    fetchImpl = globalThis.fetch,
    maxRetries = 3
  }) {
    if (!/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(repository || "")) throw new Error("GITHUB_JSON_REPOSITORY must be owner/repo");
    if (!token || token.length < 20) throw new Error("GITHUB_JSON_TOKEN is required");
    if (typeof fetchImpl !== "function") throw new Error("fetch is unavailable");
    this.repository = repository;
    this.token = token;
    this.branch = branch;
    this.apiBase = apiBase.replace(/\/$/, "");
    this.fetchImpl = fetchImpl;
    this.maxRetries = maxRetries;
    this.kind = "github-private-json";
  }

  async request(endpoint, options = {}) {
    const response = await this.fetchImpl(this.apiBase + endpoint, {
      ...options,
      headers: {
        accept: "application/vnd.github+json",
        authorization: "Bearer " + this.token,
        "x-github-api-version": "2022-11-28",
        ...(options.body ? { "content-type": "application/json" } : {}),
        ...options.headers
      }
    });
    const text = await response.text();
    let body = {};
    try { body = text ? JSON.parse(text) : {}; } catch { body = { message: text.slice(0, 300) }; }
    if (!response.ok) {
      const error = new Error("github_storage_" + response.status + ": " + String(body.message || "request_failed"));
      error.status = response.status;
      error.github = body;
      throw error;
    }
    return body;
  }

  async readJson(relativePath) {
    const filePath = safePath(relativePath);
    try {
      const result = await this.request(
        "/repos/" + this.repository + "/contents/" + filePath.split("/").map(encodeURIComponent).join("/") +
        "?ref=" + encodeURIComponent(this.branch)
      );
      if (result.type !== "file" || typeof result.sha !== "string") {
        throw new Error("github_json_file_invalid");
      }
      let encoded = result.content;
      if (result.encoding !== "base64" || typeof encoded !== "string" || !encoded.length) {
        // Contents API omits inline content for larger files; fetch the blob by SHA.
        const blob = await this.request("/repos/" + this.repository + "/git/blobs/" + result.sha);
        if (blob.encoding !== "base64" || typeof blob.content !== "string") {
          throw new Error("github_json_blob_invalid");
        }
        encoded = blob.content;
      }
      return JSON.parse(Buffer.from(encoded.replace(/\\n/g, ""), "base64").toString("utf8"));
    } catch (error) {
      if (error.status === 404) return null;
      throw error;
    }
  }

  async writeMany(entries) {
    if (!Array.isArray(entries) || entries.length < 1) throw new Error("empty_json_storage_commit");
    const unique = new Set();
    const files = entries.map(entry => {
      const filePath = safePath(entry.path);
      if (unique.has(filePath)) throw new Error("duplicate_json_storage_path");
      unique.add(filePath);
      return { path: filePath, content: JSON.stringify(entry.value) };
    });

    for (let attempt = 0; attempt < this.maxRetries; attempt += 1) {
      const ref = await this.request("/repos/" + this.repository + "/git/ref/heads/" + encodeURIComponent(this.branch));
      const parentSha = ref.object?.sha;
      if (!parentSha) throw new Error("github_branch_ref_missing");
      const parent = await this.request("/repos/" + this.repository + "/git/commits/" + parentSha);
      const blobs = [];
      for (const file of files) {
        const blob = await this.request("/repos/" + this.repository + "/git/blobs", {
          method: "POST",
          body: JSON.stringify({ content: file.content, encoding: "utf-8" })
        });
        blobs.push({ path: file.path, mode: "100644", type: "blob", sha: blob.sha });
      }
      const tree = await this.request("/repos/" + this.repository + "/git/trees", {
        method: "POST",
        body: JSON.stringify({ base_tree: parent.tree.sha, tree: blobs })
      });
      const commit = await this.request("/repos/" + this.repository + "/git/commits", {
        method: "POST",
        body: JSON.stringify({
          message: "Update Mshin player JSON data",
          tree: tree.sha,
          parents: [parentSha]
        })
      });
      try {
        await this.request("/repos/" + this.repository + "/git/refs/heads/" + encodeURIComponent(this.branch), {
          method: "PATCH",
          body: JSON.stringify({ sha: commit.sha, force: false })
        });
        return { commit_sha: commit.sha, files: files.map(file => file.path) };
      } catch (error) {
        if (![409, 422].includes(error.status) || attempt + 1 >= this.maxRetries) throw error;
      }
    }
    throw new Error("github_storage_commit_conflict");
  }
}
