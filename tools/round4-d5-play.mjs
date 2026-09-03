#!/usr/bin/env node
import { execFileSync } from "node:child_process";
import { mkdirSync } from "node:fs";
import { join } from "node:path";

const UDID = "641C2F6D-BF5F-406F-B22C-FEB35CB4E4BF";
const SHOT = "apps/ios/releases/qa-1.2.9/round4/D5";
const DEADLINE = Date.now() + 12 * 60 * 1000;
mkdirSync(SHOT, { recursive: true });

function run(bin, args) {
  try {
    return execFileSync(bin, args, { encoding: "utf8", maxBuffer: 32 * 1024 * 1024 });
  } catch (error) {
    return error.stdout ? String(error.stdout) : "";
  }
}

function frameOf(node) {
  if (node.frame && typeof node.frame.y === "number") return node.frame;
  return { x: 0, y: 0, width: 0, height: 0 };
}

function tree() {
  try {
    return JSON.parse(run("axe", ["describe-ui", "--udid", UDID]));
  } catch {
    return [];
  }
}

function flatten(node, acc = []) {
  if (!node || typeof node !== "object") return acc;
  acc.push(node);
  for (const child of node.children || []) flatten(child, acc);
  return acc;
}

function visibleButtons() {
  const roots = tree();
  const items = [];
  for (const root of Array.isArray(roots) ? roots : [roots]) flatten(root, items);
  const out = [];
  for (const node of items) {
    const id = String(node.AXUniqueId || node.identifier || "");
    const label = String(node.AXLabel || node.label || "");
    const type = String(node.type || "");
    const f = frameOf(node);
    if (!id && !label) continue;
    if (f.y < 40 || f.y > 760) continue;
    if (f.width < 8 || f.height < 8) continue;
    out.push({ id, label, type, x: f.x + f.width / 2, y: f.y + Math.min(f.height, 44) / 2 });
  }
  return out;
}

function tapXY(x, y) {
  const out = run("axe", ["tap", "--udid", UDID, "-x", String(Math.round(x)), "-y", String(Math.round(y)), "--post-delay", "0.45"]);
  return out.includes("completed successfully");
}

function swipeUp() {
  run("axe", ["swipe", "--udid", UDID, "--start-x", "200", "--start-y", "640", "--end-x", "200", "--end-y", "240", "--duration", "0.3", "--post-delay", "0.25"]);
}

function shot(name) {
  run("axe", ["screenshot", "--udid", UDID, "--output", join(SHOT, `${name}.png`)]);
  console.log("SHOT", name);
}

const PRIORITY = [
  "pro.notice.banner.dismiss",
  "pro.injury.result.acknowledge",
  "pro.contractOffer.confirm.accept",
  "pro.contractOffer.ambition.franchise_icon",
  "pro.contractOffer.sign",
  "hs.enterPro",
  "hs.draft.result.continue",
  "pro.seasonDecision.confirm",
  "pro.settlement.acknowledge",
  "pro.seasonReview.confirm",
  "pro.offseasonInvestment.choice.none",
  "pro.offseasonInvestment.confirm",
  "pro.offseason.arrow.forward.circle",
  "pro.game.start",
  "pitch.throw",
  "pitch.nextBatter",
  "pitch.finish",
  "pro.plan.recover",
  "pro.plan.earn_trust",
  "pro.plan.refine_command",
  "pro.advanceWeek",
  "pro.advanceSegment",
];

let settlements = 0;
let steps = 0;
const phases = new Set();
let swipes = 0;

while (Date.now() < DEADLINE && steps < 500) {
  steps += 1;
  const buttons = visibleButtons();
  const ids = new Set(buttons.map((b) => b.id));
  if (ids.has("pro.seasonSettlement") || buttons.some((b) => b.id.includes("settlement"))) {
    if (!phases.has(`s${settlements}`)) {
      phases.add(`s${settlements}`);
      settlements += 1;
      shot(`settlement-${settlements}`);
      if (settlements >= 2) break;
    }
  }
  if (ids.has("pro.seasonDecision") && !phases.has("decision")) {
    phases.add("decision");
    shot("04-decision");
  }
  if (ids.has("pro.offseasonInvestment") && !phases.has("off")) {
    phases.add("off");
    shot("07-offseason");
  }
  if (ids.has("pro.retirement.preview") && !phases.has("ret")) {
    phases.add("ret");
    shot("10-retirement-preview");
  }

  let acted = false;
  for (const key of PRIORITY) {
    const hit = buttons.find((b) => b.id === key || b.id.startsWith(key));
    if (hit && tapXY(hit.x, hit.y)) {
      acted = true;
      swipes = 0;
      break;
    }
  }
  if (!acted) {
    const choice = buttons.find((b) => b.id.startsWith("pro.seasonDecision.choice."));
    if (choice && tapXY(choice.x, choice.y)) {
      acted = true;
      swipes = 0;
    }
  }
  if (!acted) {
    const accept = buttons.find((b) => /제안 수락|확인하고 계속|1주 진행|닫기/.test(b.label));
    if (accept && tapXY(accept.x, accept.y)) {
      acted = true;
      swipes = 0;
    }
  }
  if (!acted) {
    swipeUp();
    swipes += 1;
    if (swipes > 6) {
      run("axe", ["swipe", "--udid", UDID, "--start-x", "200", "--start-y", "240", "--end-x", "200", "--end-y", "640", "--duration", "0.25", "--post-delay", "0.2"]);
      swipes = 0;
    }
  }
  if (steps % 25 === 0) {
    console.log("step", steps, "settlements", settlements, "visible", [...ids].filter(Boolean).slice(0, 10).join(","));
    shot(`loop-${steps}`);
  }
}

shot("last");
console.log(JSON.stringify({ steps, settlements, phases: [...phases] }));
process.exit(settlements >= 2 ? 0 : 2);
