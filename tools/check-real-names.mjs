#!/usr/bin/env node
// 배포 콘텐츠에 실존 구단·리그·선수명이 들어갔는지 본다(AGENTS.md 콘텐츠 불변 규칙).
//
// 한 번 훑고 끝내는 검색은 다음 문구가 들어오는 순간 무의미해진다. 게이트로 두어야
// 새로 추가되는 문구까지 계속 걸린다.
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, extname, relative } from "node:path";

const ROOT = process.cwd();

/** 실제로 사용자에게 나가는 것만 본다. 테스트·문서·마케팅 자료는 대상이 아니다. */
const SCAN_ROOTS = [
  "apps/ios/Sources",
  "apps/android/app/src/main",
  "apps/android/game-application/src/main",
  "apps/android/game-core/src/main",
  "packages/simulation-core/Sources",
  "packages/ios-layers/Sources",
  "docs/localization/android-copy.json",
];

const SCAN_EXTENSIONS = new Set([".swift", ".kt", ".json", ".xcstrings", ".xml"]);

/**
 * 실존 명칭. `word: true`는 라틴 문자 약칭이라 단어 경계가 필요하다는 뜻이다 —
 * 경계 없이 찾으면 "NC"가 "SYNC"에, "KT"가 "MARKET"에 걸린다.
 */
const FORBIDDEN = [
  // 구단 정식 명칭과 별명
  ["두산 베어스"], ["베어스"], ["엘지 트윈스"], ["트윈스"], ["키움 히어로즈"], ["히어로즈"],
  ["랜더스"], ["위즈"], ["다이노스"], ["삼성 라이온즈"], ["라이온즈"],
  ["롯데 자이언츠"], ["자이언츠"], ["기아 타이거즈"], ["타이거즈"], ["한화 이글스"], ["이글스"],
  // 리그·기구
  ["KBO", { word: true }], ["한국야구위원회"], ["퓨처스리그"], ["퓨처스 리그"],
  ["메이저리그"], ["MLB", { word: true }], ["NPB", { word: true }], ["일본프로야구"],
  // 라틴 약칭 구단
  ["SSG", { word: true }], ["LG 트윈스"], ["KT 위즈"], ["NC 다이노스"],
  // 널리 알려진 실존 선수
  ["류현진"], ["오타니"], ["이대호"], ["박찬호"], ["김광현"], ["양현종"], ["이승엽"],
];

const failures = [];

function walk(path) {
  const stats = statSync(path, { throwIfNoEntry: false });
  if (!stats) return;
  if (stats.isFile()) {
    if (!SCAN_EXTENSIONS.has(extname(path))) return;
    inspect(path);
    return;
  }
  for (const entry of readdirSync(path)) {
    if (entry === "build" || entry === ".build" || entry === "Pods") continue;
    walk(join(path, entry));
  }
}

function inspect(path) {
  const source = readFileSync(path, "utf8");
  const lines = source.split("\n");
  for (const [needle, options] of FORBIDDEN) {
    const pattern = options?.word
      ? new RegExp(`(^|[^A-Za-z0-9])${needle}([^A-Za-z0-9]|$)`)
      : null;
    lines.forEach((line, index) => {
      // 주석은 콘텐츠가 아니다. 규칙 자체를 설명하는 주석까지 걸리면 게이트가 자기를 막는다.
      const trimmed = line.trim();
      if (trimmed.startsWith("//") || trimmed.startsWith("///") || trimmed.startsWith("*")) return;
      const hit = pattern ? pattern.test(line) : line.includes(needle);
      if (!hit) return;
      failures.push({ path: relative(ROOT, path), line: index + 1, needle, text: trimmed.slice(0, 160) });
    });
  }
}

for (const root of SCAN_ROOTS) walk(join(ROOT, root));

if (failures.length > 0) {
  console.error("실존 명칭이 배포 콘텐츠에 있습니다 (AGENTS.md 콘텐츠 불변 규칙):\n");
  for (const failure of failures) {
    console.error(`  ${failure.path}:${failure.line}  «${failure.needle}»`);
    console.error(`    ${failure.text}`);
  }
  console.error(`\n총 ${failures.length}건.`);
  process.exit(1);
}

console.log("real-name check passed: 배포 콘텐츠에 실존 구단·리그·선수명이 없습니다.");
