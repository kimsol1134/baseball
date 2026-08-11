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

// 소스가 바뀌었는데 예전 release 바이너리가 남아 있으면 검사가 낡은 커널을 통과시킨다.
// SwiftPM 증분 빌드는 변경이 없을 때 빠르므로 매번 최신 바이너리를 보장한다.
execFileSync("swift", ["build", "--package-path", packagePath, "-c", "release"], { stdio: "inherit" });
const cli = findCli();
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
    runsPerPa: d.runsAllowed / pa,
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

// ── 육성 축 분화 검사 ──────────────────────────────────────────────────────
// 같은 투수·같은 슬라이더·같은 타자에서 글로벌 능력 하나만 50→70으로 바꾼다.
// 구종 선택이나 프리셋 프로필 차이를 제거해야 어떤 능력이 어떤 결과를 샀는지 알 수 있다.
const AXIS = ["--preset", "power_prospect", "--strategy", "fixed", "--pitch", "slider",
  "--contact", "50", "--discipline", "50", "--power", "50", "--iterations", "6000"];
const axisBase = batch([...AXIS, "--stuff", "50", "--command", "50", "--movement", "50", "--stamina", "50"]);
const axisStuff = batch([...AXIS, "--stuff", "70", "--command", "50", "--movement", "50", "--stamina", "50"]);
const axisCommand = batch([...AXIS, "--stuff", "50", "--command", "70", "--movement", "50", "--stamina", "50"]);
const axisMovement = batch([...AXIS, "--stuff", "50", "--command", "50", "--movement", "70", "--stamina", "50"]);

if (axisStuff.kRate < Math.max(axisCommand.kRate, axisMovement.kRate) + 0.015) {
  failures.push(`구위 정체성 부족: K% ${axisStuff.kRate.toFixed(3)}가 제구/변화보다 1.5%p 이상 높지 않음`);
} else {
  console.log(`  통과: 구위 70은 탈삼진 1위 (${axisStuff.kRate.toFixed(3)})`);
}
if (axisCommand.bbRate > Math.min(axisStuff.bbRate, axisMovement.bbRate) - 0.012) {
  failures.push(`제구 정체성 부족: BB% ${axisCommand.bbRate.toFixed(3)}가 구위/변화보다 1.2%p 이상 낮지 않음`);
} else {
  console.log(`  통과: 제구 70은 볼넷 억제 1위 (${axisCommand.bbRate.toFixed(3)})`);
}
if (axisMovement.avg > Math.min(axisStuff.avg, axisCommand.avg) - 0.004) {
  failures.push(`변화 정체성 부족: 피안타율 ${axisMovement.avg.toFixed(3)}가 구위/제구보다 0.4%p 이상 낮지 않음`);
} else {
  console.log(`  통과: 변화 70은 피안타 억제 1위 (${axisMovement.avg.toFixed(3)})`);
}
for (const [label, result] of [["구위", axisStuff], ["제구", axisCommand], ["변화", axisMovement]]) {
  if (result.runsPerPa >= axisBase.runsPerPa) {
    failures.push(`${label} 70이 기준보다 실점을 줄이지 못함: ${result.runsPerPa.toFixed(3)} >= ${axisBase.runsPerPa.toFixed(3)}`);
  }
}


// ── 등판 단위 검사 ───────────────────────────────────────────────────────────
//
// 타석 분포만으로는 시즌 성적이 야구처럼 보이는지 알 수 없다. 6이닝 선발이 몇 이닝을
// 버티는지, 승패가 어떻게 갈리는지는 경기 단위로만 드러난다. 자동 시즌 성적이 화면에
// 나오기 시작했으므로 여기가 회귀 지점이다.
//
// **밴드의 성격**: 아래 값은 "실제 야구의 정답"이 아니라 **2026-07-26 실측값 기준의 회귀
// 탐지선**이다. 지금 커널은 실제 야구보다 투수에게 유리하다 — 신인급 프리셋(구위 42·제구 34)이
// 리그 평균 타자를 상대로 BB9 1.79(MLB 약 3.2)·K9 9.81(약 8.5)·RA9 3.42(약 4.4)를 찍는다.
// 그 격차는 커널 판정의 문제이지 이 파일의 문제가 아니며, 밴드를 실제 야구 값으로 좁히면
// 오늘 당장 실패한다. 격차를 줄이는 것은 별도 작업이고, 그때 이 밴드도 함께 좁힌다.
// 밴드를 넓혀 통과시키지 않는다 — 벗어나면 원인을 찾는다.
function outings(args) {
  const raw = execFileSync(cli, args, { encoding: "utf8" });
  const d = JSON.parse(raw);
  const outs = d.outs;
  return {
    inningsPerGame: outs / 3 / d.games,
    ra9: (d.runsAllowed * 27) / outs,
    k9: (d.strikeouts * 27) / outs,
    bb9: (d.walks * 27) / outs,
    h9: (d.hits * 27) / outs,
    hr9: (d.homeRuns * 27) / outs,
    winRate: d.wins / d.games,
    noDecisionRate: d.noDecisions / d.games,
    saveRate: d.saves / d.games,
  };
}

