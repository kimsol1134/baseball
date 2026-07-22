import { readFileSync, readdirSync } from "node:fs";
import { extname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../", import.meta.url));
const sourceRoots = [
  "apps/windows/src",
  "apps/ios/Sources",
  "packages/simulation-core/Sources/SimulationCore",
];
const allowedExtensions = new Set([".swift", ".ts", ".tsx"]);
const excludedSuffixes = [".test.ts", ".test.tsx"];

// 화면에서 뜻을 바로 알 수 있는 말로 바꾼 표현들입니다. 새 콘텐츠가 예전
// 내부 용어를 다시 노출하면 CI에서 발견할 수 있도록 정확한 문구만 검사합니다.
const blockedCopy = [
  "스트라이크 재현성",
  "목표점 재현",
  "경계 재현",
  "코스 재현",
  "현재 능력과 잠재 범위",
  "정보 정확도",
  "관계 신뢰",
  "감독 신뢰",
  "포수 신뢰",
  "커리어 이정표",
  "보직 경쟁 평가전",
  "다음 보직",
  "이번 구간",
  "실행 품질",
  "타구 품질 지수",
  "경기 설계",
  "릴리스 반복",
  "반복되는 릴리스",
  "노림수 형성",
  "커맨드",
  "무브먼트",
];

function filesUnder(directory) {
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) return filesUnder(path);
    if (!allowedExtensions.has(extname(path)) || excludedSuffixes.some((suffix) => path.endsWith(suffix))) return [];
    return [path];
  });
}

const failures = [];
for (const sourceRoot of sourceRoots) {
  for (const path of filesUnder(join(root, sourceRoot))) {
    const source = readFileSync(path, "utf8");
    const lines = source.split("\n");
    for (const blocked of blockedCopy) {
      lines.forEach((line, index) => {
        if (line.includes(blocked)) failures.push(`${relative(root, path)}:${index + 1} — ${blocked}`);
      });
    }
  }
}

if (failures.length > 0) {
  console.error(`문구 품질 검사 실패 (${failures.length})`);
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}

console.log(`문구 품질 검사 통과: 이해하기 어려운 내부 용어 ${blockedCopy.length}종 미노출`);
