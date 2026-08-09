import { chromium } from "playwright";
import { mkdir } from "node:fs/promises";
import path from "node:path";

const baseURL = process.env.GAME_URL ?? "http://localhost:3000/";
const outputDir = path.resolve("capture/screenshots");

await mkdir(outputDir, { recursive: true });

const browser = await chromium.launch({
  headless: true,
  executablePath:
    process.env.CHROME_PATH ?? "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
});
const context = await browser.newContext({
  viewport: { width: 1920, height: 1080 },
  deviceScaleFactor: 1,
  colorScheme: "dark",
  reducedMotion: "no-preference",
});

await context.addInitScript(() => {
  window.localStorage.clear();
});

const page = await context.newPage();

async function shot(name) {
  await page.screenshot({ path: path.join(outputDir, name), animations: "allow" });
}

async function releasePerfect() {
  const release = page.locator(".release-button");
  await release.focus();
  await page.keyboard.down("Space");
  await page.waitForTimeout(325);
  await page.keyboard.up("Space");
  await page.waitForTimeout(900);
}

await page.goto(baseURL, { waitUntil: "networkidle" });
await page.getByRole("button", { name: /마지막 타자 상대하기/ }).waitFor();
await page.waitForTimeout(400);
await shot("game-01-intro.png");

await page.getByRole("button", { name: /마지막 타자 상대하기/ }).click();
await page.locator(".release-button").waitFor();
await page.waitForTimeout(300);
await shot("game-02-read-and-choose.png");

await page.getByRole("button", { name: /포심/ }).click();
await page.getByRole("button", { name: "가운데", exact: true }).click();
const release = page.locator(".release-button");
await release.focus();
await page.keyboard.down("Space");
await page.waitForTimeout(280);
await shot("game-03-hold-release.png");
await page.keyboard.up("Space");
await page.waitForTimeout(900);
await shot("game-04-first-life-hit.png");

await page.getByRole("button", { name: /운명 확인하기/ }).click();
await page.getByRole("heading", { name: /다음 삶에 하나만/ }).waitFor();
await page.waitForTimeout(250);
await shot("game-05-memory-choice.png");

await page.getByRole("button", { name: /포수의 노트/ }).click();
await page.waitForTimeout(180);
await shot("game-06-memory-selected.png");
await page.getByRole("button", { name: /03번째 삶으로/ }).click();
await page.locator(".release-button").waitFor();
await page.waitForTimeout(300);
await shot("game-07-next-life.png");

await releasePerfect();
await shot("game-08-strike-one.png");
await page.getByRole("button", { name: /다음 공 고르기/ }).click();
await page.waitForTimeout(220);
await shot("game-09-batter-adapts.png");

await releasePerfect();
await page.getByRole("button", { name: /다음 공 고르기/ }).click();
await page.waitForTimeout(220);
await releasePerfect();
await shot("game-10-strikeout.png");

await page.getByRole("button", { name: /운명 확인하기/ }).click();
await page.getByRole("heading", { name: /이름이 불렸다/ }).waitFor();
await page.waitForTimeout(350);
await shot("game-11-victory.png");

await browser.close();
console.log(`Captured 11 deterministic game states in ${outputDir}`);
