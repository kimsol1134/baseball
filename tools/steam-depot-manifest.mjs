import { createHash } from "node:crypto";
import { existsSync, lstatSync, readFileSync, readdirSync } from "node:fs";
import path from "node:path";

function depotFiles(directory, prefix = "") {
  const files = [];
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const relative = path.join(prefix, entry.name);
    const absolute = path.join(directory, entry.name);
    if (entry.isSymbolicLink()) throw new Error(`Depot must not contain symbolic links: ${relative}`);
    if (entry.isDirectory()) files.push(...depotFiles(absolute, relative));
    else if (entry.isFile() && relative !== "BUILD_MANIFEST.json") {
      files.push(relative.split(path.sep).join("/"));
    }
  }
  return files.sort();
}

export function validateSteamDepot(depotDirectory, expectedEdition) {
  const root = path.resolve(depotDirectory);
  const manifestPath = path.join(root, "BUILD_MANIFEST.json");
  if (!existsSync(manifestPath)) throw new Error(`Missing depot manifest: ${manifestPath}`);
  const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
  if (manifest.format !== "DiamondSoulSteamDepot" || manifest.schemaVersion !== 1 || !Array.isArray(manifest.files)) {
    throw new Error("Depot manifest has an unsupported format");
  }
  if (expectedEdition && manifest.edition !== expectedEdition) {
    throw new Error(`Depot edition mismatch: expected ${expectedEdition}, received ${manifest.edition}`);
  }

  const declared = new Set();
  for (const file of manifest.files) {
    if (typeof file.path !== "string" || file.path.includes("\\") || file.path.split("/").some((part) => !part || part === "." || part === "..")) {
      throw new Error(`Unsafe depot manifest path: ${String(file.path)}`);
    }
    if (declared.has(file.path)) throw new Error(`Duplicate depot manifest path: ${file.path}`);
    declared.add(file.path);
    const absolute = path.resolve(root, ...file.path.split("/"));
    if (!absolute.startsWith(`${root}${path.sep}`) || !existsSync(absolute) || !lstatSync(absolute).isFile()) {
      throw new Error(`Missing depot file: ${file.path}`);
    }
    const contents = readFileSync(absolute);
    if (contents.length !== file.bytes) throw new Error(`Size mismatch: ${file.path}`);
    const checksum = createHash("sha256").update(contents).digest("hex");
    if (checksum !== file.sha256) throw new Error(`Checksum mismatch: ${file.path}`);
  }

  const actual = depotFiles(root);
  const expected = [...declared].sort();
  if (actual.length !== expected.length || actual.some((file, index) => file !== expected[index])) {
    throw new Error("Depot contents do not exactly match BUILD_MANIFEST.json");
  }
  return manifest;
}
