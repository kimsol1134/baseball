import { mkdir } from "node:fs/promises";
import path from "node:path";
import { chromium } from "playwright";

const gameURL = process.env.GAME_URL
  ?? "https://baseball-rebirth-last-pitch.kimsol1134.chatgpt.site/?video=development-v9-final";
const outputDir = path.resolve("public/game");

await mkdir(outputDir, { recursive: true });

const browser = await chromium.launch({
  headless: true,
  executablePath: process.env.CHROME_PATH ?? "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
});

const context = await browser.newContext({
  viewport: { width: 1920, height: 1080 },
  deviceScaleFactor: 1,
  colorScheme: "dark",
  reducedMotion: "no-preference",
});

await context.addInitScript(() => window.localStorage.clear());
const page = await context.newPage();

async function shot(name) {
  await page.waitForTimeout(500);
  await page.screenshot({ path: path.join(outputDir, name), animations: "allow" });
  console.log(`captured ${name}`);
}

async function releasePerfect() {
  const release = page.locator(".release-button");
  await release.focus();
  await page.keyboard.down("Space");
  await page.waitForTimeout(325);
  await page.keyboard.up("Space");
  await page.locator(".outcome-card").waitFor({ timeout: 10_000 });
}

async function waitForSession(expected) {
  await page.waitForFunction(
    (session) => document.querySelector(".training-count")?.getAttribute("aria-label")?.includes(`${session}회 완료`),
    expected,
  );
}

async function chooseTraining(name, expectedSession) {
  await page.getByRole("button", { name }).click();
  await waitForSession(expectedSession);
  await page.locator(".training-result").waitFor();
}

async function choosePlan(name) {
  await page.getByRole("button", { name }).click();
  await page.locator(".scout-blueprint.has-plan").waitFor();
}

async function choosePitchDesign(name) {
  await page.getByRole("button", { name }).click();
  await page.locator(".pitch-lab.is-selected").waitFor();
}

async function setPitch(pitch, zone) {
  await page.getByRole("button", { name: pitch }).click();
  await page.getByRole("button", { name: zone, exact: true }).click();
}

async function throwPitch(pitch, zone, { captureSelection, captureOutcome } = {}) {
  await setPitch(pitch, zone);
  if (captureSelection) await shot(captureSelection);
  await releasePerfect();
  if (captureOutcome) await shot(captureOutcome);
}

async function nextPitch() {
  await page.getByRole("button", { name: /다음 공 고르기/ }).click();
  await page.locator(".outcome-card").waitFor({ state: "detached" });
}

async function openTrainingAfterVictory() {
  await page.getByRole("button", { name: /다음 주 다시 육성하기/ }).click();
  await page.locator(".training-screen").waitFor();
}

