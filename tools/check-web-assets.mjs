import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { extname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../", import.meta.url));
const dist = join(root, "apps/windows/dist");
const runtimeAssets = join(root, "apps/windows/src/assets");
const sourceRoot = join(root, "apps/windows/src");

// 예산 프로필: 웹 티저는 전송량 때문에 빡빡하게, 데스크톱/Steam 번들은 고화질 아트를 허용한다.
// 기본은 web(기존 동작 유지). 데스크톱 검사는 `--profile desktop`으로 실행한다.
const profile = process.argv.includes("--profile")
  ? process.argv[process.argv.indexOf("--profile") + 1] ?? "web"
  : "web";
const BUDGETS = {
  web: { total: 2.5 * 1024 * 1024, file: 600 * 1024, label: "2.50 MiB" },
  desktop: { total: 16 * 1024 * 1024, file: 4 * 1024 * 1024, label: "16.00 MiB" },
};
const budget = BUDGETS[profile] ?? BUDGETS.web;
const MAX_TOTAL = budget.total;
const MAX_FILE = budget.file;

function filesUnder(directory) {
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const path = join(directory, entry.name);
    return entry.isDirectory() ? filesUnder(path) : [path];
  });
}

if (!existsSync(dist)) {
  console.error("웹 자산 검사 실패: 먼저 build:web을 실행해야 합니다.");
  process.exit(1);
}

const distFiles = filesUnder(dist);
const total = distFiles.reduce((sum, path) => sum + statSync(path).size, 0);
const failures = [];
if (total > MAX_TOTAL) failures.push(`dist 합계 ${(total / 1024 / 1024).toFixed(2)} MiB > ${budget.label}`);
for (const path of distFiles) {
  const size = statSync(path).size;
  if (size > MAX_FILE) failures.push(`${relative(root, path)} ${(size / 1024).toFixed(0)} KiB > ${(MAX_FILE / 1024).toFixed(0)} KiB`);
  if ([".ico", ".icns", ".exe", ".dmg"].includes(extname(path))) failures.push(`${relative(root, path)} 플랫폼 전용 파일이 웹 dist에 포함됨`);
}

const sourceText = filesUnder(sourceRoot)
  .filter((path) => [".ts", ".tsx", ".css"].includes(extname(path)))
  .map((path) => readFileSync(path, "utf8"))
  .join("\n");
for (const asset of filesUnder(runtimeAssets)) {
  const filename = asset.split("/").at(-1);
  if (filename && !sourceText.includes(filename)) failures.push(`${relative(root, asset)} 런타임 참조 없음 — docs/assets/source로 보관하거나 제거`);
}

if (failures.length) {
  console.error(`웹 자산 검사 실패 (${failures.length})`);
  failures.forEach((failure) => console.error(`- ${failure}`));
  process.exit(1);
}

console.log(`웹 자산 검사 통과(${profile} 프로필): ${distFiles.length}개 · ${(total / 1024 / 1024).toFixed(2)} MiB · 미사용 런타임 자산 없음`);
