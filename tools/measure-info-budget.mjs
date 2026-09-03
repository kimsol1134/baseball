#!/usr/bin/env node
/**
 * First-viewport information budget. Reads `axe describe-ui` from the booted
 * simulator and counts text in y < 874, excluding the tab bar.
 *
 *   node tools/measure-info-budget.mjs --screen hs-training --label before
 *   node tools/measure-info-budget.mjs --screen pro-week --label after --out apps/ios/releases/qa-1.2.9/round3/budget.json
 *
 * Optional: --launch "-uiTestResetCareer,-uiTestDraftedCareerFixture" relaunches
 * the app with those arguments before measuring. --udid overrides the default.
 */
import { execFileSync } from "node:child_process";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../", import.meta.url));
const DEFAULT_UDID = "641C2F6D-BF5F-406F-B22C-FEB35CB4E4BF";
const BUNDLE = "com.solkim.baseball.ios";
const VIEWPORT_HEIGHT = 874;
const TAB_BAR_MIN_Y = 780;

const BUDGETS = {
  "hs-training": { text: 8, long: 1, buttons: 3 },
  "hs-chapter-start": { text: 8, long: 2, buttons: 1 },
  "pitch-ready": { text: 6, long: 0, buttons: 3 },
  "pro-decision": { text: 9, long: 1, buttons: 3 },
  "hs-draft-result": { text: 5, long: 1, buttons: 1 },
  "pro-week": { text: 10, long: 1, buttons: 3 },
};

function argValue(flag, fallback = null) {
  const index = process.argv.indexOf(flag);
  if (index === -1 || index === process.argv.length - 1) return fallback;
  return process.argv[index + 1];
}

function hasFlag(flag) {
  return process.argv.includes(flag);
}

const udid = argValue("--udid", DEFAULT_UDID);
const screen = argValue("--screen", "current");
const label = argValue("--label", "now");
const outPath = argValue(
  "--out",
  join(root, "apps/ios/releases/qa-1.2.9/round3/budget.json")
);
const launchArg = argValue("--launch", null);
const waitMs = Number(argValue("--wait", "4500"));

function run(bin, args, options = {}) {
  return execFileSync(bin, args, {
    encoding: "utf8",
    maxBuffer: 32 * 1024 * 1024,
    ...options,
  });
}

function launchApp(args) {
  try {
    run("xcrun", ["simctl", "terminate", "booted", BUNDLE], { stdio: "ignore" });
  } catch {
    // already stopped
  }
  run("xcrun", ["simctl", "launch", "booted", BUNDLE, ...args]);
  run("sleep", [String(Math.max(1, waitMs / 1000))]);
}

function describeUI() {
  const raw = run("axe", ["describe-ui", "--udid", udid]);
  return JSON.parse(raw);
}

function flatten(node, acc = [], ancestors = []) {
  if (!node || typeof node !== "object") return acc;
  acc.push({ node, ancestors });
  const children = node.children ?? node.AXChildren ?? [];
  for (const child of children) {
    flatten(child, acc, ancestors.concat(node));
  }
  return acc;
}

function frameOf(node) {
  if (node.frame && typeof node.frame.y === "number") {
    return {
      x: node.frame.x ?? 0,
      y: node.frame.y ?? 0,
      width: node.frame.width ?? 0,
      height: node.frame.height ?? 0,
    };
  }
  const ax = node.AXFrame;
  if (typeof ax === "string") {
    const match = ax.match(/\{\{([-\d.]+),\s*([-\d.]+)\},\s*\{([-\d.]+),\s*([-\d.]+)\}\}/);
    if (match) {
      return {
        x: Number(match[1]),
        y: Number(match[2]),
        width: Number(match[3]),
        height: Number(match[4]),
      };
    }
  }
  return { x: 0, y: 0, width: 0, height: 0 };
}

function isTabBar(node) {
  const type = String(node.type ?? "");
  const role = String(node.role ?? node.AXRole ?? "");
  return type.includes("TabBar") || role.includes("TabBar");
}

