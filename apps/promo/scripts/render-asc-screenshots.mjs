import {mkdirSync} from "node:fs";
import {spawnSync} from "node:child_process";
import {dirname, resolve} from "node:path";

const [composition, outputDirectory, countRaw] = process.argv.slice(2);
if (!composition || !outputDirectory || !countRaw) {
  throw new Error("usage: render-asc-screenshots.mjs <composition> <output-dir> <count>");
}
const count = Number.parseInt(countRaw, 10);
if (!Number.isInteger(count) || count < 1) throw new Error(`invalid count: ${countRaw}`);

const output = resolve(outputDirectory);
mkdirSync(output, {recursive: true});

for (let index = 0; index < count; index += 1) {
  const file = resolve(output, `${String(index + 1).padStart(2, "0")}.png`);
  mkdirSync(dirname(file), {recursive: true});
  const result = spawnSync(
    process.platform === "win32" ? "npx.cmd" : "npx",
    ["remotion", "still", composition, file, `--frame=${index}`],
    {stdio: "inherit"},
  );
  if (result.status !== 0) process.exit(result.status ?? 1);
}
