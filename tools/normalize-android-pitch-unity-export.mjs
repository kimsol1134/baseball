import fs from "node:fs";
import path from "node:path";

const exportRoot = path.resolve(
  process.argv[2] ?? "artifacts/android-compose/unity-export/current",
);
const generatedGradleFiles = [
  path.join(exportRoot, "unityLibrary", "build.gradle"),
  path.join(exportRoot, "launcher", "build.gradle"),
];
const generatedExpression =
  "String.valueOf(project.findProperty('unityStreamingAssets') ?: '').tokenize(', ')";

for (const file of generatedGradleFiles) {
  if (!fs.existsSync(file)) continue;
  const source = fs.readFileSync(file, "utf8");
  const replacement = source.replaceAll("unityStreamingAssets.tokenize(', ')", generatedExpression);
  if (replacement === source) continue;
  fs.writeFileSync(file, replacement);
}

const unityLibrary = path.join(exportRoot, "unityLibrary");
if (!fs.existsSync(unityLibrary)) {
  throw new Error(`Unity export is missing unityLibrary: ${unityLibrary}`);
}
