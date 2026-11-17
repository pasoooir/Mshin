function safePath(value) {
  const path = String(value || "").replace(/\\\\/g, "/");
  if (!path || path.startsWith("/") || path.split("/").some(part => !part || part === "." || part === "..")) {
    throw new Error("invalid_json_storage_path");
  }
  return path;
}
function decodeBase64(value) {
  const binary = atob(value.replace(/\\s/g, ""));
  const bytes = Uint8Array.from(binary, c => c.charCodeAt(0));
  return new TextDecoder().decode(bytes);
}
function encodeBase64(value) {
  const bytes = new TextEncoder().encode(value);
  let binary = "";
  for (let i = 0; i < bytes.length; i += 0x8000) {
    binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  }
  return btoa(binary);
}
export class GitHubJsonStore {
  constructor({ repository, token, branch = "main", fetchImpl = fetch }) {
    if (!/^[A-Za-z0-9_.-]+\\/[A-Za-z0-9_.-]+$/.test(repository || "")) throw new Error("invalid_github_json_repository");
    if (!token || token.length < 20) throw new Error("github_json_token_required");
    this.repository = repository;
    this.token = token;
    this.branch = branch;
    this.fetchImpl = fetchImpl;
    this.base = "https://api.github.com/repos/" + repository;
  }
  async request(path, options = {}) {
    const response = await this.fetchImpl(this.base + path, {
      ...options,
      headers: {
        accept: "application/vnd.github+json",
        authorization: "Bearer " + this.token,
        "x-github-api-version": "2022-11-28",
        ...(options.body ? { "content-type": "application/json" } : {}),
        ...options.headers
      }
    });
    const raw = await response.text();
    let body = {};
    try { body = raw ? JSON.parse(raw) : {}; } catch { body = { message: raw.slice(0, 200) }; }
    if (!response.ok) {
      const error = new Error("github_storage_" + response.status);
      error.status = response.status;
      error.githubMessage = String(body.message || "");
      throw error;
    }
    return body;
  }
  async verifyPrivateRepository() {
    const repo = await this.request("");
    if (repo.private !== true) throw new Error("github_json_repository_must_be_private");
    const ref = await this.request("/git/ref/heads/" + encodeURIComponent(this.branch));
    if (!ref.object?.sha) throw new Error("github_json_branch_ref_missing");
    return { private: true, branch: this.branch };
  }
  async readJson(relativePath) {
    const path = safePath(relativePath);
    try {
      const file = await this.request("/contents/" + path.split("/").map(encodeURIComponent).join("/") + "?ref=" + encodeURIComponent(this.branch));
      if (file.type !== "file" || !file.sha) throw new Error("github_json_file_invalid");
      let encoded = file.content;
      if (file.encoding !== "base64" || typeof encoded !== "string" || !encoded.trim()) {
        const blob = await this.request("/git/blobs/" + file.sha);
        if (blob.encoding !== "base64" || typeof blob.content !== "string") throw new Error("github_json_blob_invalid");
        encoded = blob.content;
      }
      return JSON.parse(decodeBase64(encoded));
    } catch (error) {
      if (error.status === 404) return null;
      throw error;
    }
  }
  async writeMany(entries) {
    if (!Array.isArray(entries) || !entries.length) throw new Error("empty_json_storage_commit");
    const seen = new Set();
    const files = entries.map(entry => {
      const path = safePath(entry.path);
      if (seen.has(path)) throw new Error("duplicate_json_storage_path");
      seen.add(path);
      return { path, content: JSON.stringify(entry.value) };
    });
    for (let attempt = 0; attempt < 3; attempt++) {
      const ref = await this.request("/git/ref/heads/" + encodeURIComponent(this.branch));
      const parentSha = ref.object?.sha;
      if (!parentSha) throw new Error("github_branch_ref_missing");
      const parent = await this.request("/git/commits/" + parentSha);
      const treeEntries = [];
      for (const file of files) {
        const blob = await this.request("/git/blobs", {
          method: "POST",
          body: JSON.stringify({ content: file.content, encoding: "utf-8" })
        });
        treeEntries.push({ path: file.path, mode: "100644", type: "blob", sha: blob.sha });
      }
      const tree = await this.request("/git/trees", {
        method: "POST",
        body: JSON.stringify({ base_tree: parent.tree.sha, tree: treeEntries })
      });
      const commit = await this.request("/git/commits", {
        method: "POST",
        body: JSON.stringify({ message: "Update Mshin player JSON data", tree: tree.sha, parents: [parentSha] })
      });
      try {
        await this.request("/git/refs/heads/" + encodeURIComponent(this.branch), {
          method: "PATCH", body: JSON.stringify({ sha: commit.sha, force: false })
        });
        return { commit_sha: commit.sha, files: files.map(file => file.path) };
      } catch (error) {
        if (![409, 422].includes(error.status) || attempt === 2) throw error;
      }
    }
    throw new Error("github_storage_commit_conflict");
  }
}
