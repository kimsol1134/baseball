#!/usr/bin/env node

import { readFileSync } from "node:fs";
import { basename, dirname, isAbsolute, join, relative, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const DEFAULT_FILES = [
  "packages/simulation-core/Sources/SimulationCore/RelationshipVoiceCatalog.swift",
  "packages/simulation-core/Sources/SimulationCore/HighSchoolCareer.swift",
  "packages/simulation-core/Sources/SimulationCore/HighSchoolContentCatalog.swift",
];
const DEFAULT_CONFIG = "tools/korean-copy.config.json";

const TRANSLATIONESE_GROUPS = [
  {
    id: "translationese-passive",
    label: "번역투 피동 표현",
    pattern: /(?:되어졌|되어 있|되었습니다|되었으며|이루어졌|진행되었|수행되었|제공되었|확인되었|표시되었)/g,
  },
  {
    id: "translationese-formal-noun",
    label: "동작을 명사로 돌린 관공서체",
    pattern: /(?:확인을 진행|설명을 진행|검토를 진행|선택을 진행|훈련을 실시|평가를 실시|수행을 하|진행을 하)/g,
  },
  {
    id: "translationese-connective",
    label: "번역투 연결·가능 표현",
    pattern: /(?:이를 통해|그에 따라|이와 관련하여|에 대하여|의 경우에는|할 수 있습니다|될 수 있습니다)/g,
  },
];

const BOILERPLATE = [
  ["설명", /설명/g],
  ["확인", /확인/g],
  ["정리", /정리/g],
  ["차분히", /차분히/g],
  ["결과로 답", /결과로\s*(?:답|보여|증명)/g],
  ["다음", /다음/g],
];

function lineAt(source, offset) {
  let line = 1;
  for (let index = 0; index < offset; index += 1) if (source.charCodeAt(index) === 10) line += 1;
  return line;
}

function decodeSwiftString(raw) {
  return raw
    .replace(/\\u\{([0-9a-fA-F]+)\}/g, (_, hex) => String.fromCodePoint(Number.parseInt(hex, 16)))
    .replace(/\\n/g, "\n")
    .replace(/\\t/g, "\t")
    .replace(/\\r/g, "\r")
    .replace(/\\\"/g, "\"")
    .replace(/\\\\/g, "\\");
}

function interpolationEnd(source, start) {
  let index = start + 2;
  let depth = 1;
  let quoted = false;
  while (index < source.length && depth > 0) {
    const char = source[index];
    if (quoted) {
      if (char === "\\") index += 2;
      else { if (char === '"') quoted = false; index += 1; }
      continue;
    }
    if (char === '"') quoted = true;
    else if (char === "(") depth += 1;
    else if (char === ")") depth -= 1;
    index += 1;
  }
  return index;
}

/** Extract ordinary and triple-quoted Swift literals while skipping comments. */
export function extractSwiftStrings(source, file = "<memory>") {
  const strings = [];
  let index = 0;
  let blockDepth = 0;
  while (index < source.length) {
    if (blockDepth > 0) {
      if (source.startsWith("/*", index)) { blockDepth += 1; index += 2; continue; }
      if (source.startsWith("*/", index)) { blockDepth -= 1; index += 2; continue; }
      index += 1;
      continue;
    }
    if (source.startsWith("//", index)) {
      const newline = source.indexOf("\n", index + 2);
      index = newline === -1 ? source.length : newline + 1;
      continue;
    }
    if (source.startsWith("/*", index)) { blockDepth = 1; index += 2; continue; }

    const triple = source.startsWith('"""', index);
    if (source[index] !== '"') { index += 1; continue; }
    const start = index;
    const delimiter = triple ? '"""' : '"';
    index += delimiter.length;
    let raw = "";
    while (index < source.length) {
      if (source.startsWith(delimiter, index)) {
        index += delimiter.length;
        break;
      }
      if (source.startsWith("\\(", index)) {
        const end = interpolationEnd(source, index);
        raw += source.slice(index, end);
        index = end;
        continue;
      }
      if (!triple && source[index] === "\\" && index + 1 < source.length) {
        if (source.startsWith("\\u{", index)) {
          const close = source.indexOf("}", index + 3);
          if (close !== -1) { raw += source.slice(index, close + 1); index = close + 1; continue; }
        }
        raw += source.slice(index, index + 2);
        index += 2;
        continue;
      }
      raw += source[index];
      index += 1;
    }
    const value = decodeSwiftString(raw);
    if (/\p{Script=Hangul}/u.test(value)) {
      strings.push({ file, line: lineAt(source, start), start, end: index, value });
    }
  }
  return strings;
}

function cleanText(value) {
  return value
    .replace(/\{[^}]+\}|\\\([^)]*\)/g, " 변수 ")
    .replace(/[“”‘’"'…·—–.,!?()[\]{}:;]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function nearSimilarity(a, b) {
  const left = cleanText(a).replace(/\s/g, "");
  const right = cleanText(b).replace(/\s/g, "");
  if (!left || !right) return 0;
  if (left === right) return 1;
  if ((left.includes(right) || right.includes(left)) && Math.min(left.length, right.length) / Math.max(left.length, right.length) >= 0.72) return 0.9;
  const bigrams = (text) => Array.from({ length: Math.max(0, text.length - 1) }, (_, i) => text.slice(i, i + 2));
  const aGrams = bigrams(left);
  const bCounts = new Map();
  for (const gram of bigrams(right)) bCounts.set(gram, (bCounts.get(gram) ?? 0) + 1);
  let overlap = 0;
  for (const gram of aGrams) {
    if ((bCounts.get(gram) ?? 0) > 0) { overlap += 1; bCounts.set(gram, bCounts.get(gram) - 1); }
  }
  return (2 * overlap) / Math.max(1, aGrams.length + Math.max(0, right.length - 1));
}

function choicePairs(source, file) {
  const strings = extractSwiftStrings(source, file);
  const pairs = [];
  for (let index = 0; index < strings.length - 1; index += 1) {
    const title = strings[index];
    const detail = strings[index + 1];
    const prefix = source.slice(Math.max(0, title.start - 40), title.start);
    const between = source.slice(title.end, detail.start);
    if (/(?:listen|explain|challenge)\(\s*$/.test(prefix) && /^\s*,\s*$/.test(between)) {
      pairs.push({ file, line: title.line, title: title.value, detail: detail.value });
    }
  }
  return pairs;
}

function allowed(finding, allowlist) {
  return allowlist.some((entry) => entry.ruleId === finding.ruleId
    && (!entry.path || finding.file.endsWith(entry.path))
    && (!entry.contains || finding.excerpt?.includes(entry.contains)));
}

function finding(severity, ruleId, message, sample = {}) {
  return { severity, ruleId, message, ...sample };
}

function endingOf(value) {
  const normalized = value.replace(/[”’"')\]}\s.!?…]+$/g, "");
  const match = normalized.match(/(했습니다|되었습니다|있습니다|없습니다|입니다|합니다|됐습니다|한다|했다|된다|됐다|있다|없다|이다|해요|돼요|네요|군요|죠|다)$/);
  return match?.[1] ?? null;
}

function templateSkeleton(value) {
  return value
    .replace(/\{[^}]+\}|\\\([^)]*\)/g, "<변수>")
    .replace(/\d+(?:[.,]\d+)?/g, "<수>")
    .split(/\s+/)
    .filter(Boolean)
    .map((token) => {
      if (token.includes("<변수>")) return "<변수>";
      if (token.includes("<수>")) return "<수>";
      const punctuation = token.match(/[.!?…]+$/)?.[0] ?? "";
      const ending = token.match(/(했습니다|되었습니다|있습니다|없습니다|입니다|합니다|됐습니다|한다|했다|된다|됐다|있다|없다|이다|한다|해요|돼요|네요|군요|죠|다)(?:[.!?…]*)$/)?.[1];
      return `${ending ? `*${ending}` : "*"}${punctuation}`;
    })
    .join(" ");
}

function countMatches(text, pattern) {
  return [...text.matchAll(new RegExp(pattern.source, pattern.flags))].length;
}

function validateFallbackCoverage(sources) {
  const catalog = sources.find(({ path }) => basename(path) === "HighSchoolContentCatalog.swift");
  const voices = sources.find(({ path }) => basename(path) === "RelationshipVoiceCatalog.swift");
  if (!catalog || !voices) return [];
  const categories = new Set([...catalog.source.matchAll(/category:\s*"([a-z-]+)"/g)].map((match) => match[1]));
  const categoryBlock = voices.source.match(/public static let categoryScenes:[\s\S]*?= \[([\s\S]*?)\n    \]\n\n    \/\/\/ 핵심/);
  const fallbacks = new Set(categoryBlock ? [...categoryBlock[1].matchAll(/^\s*"([a-z-]+)":\s*Scene/gm)].map((match) => match[1]) : []);
  for (const core of ["coach", "catcher", "rival"]) fallbacks.add(core);
  const missing = [...categories].filter((category) => !fallbacks.has(category)).sort();
  return missing.map((category) => finding(
    "error",
    "event-fallback-coverage",
    `이벤트 카테고리 '${category}'에 관계 장면 폴백이 없습니다.`,
    { file: relative(ROOT, catalog.path), line: 1, excerpt: category },
  ));
}

export function analyzeSources(sources, config) {
  const thresholds = config.thresholds;
  const entries = sources.flatMap(({ path, source }) => extractSwiftStrings(source, relative(ROOT, path)));
  const findings = [];

  for (const entry of entries) {
    // Swift interpolation source can be much longer than its rendered value. Use a short,
    // visible stand-in so `\(long.property.path)` does not manufacture a line-budget warning.
    const renderedEstimate = entry.value.replace(/\\\([^)]*\)|\{[^}]+\}/g, "선수");
    const length = [...renderedEstimate].length;
    if (length > thresholds.longStringError) {
      findings.push(finding("error", "long-line", `한 화면 문자열이 ${length}자로 ${thresholds.longStringError}자 상한을 넘습니다.`, { ...entry, excerpt: entry.value }));
    } else if (length > thresholds.longStringWarning) {
      findings.push(finding("warning", "long-line", `한 화면 문자열이 ${length}자입니다. 카드에서 잘리거나 읽기 버거운지 확인하세요.`, { ...entry, excerpt: entry.value }));
    }
  }

  for (const { path, source } of sources) {
    for (const pair of choicePairs(source, relative(ROOT, path))) {
      const similarity = nearSimilarity(pair.title, pair.detail);
      if (similarity === 1) {
        findings.push(finding("error", "duplicate-title-detail", "선택지 제목과 설명이 같습니다.", { ...pair, excerpt: `${pair.title} / ${pair.detail}` }));
      } else if (similarity >= 0.84) {
        findings.push(finding("warning", "near-duplicate-title-detail", `선택지 제목과 설명이 매우 비슷합니다 (${similarity.toFixed(2)}).`, { ...pair, excerpt: `${pair.title} / ${pair.detail}` }));
      }
    }
  }

  const allText = entries.map((entry) => entry.value).join("\n");
  for (const group of TRANSLATIONESE_GROUPS) {
    const matches = entries.filter((entry) => countMatches(entry.value, group.pattern) > 0);
    const occurrences = countMatches(allText, group.pattern);
    const density = entries.length ? (occurrences * 100) / entries.length : 0;
    if (occurrences >= thresholds.translationeseMinimum && density >= thresholds.translationesePerHundredStrings) {
      findings.push(finding("warning", group.id, `${group.label}이 ${occurrences}회(${density.toFixed(1)}/문자열 100개) 반복됩니다.`, {
        file: matches[0]?.file ?? "<all>", line: matches[0]?.line ?? 1, excerpt: matches.slice(0, 3).map((entry) => entry.value).join(" | "),
      }));
    }
  }

  for (const [label, pattern] of BOILERPLATE) {
    const matching = entries.filter((entry) => countMatches(entry.value, pattern) > 0);
    const occurrences = countMatches(allText, pattern);
    const ratio = matching.length / Math.max(1, entries.length);
    if (occurrences >= thresholds.boilerplateMinimum && ratio >= thresholds.boilerplateStringRatio) {
      findings.push(finding("warning", "boilerplate-density", `'${label}' 계열 문구가 ${occurrences}회, 전체 문자열의 ${(ratio * 100).toFixed(1)}%에 나타납니다.`, {
        file: matching[0]?.file ?? "<all>", line: matching[0]?.line ?? 1, excerpt: matching.slice(0, 3).map((entry) => entry.value).join(" | "),
      }));
    }
  }

  const endings = new Map();
  for (const entry of entries) {
    const ending = endingOf(entry.value);
    if (ending) endings.set(ending, [...(endings.get(ending) ?? []), entry]);
  }
  const endingTotal = [...endings.values()].reduce((sum, group) => sum + group.length, 0);
  const dominant = [...endings.entries()].sort((a, b) => b[1].length - a[1].length)[0];
  if (dominant && endingTotal >= thresholds.uniformEndingMinimumSentences && dominant[1].length / endingTotal >= thresholds.uniformEndingRatio) {
    findings.push(finding("warning", "sentence-ending-uniformity", `판별 가능한 문장 ${endingTotal}개 중 ${dominant[1].length}개가 '${dominant[0]}'로 끝납니다.`, {
      file: dominant[1][0].file, line: dominant[1][0].line, excerpt: dominant[1].slice(0, 3).map((entry) => entry.value).join(" | "),
    }));
  }

  const ngrams = new Map();
  for (const entry of entries) {
    const tokens = cleanText(entry.value).split(" ").filter(Boolean);
    const seen = new Set();
    for (let index = 0; index <= tokens.length - 3; index += 1) seen.add(tokens.slice(index, index + 3).join(" "));
    for (const gram of seen) ngrams.set(gram, [...(ngrams.get(gram) ?? []), entry]);
  }
  for (const [gram, locations] of [...ngrams.entries()].sort((a, b) => b[1].length - a[1].length || a[0].localeCompare(b[0], "ko"))) {
    if (locations.length >= thresholds.repeatedNgramMinimum && locations.length / Math.max(1, entries.length) >= thresholds.repeatedNgramStringRatio) {
      findings.push(finding("warning", "repeated-ngram", `3어절 '${gram}'이 서로 다른 문자열 ${locations.length}개에서 반복됩니다.`, {
        file: locations[0].file, line: locations[0].line, excerpt: locations.slice(0, 3).map((entry) => entry.value).join(" | "),
      }));
    }
  }

  const templates = new Map();
  for (const entry of entries) {
    const skeleton = templateSkeleton(entry.value);
    if (skeleton.split(" ").length < 4) continue;
    const group = templates.get(skeleton) ?? [];
    if (!group.some(({ value }) => value === entry.value)) group.push(entry);
    templates.set(skeleton, group);
  }
  for (const [skeleton, locations] of [...templates.entries()].sort((a, b) => b[1].length - a[1].length)) {
    if (locations.length >= thresholds.repeatedTemplateMinimum
      && locations.length / Math.max(1, entries.length) >= thresholds.repeatedTemplateStringRatio) {
      findings.push(finding("warning", "repeated-template", `같은 문장 뼈대 '${skeleton}'가 서로 다른 문자열 ${locations.length}개에서 반복됩니다.`, {
        file: locations[0].file, line: locations[0].line, excerpt: locations.slice(0, 3).map((entry) => entry.value).join(" | "),
      }));
    }
  }

  findings.push(...validateFallbackCoverage(sources));
  const activeFindings = findings.filter((item) => !allowed(item, config.allowlist ?? []));
  const counts = {
    errors: activeFindings.filter(({ severity }) => severity === "error").length,
    warnings: activeFindings.filter(({ severity }) => severity === "warning").length,
  };
  return {
    schemaVersion: 1,
    files: sources.map(({ path }) => relative(ROOT, path)),
    stringCount: entries.length,
    counts,
    passed: counts.errors === 0,
    findings: activeFindings.map(({ start: _start, end: _end, value: _value, ...item }) => item),
  };
}