function isButton(node) {
  const type = String(node.type ?? "");
  const role = String(node.role ?? node.AXRole ?? "");
  return type === "Button" || role === "AXButton" || type.includes("Button");
}

function hasLabeledDescendant(node) {
  const children = node.children ?? [];
  for (const child of children) {
    const label = String(child.AXLabel ?? child.label ?? "").trim();
    if (label) return true;
    if (hasLabeledDescendant(child)) return true;
  }
  return false;
}

function measure(tree) {
  const roots = Array.isArray(tree) ? tree : [tree];
  const items = [];
  for (const root of roots) flatten(root, items);

  const visible = [];
  for (const { node, ancestors } of items) {
    if (ancestors.some(isTabBar) || isTabBar(node)) continue;
    const frame = frameOf(node);
    if (frame.y >= VIEWPORT_HEIGHT) continue;
    if (frame.y + frame.height <= 0) continue;
    if (frame.y >= TAB_BAR_MIN_Y && isButton(node)) continue;
    const labelText = String(node.AXLabel ?? node.label ?? "").trim();
    if (!labelText) continue;
    if (hasLabeledDescendant(node) && !isButton(node)) continue;
    visible.push({
      label: labelText,
      type: node.type ?? node.role ?? "",
      identifier: node.AXUniqueId ?? node.identifier ?? null,
      y: frame.y,
      button: isButton(node),
    });
  }

  const long = visible.filter((item) => [...item.label].length >= 20);
  const buttons = visible.filter((item) => item.button);
  const numbers = visible.filter((item) => /^\d+$/.test(item.label));

  return {
    screen,
    textChunks: visible.length,
    longSentences: long.length,
    buttons: buttons.length,
    numericLabels: numbers.length,
    longLabels: long.map((item) => item.label),
    buttonLabels: buttons.map((item) => item.label),
    numericValues: numbers.map((item) => item.label),
    labels: visible.map((item) => ({
      label: item.label,
      y: Math.round(item.y),
      type: item.type,
      id: item.identifier,
    })),
  };
}

if (launchArg) {
  const args = launchArg.split(",").map((part) => part.trim()).filter(Boolean);
  launchApp(args);
}

const snapshot = measure(describeUI());
const budget = BUDGETS[screen];
if (budget) {
  snapshot.budget = budget;
  snapshot.over = {
    text: snapshot.textChunks > budget.text,
    long: snapshot.longSentences > budget.long,
    buttons: snapshot.buttons > budget.buttons,
  };
}

if (hasFlag("--json")) {
  process.stdout.write(`${JSON.stringify(snapshot, null, 2)}\n`);
} else {
  const over = snapshot.over
    ? ` over[text=${snapshot.over.text} long=${snapshot.over.long} buttons=${snapshot.over.buttons}]`
    : "";
  process.stdout.write(
    `${screen} ${label}: text=${snapshot.textChunks} long=${snapshot.longSentences} buttons=${snapshot.buttons} numbers=${snapshot.numericLabels}${over}\n`
  );
}

mkdirSync(dirname(outPath), { recursive: true });
let file = { screens: {} };
try {
  file = JSON.parse(readFileSync(outPath, "utf8"));
  if (!file.screens) file.screens = {};
} catch {
  file = { screens: {} };
}
if (!file.screens[screen]) file.screens[screen] = { budget: budget ?? null };
if (budget) file.screens[screen].budget = budget;
file.screens[screen][label] = {
  textChunks: snapshot.textChunks,
  longSentences: snapshot.longSentences,
  buttons: snapshot.buttons,
  numericLabels: snapshot.numericLabels,
  longLabels: snapshot.longLabels,
  measuredAt: new Date().toISOString(),
};
file.updatedAt = new Date().toISOString();
writeFileSync(outPath, `${JSON.stringify(file, null, 2)}\n`);