try {
  await page.goto(gameURL, { waitUntil: "domcontentloaded", timeout: 60_000 });
  await page.getByRole("button", { name: /마지막 주 육성 시작하기/ }).waitFor({ timeout: 60_000 });
  await shot("01-intro.png");

  await page.getByRole("button", { name: /마지막 주 육성 시작하기/ }).click();
  await page.locator(".training-screen").waitFor();
  await shot("02-training-start.png");

  // LIFE 02 · Precision: connect three sessions, branch, repeat for mastery, recover.
  await choosePlan(/코너 장인/);
  await shot("03-blueprint-selected.png");

  await chooseTraining(/코스 제구 훈련/, 1);
  await shot("04-day1-command.png");
  await chooseTraining(/타자 영상 분석/, 2);
  await shot("05-day2-combo.png");
  await chooseTraining(/긴 이닝 훈련/, 3);
  await page.locator(".pitch-lab.needs-choice").waitFor();
  await shot("06-day3-pitch-lab.png");

  await choosePitchDesign(/검은 선 제구/);
  await shot("07-precision-design.png");
  await chooseTraining(/코스 제구 훈련/, 4);
  await shot("08-repeat-mastery.png");
  await chooseTraining(/회복과 가동성/, 5);
  await page.getByRole("button", { name: /내 빌드 검증하러 결승전으로/ }).waitFor();
  await shot("09-training-complete.png");

  await page.getByRole("button", { name: /내 빌드 검증하러 결승전으로/ }).click();
  await page.locator(".release-button").waitFor();
  await shot("10-growth-in-match.png");

  // The build is complete, but a deliberately readable pitch proves failure still matters.
  await throwPitch(/슬라이더/, "가운데", { captureOutcome: "11-first-life-hit.png" });
  await page.getByRole("button", { name: /운명 확인하기/ }).click();
  await page.getByRole("heading", { name: /다음 삶에 하나만/ }).waitFor();
  await shot("12-memory-choice.png");

  await page.getByRole("button", { name: /포수의 노트/ }).click();
  await page.getByRole("button", { name: /03번째 삶으로/ }).click();
  await page.locator(".training-screen").waitFor();
  await shot("13-growth-inherited.png");

  // LIFE 03 · Power: a different plan and branch create a visibly different pitcher.
  await choosePlan(/압도형 에이스/);
  await shot("14-next-blueprint.png");
  await page.getByRole("button", { name: /몰아붙이기/ }).click();
  await chooseTraining(/결정구 불펜/, 1);
  await page.getByRole("button", { name: /표준/ }).click();
  await chooseTraining(/타자 영상 분석/, 2);
  await chooseTraining(/코스 제구 훈련/, 3);
  await page.locator(".pitch-lab.needs-choice").waitFor();
  await shot("15-power-pitch-lab.png");

  await choosePitchDesign(/가로지르는 슬라이더/);
  await shot("16-power-design.png");
  await chooseTraining(/결정구 불펜/, 4);
  await shot("17-power-mastery.png");
  await chooseTraining(/회복과 가동성/, 5);
  await page.getByRole("button", { name: /내 빌드 검증하러 결승전으로/ }).waitFor();
  await shot("18-next-build-complete.png");

  await page.getByRole("button", { name: /내 빌드 검증하러 결승전으로/ }).click();
  await page.locator(".release-button").waitFor();
  await throwPitch(/슬라이더/, "바깥쪽 낮게", {
    captureSelection: "19-design-trigger.png",
    captureOutcome: "20-strike-one.png",
  });
  await nextPitch();
  await throwPitch(/포심/, "몸쪽 높게");
  await nextPitch();
  await throwPitch(/체인지업/, "몸쪽 낮게", { captureOutcome: "21-strikeout.png" });

  await page.getByRole("button", { name: /운명 확인하기/ }).click();
  await page.getByRole("heading", { name: /이름이 불렸다/ }).waitFor();
  await shot("22-victory.png");

  await openTrainingAfterVictory();
  await page.getByText("SIGNATURE LEGACY · 1/3").waitFor();
  await shot("23-signature-legacy.png");

  // WEEK 14 · Precision completes the second distinct legacy.
  await choosePlan(/코너 장인/);
  await chooseTraining(/코스 제구 훈련/, 1);
  await chooseTraining(/타자 영상 분석/, 2);
  await chooseTraining(/긴 이닝 훈련/, 3);
  await choosePitchDesign(/검은 선 제구/);
  await chooseTraining(/코스 제구 훈련/, 4);
  await chooseTraining(/회복과 가동성/, 5);
  await page.getByRole("button", { name: /내 빌드 검증하러 결승전으로/ }).click();
  await page.locator(".release-button").waitFor();
  await throwPitch(/포심/, "바깥쪽 높게");
  await nextPitch();
  await throwPitch(/슬라이더/, "바깥쪽 낮게");
  await nextPitch();
  await throwPitch(/체인지업/, "몸쪽 낮게");
  await page.getByRole("button", { name: /운명 확인하기/ }).click();
  await page.getByRole("heading", { name: /이름이 불렸다/ }).waitFor();

  await openTrainingAfterVictory();
  await page.getByText("SIGNATURE LEGACY · 2/3").waitFor();

  // WEEK 15 · Mind game: the final philosophy branches into a sequence weapon.
  await choosePlan(/수싸움 설계자/);
  await chooseTraining(/타자 영상 분석/, 1);
  await chooseTraining(/코스 제구 훈련/, 2);
  await chooseTraining(/회복과 가동성/, 3);
  await page.locator(".pitch-lab.needs-choice").waitFor();
  await shot("24-mind-pitch-lab.png");

  await choosePitchDesign(/역순 설계/);
  await chooseTraining(/타자 영상 분석/, 4);
  await chooseTraining(/회복과 가동성/, 5);
  await page.locator(".signature-live.is-active").waitFor();
  await shot("25-pattern-thief-build.png");

  await page.getByRole("button", { name: /내 빌드 검증하러 결승전으로/ }).click();
  await page.locator(".release-button").waitFor();
  await throwPitch(/포심/, "바깥쪽 높게");
  await nextPitch();
  await setPitch(/슬라이더/, "바깥쪽 낮게");
  await page.locator(".design-trigger.is-active").waitFor();
  await shot("26-sequence-design-trigger.png");
  await releasePerfect();
  await nextPitch();
  await throwPitch(/체인지업/, "몸쪽 낮게", { captureOutcome: "27-final-strikeout.png" });
  await page.getByRole("button", { name: /운명 확인하기/ }).click();
  await page.getByRole("heading", { name: /모두 완성했다/ }).waitFor();
  await page.getByText("투수 철학 완성", { exact: true }).waitFor();
  await shot("28-legacy-archive-complete.png");

  console.log(`Captured 28 player-development game states in ${outputDir}`);
} finally {
  await browser.close();
}