export function analyzePaths(paths, configPath = resolve(ROOT, DEFAULT_CONFIG)) {
  const config = JSON.parse(readFileSync(configPath, "utf8"));
  const sources = paths.map((path) => {
    const absolute = isAbsolute(path) ? path : resolve(ROOT, path);
    return { path: absolute, source: readFileSync(absolute, "utf8") };
  });
  return analyzeSources(sources, config);
}

function parseArgs(argv) {
  const options = { json: false, failOnWarnings: false, config: resolve(ROOT, DEFAULT_CONFIG), files: [] };
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--json") options.json = true;
    else if (arg === "--fail-on-warnings") options.failOnWarnings = true;
    else if (arg === "--config") options.config = resolve(argv[++index]);
    else if (arg === "--help" || arg === "-h") options.help = true;
    else options.files.push(arg);
  }
  return options;
}

function printHuman(report) {
  const status = report.passed ? "통과" : "실패";
  console.log(`한국어 게임 문구 검사 ${status}: ${report.stringCount}개 문자열 · 오류 ${report.counts.errors} · 경고 ${report.counts.warnings}`);
  for (const item of report.findings) {
    console.log(`- [${item.severity.toUpperCase()}] ${item.ruleId} ${item.file}:${item.line} — ${item.message}`);
    if (item.excerpt) console.log(`  ${item.excerpt.slice(0, 220)}`);
  }
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  if (options.help) {
    console.log("사용법: node tools/check-korean-game-copy.mjs [--json] [--fail-on-warnings] [--config FILE] [Swift 파일 ...]");
    return;
  }
  const report = analyzePaths(options.files.length ? options.files : DEFAULT_FILES, options.config);
  if (options.json) console.log(JSON.stringify(report, null, 2));
  else printHuman(report);
  if (!report.passed || (options.failOnWarnings && report.counts.warnings > 0)) process.exitCode = 1;
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) await main();
