import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

import { analyzeSources, extractSwiftStrings } from "../check-korean-game-copy.mjs";
import { parseResponses, preparePacket, scoreResponses } from "../evaluate-korean-copy.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, "../..");
const fixture = (name) => readFileSync(join(here, "fixtures", name), "utf8");
const config = JSON.parse(readFileSync(join(root, "tools/korean-copy.config.json"), "utf8"));

test("Swift extractor skips comments and preserves Korean quotations and variables", () => {
  const entries = extractSwiftStrings(fixture("korean-copy-human.swift"), "human.swift");
  assert(entries.some(({ value }) => value.includes("{player}")));
  assert(entries.some(({ value }) => value.includes("\\(pitcher.name)")));
  assert(!entries.some(({ value }) => value.includes("설명을 진행할 수 있습니다")));
});

test("natural game dialogue produces no hard failures or density false positives", () => {
  const report = analyzeSources(
    [{ path: join(here, "fixtures/korean-copy-human.swift"), source: fixture("korean-copy-human.swift") }],
    config,
  );
  assert.equal(report.passed, true);
  assert.equal(report.counts.errors, 0);
  assert.equal(report.counts.warnings, 0);
});

test("template-heavy prose catches high-confidence and density defects", () => {
  const report = analyzeSources(
    [{ path: join(here, "fixtures/korean-copy-aiish.swift"), source: fixture("korean-copy-aiish.swift") }],
    {
      ...config,
      thresholds: {
        ...config.thresholds,
        translationeseMinimum: 2,
        translationesePerHundredStrings: 1,
        boilerplateMinimum: 3,
        boilerplateStringRatio: 0.2,
        repeatedTemplateMinimum: 4,
        repeatedTemplateStringRatio: 0.2,
      },
    },
  );
  const rules = new Set(report.findings.map(({ ruleId }) => ruleId));
  assert.equal(report.passed, false);
  assert(rules.has("duplicate-title-detail"));
  assert(rules.has("long-line"));
  assert(rules.has("translationese-passive"));
  assert(rules.has("translationese-formal-noun"));
  assert(rules.has("translationese-connective"));
  assert(rules.has("boilerplate-density"));
  assert(rules.has("repeated-ngram"));
  assert(rules.has("repeated-template"));
});

test("static event coverage reports a catalog category without a fallback", () => {
  const report = analyzeSources([
    { path: join(root, "HighSchoolContentCatalog.swift"), source: 'let x = .init(id: "evt-x", title: "낯선 사건", category: "mystery", summary: "무슨 일이 생겼다.")' },
    { path: join(root, "RelationshipVoiceCatalog.swift"), source: 'public static let categoryScenes: [String: Scene] = [\n        "health": Scene()\n    ]\n\n    /// 핵심' },
  ], config);
  assert(report.findings.some(({ ruleId }) => ruleId === "event-fallback-coverage"));
  assert.equal(report.passed, false);
});

test("blind packet is stable, balanced by key, and conceals source labels", () => {
  const input = JSON.parse(fixture("blind-pairs.json"));
  const first = preparePacket(input, "test-seed");
  const second = preparePacket(input, "test-seed");
  assert.deepEqual(first, second);
  assert(!JSON.stringify(first.packet).includes('"original"'));
  assert(!JSON.stringify(first.packet).includes('"rewrite"'));
  assert.equal(first.key.items.length, input.items.length);
});

test("checked-in 12-pair packet and key exactly match deterministic generation", () => {
  const input = JSON.parse(readFileSync(join(root, "docs/content-evaluation/korean-copy-relationship-training-12-pairs.json"), "utf8"));
  const generated = preparePacket(input, "baseball-korean-copy-v1");
  const packet = `${JSON.stringify(generated.packet, null, 2)}\n`;
  const key = `${JSON.stringify(generated.key, null, 2)}\n`;
  assert.equal(packet, readFileSync(join(root, "docs/content-evaluation/korean-copy-relationship-training-12-packet.json"), "utf8"));
  assert.equal(key, readFileSync(join(root, "docs/content-evaluation/korean-copy-relationship-training-12-key.json"), "utf8"));
});