const starter = outings(["--outings", "400"]);
expect("선발 평균 이닝", starter.inningsPerGame, 4.6, 6.2);
expect("선발 9이닝당 실점", starter.ra9, 2.6, 4.6);
expect("선발 K/9", starter.k9, 8.0, 11.5);
expect("선발 BB/9", starter.bb9, 1.2, 3.2);
expect("선발 승률", starter.winRate, 0.3, 0.62);
expect("선발 노디시전 비율", starter.noDecisionRate, 0.1, 0.35);

// 마무리는 세이브 전환율이 핵심이다. 한 번도 날리지 않으면 마무리를 맡는 긴장이 없어진다.
const closer = outings(["--outings", "400", "--role", "closer", "--outs-target", "3"]);
expect("마무리 세이브 비율", closer.saveRate, 0.15, 0.4);
expect("마무리 9이닝당 실점", closer.ra9, 2.2, 5.2);

// 제구형이 파워형보다 볼넷이 적어야 한다. 프리셋 차이가 성적에 반영되지 않으면
// 선수 육성 자체가 의미를 잃는다.
const commander = outings(["--outings", "300", "--preset", "precision_commander"]);
if (!(commander.bb9 < starter.bb9)) {
  failures.push(`제구형 BB/9(${commander.bb9.toFixed(2)})가 파워형(${starter.bb9.toFixed(2)})보다 많음`);
} else {
  console.log(`  통과: 제구형 < 파워형 볼넷 위계 (${commander.bb9.toFixed(2)} < ${starter.bb9.toFixed(2)})`);
}

// 체력은 첫 공을 강화하지 않고 긴 등판에서만 보상한다. 동일 프로필에 글로벌 체력만 바꿔
// 목표 아웃·후반 성적이 달라지는지 확인한다.
const staminaBase = outings(["--outings", "500", "--stuff", "50", "--command", "50", "--movement", "50", "--stamina", "50"]);
const staminaHigh = outings(["--outings", "500", "--stuff", "50", "--command", "50", "--movement", "50", "--stamina", "80"]);
if (staminaHigh.inningsPerGame < staminaBase.inningsPerGame + 0.25) {
  failures.push(`체력 이닝 효과 부족: ${staminaBase.inningsPerGame.toFixed(2)}→${staminaHigh.inningsPerGame.toFixed(2)}`);
} else {
  console.log(`  통과: 체력 80은 더 긴 이닝 (${staminaBase.inningsPerGame.toFixed(2)}→${staminaHigh.inningsPerGame.toFixed(2)})`);
}
if (staminaHigh.ra9 >= staminaBase.ra9) {
  failures.push(`체력 후반 안정성 부족: RA/9 ${staminaBase.ra9.toFixed(2)}→${staminaHigh.ra9.toFixed(2)}`);
} else {
  console.log(`  통과: 체력 80은 후반 실점 억제 (${staminaBase.ra9.toFixed(2)}→${staminaHigh.ra9.toFixed(2)})`);
}

// 시작 청사진도 동일 능력 예산(합 150) 안에서 대표 지표가 하나씩 달라야 한다.
const presetPower = outings(["--outings", "500", "--preset", "power_prospect"]);
const presetCommand = outings(["--outings", "500", "--preset", "precision_commander"]);
const presetMovement = outings(["--outings", "500", "--preset", "breaking_ball_artist"]);
const presetStamina = outings(["--outings", "500", "--preset", "innings_eater"]);
const presetRuns = [presetPower, presetCommand, presetMovement, presetStamina];
if (presetPower.k9 < Math.max(...presetRuns.slice(1).map((value) => value.k9))) {
  failures.push(`시작 강속구형 K/9(${presetPower.k9.toFixed(2)})가 1위가 아님`);
} else console.log(`  통과: 시작 강속구형 K/9 1위 (${presetPower.k9.toFixed(2)})`);
if (presetCommand.bb9 > Math.min(presetPower.bb9, presetMovement.bb9, presetStamina.bb9)) {
  failures.push(`시작 제구형 BB/9(${presetCommand.bb9.toFixed(2)})가 1위가 아님`);
} else console.log(`  통과: 시작 제구형 BB/9 1위 (${presetCommand.bb9.toFixed(2)})`);
if (presetMovement.h9 > Math.min(presetPower.h9, presetCommand.h9, presetStamina.h9)) {
  failures.push(`시작 변화구형 H/9(${presetMovement.h9.toFixed(2)})가 1위가 아님`);
} else console.log(`  통과: 시작 변화구형 H/9 1위 (${presetMovement.h9.toFixed(2)})`);
if (presetStamina.inningsPerGame < Math.max(presetPower.inningsPerGame, presetCommand.inningsPerGame, presetMovement.inningsPerGame)) {
  failures.push(`시작 체력형 이닝/경기(${presetStamina.inningsPerGame.toFixed(2)})가 1위가 아님`);
} else console.log(`  통과: 시작 체력형 이닝/경기 1위 (${presetStamina.inningsPerGame.toFixed(2)})`);

if (failures.length > 0) {
  console.error("\n밸런스 불변식 검사 실패:");
  for (const failure of failures) console.error(`  실패: ${failure}`);
  process.exit(1);
}
console.log("밸런스 불변식 검사 통과: 분포·적응·능력축·체력·시작 청사진·등판 단위 확인");
