#!/usr/bin/env node
// 관계 대사가 두 플랫폼에서 갈라지지 않는지 대조한다.
//
// 대사는 코어(`RelationshipVoiceCatalog.swift`)가 원본이다. 데스크톱은 아직 자기 TS 사본
// (`apps/windows/src/relationshipDialogue.ts`)을 쓰는데, 그건 데스크톱이 현재 중단 상태라
// 브리지를 손대는 위험을 지지 않기로 했기 때문이다. 대신 두 사본이 조용히 달라지는 것을
// 막는다 — 같은 인물이 두 화면에서 다른 말을 하면 그건 같은 인물이 아니다.
//
// 대조 대상은 **신뢰도 3단 인용 대사**뿐이다. 선택지 문구는 데스크톱이 화면 파일 안에
// 들고 있어 구조가 달라, 여기서는 다루지 않는다.

import { readFileSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const swiftPath = join(root, "packages/simulation-core/Sources/SimulationCore/RelationshipVoiceCatalog.swift");
const tsPath = join(root, "apps/windows/src/relationshipDialogue.ts");

const failures = [];

/** Swift 소스의 `\u{201C}` 이스케이프를 실제 문자로 되돌린다. */
function decodeSwift(text) {
  return text.replace(/\\u\{([0-9A-Fa-f]+)\}/g, (_, hex) => String.fromCodePoint(parseInt(hex, 16)));
}

/** Swift 표에서 `"이벤트id": Scene(... .low: "...", .mid: "...", .high: "..." ...)` 를 뽑는다. */
function readSwiftQuotes(source) {
  const quotes = new Map();
  // 장면마다 닫는 모양이 달라(`])` / `)`) 블록 끝을 정규식으로 잡으면 다음 장면을 삼킨다.
  // 대신 장면 머리(`"evt-…": Scene(`)로 잘라 그 사이만 본다.
  const heads = [...source.matchAll(/"(evt-[a-z-]+)":\s*Scene\(/g)];
  for (const [index, head] of heads.entries()) {
    const start = head.index + head[0].length;
    const end = index + 1 < heads.length ? heads[index + 1].index : source.length;
    const body = source.slice(start, end);
    const bands = {};
    for (const [, band, text] of body.matchAll(/\.(low|mid|high):\s*"((?:[^"\\]|\\.)*)"/g)) {
      bands[band] = decodeSwift(text);
    }
    if (Object.keys(bands).length === 3) quotes.set(head[1], bands);
  }
  return quotes;
}

/** TS 표에서 같은 모양을 뽑는다. */
function readTsQuotes(source) {
  const quotes = new Map();
  const blockRe = /"([a-z-]+)":\s*\{([\s\S]*?)\n  \},/g;
  for (const [, id, body] of source.matchAll(blockRe)) {
    const bands = {};
    for (const [, band, text] of body.matchAll(/(low|mid|high):\s*"((?:[^"\\]|\\.)*)"/g)) {
      bands[band] = text;
    }
    if (Object.keys(bands).length === 3) quotes.set(id, bands);
  }
  return quotes;
}

const swift = readSwiftQuotes(readFileSync(swiftPath, "utf8"));
const ts = readTsQuotes(readFileSync(tsPath, "utf8"));

if (swift.size === 0) failures.push("코어 표에서 신뢰도 3단 대사를 하나도 읽지 못했습니다. 파서가 형식을 놓쳤습니다.");
if (ts.size === 0) failures.push("데스크톱 표에서 신뢰도 3단 대사를 하나도 읽지 못했습니다. 파서가 형식을 놓쳤습니다.");

// 데스크톱의 `fallback-rival`은 코어에서 `evt-rival-message`로 이름이 바뀌었다.
// 코어 쪽이 이벤트 id를 그대로 쓰는 편이 맞다 — 폴백이라는 이름은 구현 사정이지 콘텐츠가 아니다.
const aliases = new Map([["fallback-rival", "evt-rival-message"]]);

for (const [tsID, tsBands] of ts) {
  const coreID = aliases.get(tsID) ?? tsID;
  const coreBands = swift.get(coreID);
  if (!coreBands) {
    failures.push(`${tsID}: 데스크톱에는 있는데 코어 표에 없습니다.`);
    continue;
  }
  for (const band of ["low", "mid", "high"]) {
    if (coreBands[band] !== tsBands[band]) {
      failures.push(
        `${coreID} (${band}): 두 플랫폼의 대사가 다릅니다.\n    코어  : ${coreBands[band]}\n    데스크톱: ${tsBands[band]}`
      );
    }
  }
}

if (failures.length > 0) {
  console.error("관계 대사 대조 실패:");
  for (const failure of failures) console.error(`  - ${failure}`);
  process.exit(1);
}

console.log(`관계 대사 대조 통과: 신뢰도 3단 장면 ${ts.size}종이 코어와 일치`);