test("blind scorer reports required metrics and per-item results", () => {
  const input = JSON.parse(fixture("blind-pairs.json"));
  const { key } = preparePacket(input, "score-seed");
  const responses = key.items.flatMap((item) => ["synthetic-a", "synthetic-b", "synthetic-c", "synthetic-d", "synthetic-e"].map((evaluatorId) => ({
    evaluatorId,
    itemId: item.id,
    preference: item.rewrite,
    aiLikeA: item.rewrite === "A" ? 1 : 5,
    aiLikeB: item.rewrite === "B" ? 1 : 5,
    readabilityA: item.rewrite === "A" ? 5 : 2,
    readabilityB: item.rewrite === "B" ? 5 : 2,
  })));
  const report = scoreResponses(key, responses);
  assert.equal(report.passed, true);
  assert.equal(report.overall.preferenceRate, 1);
  assert.equal(report.overall.aiLikeMedian, 1);
  assert.equal(report.overall.readabilityMedian, 5);
  assert.equal(report.overall.original.aiLikeMedian, 5);
  assert.equal(report.overall.delta.aiLike, -4);
  assert.equal(report.overall.original.readabilityMedian, 2);
  assert.equal(report.overall.delta.readability, 3);
  assert.equal(report.perItem.length, input.items.length);
});

test("blind protocol rejects too few pairs, too few evaluators, and incomplete ballots", () => {
  const input = JSON.parse(fixture("blind-pairs.json"));
  assert.throws(() => preparePacket({ items: input.items.slice(0, 11) }, "short"), /최소 12개/);
  const { key } = preparePacket(input, "coverage-seed");
  const incomplete = key.items.map((item) => ({
    evaluatorId: "synthetic-only",
    itemId: item.id,
    preference: item.rewrite,
    aiLikeA: 2,
    aiLikeB: 2,
    readabilityA: 4,
    readabilityB: 4,
  }));
  assert.throws(() => scoreResponses(key, incomplete), /최소 5명/);
  const fiveEvaluatorsIncomplete = key.items.flatMap((item, itemIndex) =>
    ["synthetic-a", "synthetic-b", "synthetic-c", "synthetic-d", "synthetic-e"].flatMap((evaluatorId) => {
      if (evaluatorId === "synthetic-e" && itemIndex === 0) return [];
      return [{ evaluatorId, itemId: item.id, preference: item.rewrite, aiLikeA: 2, aiLikeB: 2, readabilityA: 4, readabilityB: 4 }];
    }));
  assert.throws(() => scoreResponses(key, fiveEvaluatorsIncomplete), /모든 항목을 완료하지 않았습니다/);
});

test("ties count against the rewrite preference threshold", () => {
  const input = JSON.parse(fixture("blind-pairs.json"));
  const { key } = preparePacket(input, "tie-seed");
  const evaluators = ["synthetic-a", "synthetic-b", "synthetic-c", "synthetic-d", "synthetic-e"];
  let rewriteVoteUsed = false;
  const responses = key.items.flatMap((item) => evaluators.map((evaluatorId) => {
    const preference = rewriteVoteUsed ? "tie" : item.rewrite;
    rewriteVoteUsed = true;
    return { evaluatorId, itemId: item.id, preference, aiLikeA: 1, aiLikeB: 1, readabilityA: 5, readabilityB: 5 };
  }));
  const report = scoreResponses(key, responses);
  assert.equal(report.overall.preferenceRate, 1 / 60);
  assert.equal(report.checks.preference, false);
  assert.equal(report.passed, false);
});

test("CSV response schema is accepted", () => {
  const rows = parseResponses("evaluatorId,itemId,preference,aiLikeA,aiLikeB,readabilityA,readabilityB\ne1,item-1,A,1,4,5,2\n", "csv");
  assert.deepEqual(rows, [{ evaluatorId: "e1", itemId: "item-1", preference: "A", aiLikeA: "1", aiLikeB: "4", readabilityA: "5", readabilityB: "2" }]);
});
