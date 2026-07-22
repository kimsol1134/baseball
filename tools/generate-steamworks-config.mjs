import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { validateSteamDepot } from "./steam-depot-manifest.mjs";

const repositoryRoot = fileURLToPath(new URL("..", import.meta.url));
const edition = process.argv[2];
if (!new Set(["full", "demo"]).has(edition)) {
  throw new Error("Usage: node tools/generate-steamworks-config.mjs <full|demo>");
}
const configPath = path.join(repositoryRoot, "steam", "steamworks.local.json");
if (!existsSync(configPath)) {
  throw new Error("Create steam/steamworks.local.json from steamworks.example.json after App IDs are issued");
}
const config = JSON.parse(readFileSync(configPath, "utf8"))[edition];
const numeric = (value, label) => {
  if (!/^\d+$/.test(String(value))) throw new Error(`${label} must be a numeric Steamworks ID`);
  return String(value);
};
const appId = numeric(config?.appId, `${edition}.appId`);
const depotRoot = path.join(repositoryRoot, "artifacts", "steam", edition);
const scriptsDirectory = path.join(repositoryRoot, "artifacts", "steamworks", edition, "scripts");
mkdirSync(scriptsDirectory, { recursive: true });

const depotEntries = [];
for (const [platform, rawDepotId] of Object.entries(config?.depots ?? {})) {
  const content = path.join(depotRoot, platform);
  if (!existsSync(path.join(content, "BUILD_MANIFEST.json"))) continue;
  validateSteamDepot(content, edition === "full" ? "steam_full" : "steam_demo");
  const depotId = numeric(rawDepotId, `${edition}.depots.${platform}`);
  const filename = `depot_build_${depotId}.vdf`;
  const escapedContent = content.replaceAll("\\", "\\\\");
  writeFileSync(path.join(scriptsDirectory, filename), `"DepotBuildConfig"\n{\n  "DepotID" "${depotId}"\n  "ContentRoot" "${escapedContent}"\n  "FileMapping"\n  {\n    "LocalPath" "*"\n    "DepotPath" "."\n    "recursive" "1"\n  }\n  "FileExclusion" "BUILD_MANIFEST.json"\n}\n`);
  depotEntries.push({ depotId, filename });
}
if (depotEntries.length === 0) throw new Error(`No verified ${edition} depots exist under ${depotRoot}`);

const depots = depotEntries.map(({ depotId, filename }) => `    "${depotId}" "${filename}"`).join("\n");
writeFileSync(path.join(scriptsDirectory, "app_build.vdf"), `"appbuild"\n{\n  "appid" "${appId}"\n  "desc" "Project Diamond Soul ${edition}"\n  "buildoutput" "../output"\n  "preview" "1"\n  "depots"\n  {\n${depots}\n  }\n}\n`);
process.stdout.write(`Steamworks ${edition} preview config ready: ${path.relative(repositoryRoot, scriptsDirectory)}\n`);
