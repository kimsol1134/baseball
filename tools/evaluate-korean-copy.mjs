#!/usr/bin/env node

import { createHash } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

function stableNumber(seed, value) {
  const digest = createHash("sha256").update(`${seed}\0${value}`).digest();
  return digest.readUInt32BE(0);
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function validatePairs(input) {
  assert(input && Array.isArray(input.items) && input.items.length >= 12, "입력 JSON에는 최소 12개의 items가 필요합니다.");
  const ids = new Set();
  for (const [index, item] of input.items.entries()) {
    assert(typeof item.id === "string" && item.id.trim(), `items[${index}].id가 필요합니다.`);
    assert(!ids.has(item.id), `중복 항목 id: ${item.id}`);
    ids.add(item.id);
    assert(typeof item.original === "string" && item.original.trim(), `${item.id}.original이 필요합니다.`);
    assert(typeof item.rewrite === "string" && item.rewrite.trim(), `${item.id}.rewrite가 필요합니다.`);
  }
}

export function preparePacket(input, seed = "korean-copy-v1") {
  validatePairs(input);
  const keyed = input.items.map((item) => {
    const rewriteIsA = stableNumber(seed, `${item.id}|side`) % 2 === 0;
    return {
      packetItem: {
        id: item.id,
        context: item.context ?? "",
        options: {
          A: rewriteIsA ? item.rewrite : item.original,
          B: rewriteIsA ? item.original : item.rewrite,
        },
      },
      keyItem: {
        id: item.id,
        original: rewriteIsA ? "B" : "A",
        rewrite: rewriteIsA ? "A" : "B",
      },
    };
  });
  keyed.sort((left, right) => stableNumber(seed, `${left.packetItem.id}|order`) - stableNumber(seed, `${right.packetItem.id}|order`)
    || left.packetItem.id.localeCompare(right.packetItem.id));
  return {
    packet: {
      schemaVersion: 1,
      seed,
      instructions: {
        preference: "더 자연스럽고 게임 장면에 어울리는 문구를 A/B 중 고르세요. 차이가 없으면 tie를 고르세요.",
        aiLike: "각 문구의 AI 작성 느낌을 1(전혀 없음)~5(매우 강함)로 매기세요.",
        readability: "각 문구의 읽기 쉬움을 1(매우 어려움)~5(매우 쉬움)으로 매기세요.",
      },
      items: keyed.map(({ packetItem }) => packetItem),
    },
    key: {
      schemaVersion: 1,
      seed,
      sourceName: input.name ?? null,
      items: keyed.map(({ keyItem }) => keyItem),
    },
  };
}

function parseCsvLine(line) {
  const cells = [];
  let value = "";
  let quoted = false;
  for (let index = 0; index < line.length; index += 1) {
    const char = line[index];
    if (char === '"') {
      if (quoted && line[index + 1] === '"') { value += '"'; index += 1; }
      else quoted = !quoted;
    } else if (char === "," && !quoted) { cells.push(value); value = ""; }
    else value += char;
  }
  cells.push(value);
  return cells;
}

export function parseResponses(source, format = "json") {
  if (format === "csv") {
    const lines = source.replace(/^\uFEFF/, "").split(/\r?\n/).filter((line) => line.trim());
    assert(lines.length >= 2, "CSV에는 헤더와 응답 행이 필요합니다.");
    const headers = parseCsvLine(lines[0]);
    return lines.slice(1).map((line) => Object.fromEntries(headers.map((header, index) => [header, parseCsvLine(line)[index] ?? ""])));
  }
  const parsed = JSON.parse(source);
  return Array.isArray(parsed) ? parsed : parsed.responses;
}

function rating(value, field, row) {
  const number = Number(value);
  assert(Number.isInteger(number) && number >= 1 && number <= 5, `${row}: ${field}는 1~5 정수여야 합니다.`);
  return number;
}

function median(values) {
  if (!values.length) return null;
  const sorted = [...values].sort((a, b) => a - b);
  const middle = Math.floor(sorted.length / 2);
  return sorted.length % 2 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2;
}

export function scoreResponses(key, responsesInput) {
  const responses = Array.isArray(responsesInput) ? responsesInput : responsesInput?.responses;
  assert(Array.isArray(responses) && responses.length > 0, "응답에는 비어 있지 않은 responses 배열이 필요합니다.");
  assert(Array.isArray(key?.items) && key.items.length >= 12, "정답 키에는 최소 12개 항목이 필요합니다.");
  const keyById = new Map(key.items.map((item) => [item.id, item]));
  const seen = new Set();
  const rows = responses.map((response, index) => {
    const rowName = `responses[${index}]`;
    const item = keyById.get(response.itemId);
    assert(item, `${rowName}: 알 수 없는 itemId '${response.itemId}'`);
    assert(typeof response.evaluatorId === "string" && response.evaluatorId.trim(), `${rowName}: evaluatorId가 필요합니다.`);
    const unique = `${response.evaluatorId}\0${response.itemId}`;
    assert(!seen.has(unique), `${rowName}: 같은 평가자와 항목의 중복 응답입니다.`);
    seen.add(unique);
    assert(["A", "B", "tie"].includes(response.preference), `${rowName}: preference는 A, B, tie 중 하나여야 합니다.`);
    const aiLikeA = rating(response.aiLikeA ?? response.aiLike?.A, "aiLikeA", rowName);
    const aiLikeB = rating(response.aiLikeB ?? response.aiLike?.B, "aiLikeB", rowName);
    const readabilityA = rating(response.readabilityA ?? response.readability?.A, "readabilityA", rowName);
    const readabilityB = rating(response.readabilityB ?? response.readability?.B, "readabilityB", rowName);
    return {
      itemId: response.itemId,
      evaluatorId: response.evaluatorId,
      preferred: response.preference === "tie" ? "tie" : response.preference === item.rewrite ? "rewrite" : "original",
      rewriteAiLike: item.rewrite === "A" ? aiLikeA : aiLikeB,
      rewriteReadability: item.rewrite === "A" ? readabilityA : readabilityB,
      originalAiLike: item.original === "A" ? aiLikeA : aiLikeB,
      originalReadability: item.original === "A" ? readabilityA : readabilityB,
    };
  });

  const evaluatorIDs = [...new Set(rows.map(({ evaluatorId }) => evaluatorId))];
  assert(evaluatorIDs.length >= 5, `서로 다른 평가자가 최소 5명 필요합니다 (현재 ${evaluatorIDs.length}명).`);
  for (const evaluatorId of evaluatorIDs) {
    const completed = new Set(rows.filter((row) => row.evaluatorId === evaluatorId).map(({ itemId }) => itemId));
    const missing = key.items.filter(({ id }) => !completed.has(id)).map(({ id }) => id);
    assert(missing.length === 0, `평가자 '${evaluatorId}'가 모든 항목을 완료하지 않았습니다 (누락: ${missing.join(", ")}).`);
  }

  const summarize = (subset) => {
    const decisive = subset.filter(({ preferred }) => preferred !== "tie");
    const rewriteWins = decisive.filter(({ preferred }) => preferred === "rewrite").length;
    const originalAiLikeMedian = median(subset.map(({ originalAiLike }) => originalAiLike));
    const rewriteAiLikeMedian = median(subset.map(({ rewriteAiLike }) => rewriteAiLike));
    const originalReadabilityMedian = median(subset.map(({ originalReadability }) => originalReadability));
    const rewriteReadabilityMedian = median(subset.map(({ rewriteReadability }) => rewriteReadability));
    return {
      responses: subset.length,
      decisivePreferences: decisive.length,
      rewritePreferences: rewriteWins,
      originalPreferences: decisive.length - rewriteWins,
      ties: subset.length - decisive.length,
      // A tie is a valid ballot but not evidence that the rewrite won. Keeping ties in the
      // denominator prevents one rewrite vote plus many ties from appearing as 100% preference.
      preferenceRate: subset.length ? rewriteWins / subset.length : null,
      aiLikeMedian: rewriteAiLikeMedian,
      readabilityMedian: rewriteReadabilityMedian,
      original: { aiLikeMedian: originalAiLikeMedian, readabilityMedian: originalReadabilityMedian },
      rewrite: { aiLikeMedian: rewriteAiLikeMedian, readabilityMedian: rewriteReadabilityMedian },
      delta: {
        aiLike: rewriteAiLikeMedian === null || originalAiLikeMedian === null ? null : rewriteAiLikeMedian - originalAiLikeMedian,
        readability: rewriteReadabilityMedian === null || originalReadabilityMedian === null ? null : rewriteReadabilityMedian - originalReadabilityMedian,
      },
    };
  };
  const overall = summarize(rows);
  const thresholds = { preferenceRate: 0.8, aiLikeMaximum: 2, readabilityMinimum: 4 };
  const checks = {
    preference: overall.preferenceRate !== null && overall.preferenceRate >= thresholds.preferenceRate,
    aiLike: overall.aiLikeMedian !== null && overall.aiLikeMedian <= thresholds.aiLikeMaximum,
    readability: overall.readabilityMedian !== null && overall.readabilityMedian >= thresholds.readabilityMinimum,
  };
  return {
    schemaVersion: 1,
    thresholds,
    overall,
    checks,
    passed: Object.values(checks).every(Boolean),
    perItem: key.items.map(({ id }) => ({ itemId: id, ...summarize(rows.filter((row) => row.itemId === id)) })),
  };
}

function parseArgs(argv) {
  const command = argv[0];
  const positional = [];
  const options = { seed: "korean-copy-v1", json: false };
  for (let index = 1; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--output") options.output = argv[++index];
    else if (arg === "--key") options.key = argv[++index];
    else if (arg === "--responses") options.responses = argv[++index];
    else if (arg === "--seed") options.seed = argv[++index];
    else if (arg === "--json") options.json = true;
    else positional.push(arg);
  }
  return { command, positional, options };
}

function printScore(report) {
  const rate = report.overall.preferenceRate === null ? "n/a" : `${(report.overall.preferenceRate * 100).toFixed(1)}%`;
  console.log(`블라인드 문구 평가 ${report.passed ? "통과" : "미통과"}`);
  console.log(`개작 선호율 ${rate} (기준 ≥80%) · AI 느낌 중앙값 ${report.overall.aiLikeMedian ?? "n/a"} (기준 ≤2) · 가독성 중앙값 ${report.overall.readabilityMedian ?? "n/a"} (기준 ≥4)`);
  console.log(`원문→개작 중앙값: AI 느낌 ${report.overall.original.aiLikeMedian ?? "n/a"}→${report.overall.rewrite.aiLikeMedian ?? "n/a"} (Δ ${report.overall.delta.aiLike ?? "n/a"}) · 가독성 ${report.overall.original.readabilityMedian ?? "n/a"}→${report.overall.rewrite.readabilityMedian ?? "n/a"} (Δ ${report.overall.delta.readability ?? "n/a"})`);
  for (const item of report.perItem) {
    const itemRate = item.preferenceRate === null ? "n/a" : `${(item.preferenceRate * 100).toFixed(1)}%`;
    console.log(`- ${item.itemId}: 선호 ${itemRate}, AI 느낌 ${item.aiLikeMedian ?? "n/a"}, 가독성 ${item.readabilityMedian ?? "n/a"}, 응답 ${item.responses}`);
  }
}

function usage() {
  console.log("준비: node tools/evaluate-korean-copy.mjs prepare PAIRS.json --output PACKET.json --key KEY.json [--seed SEED]");
  console.log("채점: node tools/evaluate-korean-copy.mjs score --key KEY.json --responses RESPONSES.json|csv [--json]");
}

function main() {
  const { command, positional, options } = parseArgs(process.argv.slice(2));
  if (command === "prepare") {
    assert(positional[0] && options.output && options.key, "prepare에는 입력, --output, --key가 필요합니다.");
    const result = preparePacket(JSON.parse(readFileSync(resolve(positional[0]), "utf8")), options.seed);
    writeFileSync(resolve(options.output), `${JSON.stringify(result.packet, null, 2)}\n`);
    writeFileSync(resolve(options.key), `${JSON.stringify(result.key, null, 2)}\n`);
    console.log(`블라인드 패킷 ${result.packet.items.length}개 준비 완료: ${options.output}`);
    console.log(`정답 키(평가자에게 공유 금지): ${options.key}`);
    return;
  }
  if (command === "score") {
    assert(options.key && options.responses, "score에는 --key와 --responses가 필요합니다.");
    const responsePath = resolve(options.responses);
    const format = responsePath.toLowerCase().endsWith(".csv") ? "csv" : "json";
    const report = scoreResponses(
      JSON.parse(readFileSync(resolve(options.key), "utf8")),
      parseResponses(readFileSync(responsePath, "utf8"), format),
    );
    if (options.json) console.log(JSON.stringify(report, null, 2));
    else printScore(report);
    if (!report.passed) process.exitCode = 1;
    return;
  }
  usage();
  if (command && !["help", "--help", "-h"].includes(command)) process.exitCode = 1;
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) {
  try { main(); }
  catch (error) { console.error(`오류: ${error.message}`); process.exitCode = 2; }
}
