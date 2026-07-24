#!/usr/bin/env node
// 밸런스 불변식 게이트: 시뮬레이션 통계 분포가 설계 밴드를 벗어나면 실패한다.
// 기준 타자는 리그 평균(50/50/50)이며, 근거는 docs/GAME_QUALITY_REVIEW_2026-07-23.md §3·§4 Phase 1-2.
import { execFileSync } from "node:child_process";
import { existsSync } from "node:fs";
import path from "node:path";
import process from "node:process";

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");
const packagePath = path.join(root, "packages/simulation-core");

function findCli() {
  const candidates = ["arm64-apple-macosx", "x86_64-apple-macosx", "x86_64-unknown-linux-gnu"]
    .map((triple) => path.join(packagePath, ".build", triple, "release", "simulation-cli"));
  return candidates.find((candidate) => existsSync(candidate));
}

let cli = findCli();
if (!cli) {
  execFileSync("swift", ["build", "--package-path", packagePath, "-c", "release"], { stdio: "inherit" });
  cli = findCli();
}
if (!cli) {
  console.error("밸런스 검사 실패: release simulation-cli를 찾을 수 없습니다.");
  process.exit(1);
}

function batch(args) {
  const raw = execFileSync(cli, args, { encoding: "utf8" });
  const d = JSON.parse(raw);
  const pa = d.plateAppearances;
  const po = d.pitchOutcomes;
  const pr = d.plateAppearanceResults;
  const hits = pr.hit ?? 0;
  const hr = po.home_run ?? 0;
  // A hit-by-pitch reaches base like a walk and shares the coarse `.walk` plate-appearance result,
  // so `pr.walk` counts both. `po.hit_by_pitch` is the terminal HBP pitch (exactly one per HBP PA),
  // so it is the HBP count. BB% must exclude it (HBP is not a walk); AB already excludes both since
  // `pr.walk` here folds them together. Triples ride inside `hits` and stay in play, so AVG/BABIP
  // need no special-casing — only these two derived splits do.
  const hbp = po.hit_by_pitch ?? 0;
  const triples = po.triple ?? 0;
  const walksAndHbp = pr.walk ?? 0;
  const trueWalks = walksAndHbp - hbp;
  const outsInPlay = pr.in_play_out ?? 0;
  const bip = outsInPlay + hits;
  return {
    avg: hits / Math.max(1, pa - walksAndHbp),
    babip: (hits - hr) / Math.max(1, bip - hr),
    kRate: (pr.strikeout ?? 0) / pa,
    bbRate: trueWalks / pa,
    hrPerPa: hr / pa,
    hbpPerPa: hbp / pa,
    tripleShare: triples / Math.max(1, hits),
    foulRate: (po.foul ?? 0) / d.pitches,
    whiffRate: (po.swinging_strike ?? 0) / d.pitches,
    pitchesPerPa: d.averagePitchesPerPlateAppearance,
  };
}

const LEAGUE = ["--contact", "50", "--discipline", "50", "--power", "50", "--iterations", "3000"];
const failures = [];
function expect(label, value, low, high) {
  const line = `${label} = ${typeof value === "number" ? value.toFixed(3) : value} (허용 ${low}~${high})`;
  if (value < low || value > high) failures.push(line);
  else console.log(`  통과: ${line}`);
}

console.log("밸런스 불변식 검사 (리그 평균 타자 50/50/50)");
const base = batch(["--preset", "power_prospect", ...LEAGUE]);
expect("BABIP", base.babip, 0.24, 0.37);
expect("삼진율", base.kRate, 0.16, 0.31);
expect("볼넷율", base.bbRate, 0.04, 0.11);
expect("홈런/타석", base.hrPerPa, 0.005, 0.032);
expect("몸에 맞는 공/타석", base.hbpPerPa, 0.003, 0.02);
expect("3루타/안타", base.tripleShare, 0.005, 0.04);
expect("파울/투구", base.foulRate, 0.11, 0.2);
expect("헛스윙/투구", base.whiffRate, 0.08, 0.16);
expect("투구/타석", base.pitchesPerPa, 3.5, 4.2);

const primary = batch(["--preset", "power_prospect", "--strategy", "primary", "--memory", "persistent", ...LEAGUE]);
const fixedRepeat = batch(["--preset", "power_prospect", "--strategy", "fixed", "--memory", "persistent", ...LEAGUE]);
expect("추천 수락 피안타율(적응 지속)", primary.avg, 0.17, 0.3);
expect("같은 콜 반복 피안타율(적응 지속)", fixedRepeat.avg, 0.24, 0.47);
if (fixedRepeat.avg < primary.avg + 0.03) {
  failures.push(`위계 붕괴: 같은 콜 반복(${fixedRepeat.avg.toFixed(3)})이 추천 수락(${primary.avg.toFixed(3)}) 대비 충분히 불리하지 않습니다.`);
} else {
  console.log(`  통과: 다양한 콜 > 반복 콜 위계 (${primary.avg.toFixed(3)} < ${fixedRepeat.avg.toFixed(3)})`);
}

const lowPower = batch(["--preset", "power_prospect", "--contact", "50", "--discipline", "50", "--power", "40", "--iterations", "3000"]);
const highPower = batch(["--preset", "power_prospect", "--contact", "50", "--discipline", "50", "--power", "60", "--iterations", "3000"]);
if (highPower.hrPerPa <= lowPower.hrPerPa) {
  failures.push(`파워-홈런 단조성 붕괴: power 60 (${highPower.hrPerPa.toFixed(4)}) ≤ power 40 (${lowPower.hrPerPa.toFixed(4)})`);
} else {
  console.log(`  통과: 파워-홈런 단조성 (power 40 ${lowPower.hrPerPa.toFixed(4)} < power 60 ${highPower.hrPerPa.toFixed(4)})`);
}
expect("파워 40 홈런/타석", lowPower.hrPerPa, 0, 0.012);
expect("파워 60 홈런/타석", highPower.hrPerPa, 0.02, 0.07);

const lowContact = batch(["--preset", "power_prospect", "--contact", "45", "--discipline", "50", "--power", "50", "--iterations", "3000"]);
const highContact = batch(["--preset", "power_prospect", "--contact", "56", "--discipline", "50", "--power", "50", "--iterations", "3000"]);
const contactSpread = highContact.avg - lowContact.avg;
expect("컨택 45→56 피안타율 스프레드", contactSpread, 0.005, 0.13);

if (failures.length > 0) {
  console.error("\n밸런스 불변식 검사 실패:");
  for (const failure of failures) console.error(`  실패: ${failure}`);
  process.exit(1);
}
console.log("밸런스 불변식 검사 통과: 분포 밴드·적응 위계·파워 단조성·레이팅 민감도 확인");
