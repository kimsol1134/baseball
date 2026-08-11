import { mkdir, rm } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";
import { completeCareerFixture } from "../../game-web/tests/complete-career.fixture.mjs";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const outputDirectory = path.resolve(scriptDirectory, "../public/web-capture");
const gameURL = "https://baseball-rebirth-last-pitch.kimsol1134.chatgpt.site/?capture=judge";

await mkdir(outputDirectory, { recursive: true });

const browser = await chromium.launch({ headless: true });

async function record(name, run) {
  const temporaryDirectory = path.join(outputDirectory, `.recording-${name}`);
  await mkdir(temporaryDirectory, { recursive: true });
  const context = await browser.newContext({
    viewport: { width: 1440, height: 900 },
    recordVideo: { dir: temporaryDirectory, size: { width: 1440, height: 900 } },
  });
  const page = await context.newPage();

  try {
    await run(page);
    const video = page.video();
    await page.close();
    await video.saveAs(path.join(outputDirectory, `${name}.webm`));
    await context.close();
    await rm(temporaryDirectory, { recursive: true, force: true });
    console.log(`Captured ${name}.webm`);
  } catch (error) {
    await context.close();
    await rm(temporaryDirectory, { recursive: true, force: true });
    throw error;
  }
}

await record("fast-route", async (page) => {
  await page.goto(gameURL, { waitUntil: "domcontentloaded" });
  await page.getByRole("button", { name: "이번 생의 커리어 시작" }).waitFor();
  await page.waitForTimeout(1_200);
  await page.getByRole("button", { name: "이번 생의 커리어 시작" }).click();
  await page.waitForTimeout(1_000);
  await page.getByRole("button", { name: /90초 추천 루트 시작/ }).click();
  await page.waitForTimeout(1_200);
  await page.getByRole("button", { name: /추천 캠프 적용/ }).click();
  await page.waitForTimeout(1_300);
  await page.getByRole("button", { name: /결정구 불펜/ }).click();
  await page.waitForTimeout(800);
  await page.getByRole("button", { name: /회복과 가동성/ }).click();
  await page.waitForTimeout(1_000);

  const startMatch = page.getByRole("button", { name: /내 빌드 검증하러/ });
  await startMatch.scrollIntoViewIfNeeded();
  await startMatch.click();
  await page.waitForTimeout(1_300);

  const release = page.getByRole("button", { name: /누르고 와인드업/ });
  const box = await release.boundingBox();
  if (!box) throw new Error("Release button was not visible during capture.");
  await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
  await page.mouse.down();
  await page.waitForTimeout(325);
  await page.mouse.up();
  await page.waitForTimeout(2_200);
});

await record("rebirth", async (page) => {
  const { profile, match, outcome } = completeCareerFixture();
  const saved = {
    version: 9,
    profile,
    run: { stage: "victory", phase: "review", match, lastOutcome: outcome, selectedMemory: null },
  };
  await page.addInitScript(({ key, value }) => {
    window.localStorage.setItem(key, JSON.stringify(value));
  }, { key: "baseball-rebirth.web-state.v9", value: saved });

  await page.goto(gameURL, { waitUntil: "domcontentloaded" });
  await page.getByRole("heading", { name: /이번 생엔/ }).waitFor();
  await page.waitForTimeout(2_400);
  const rebirth = page.getByRole("button", { name: /유산과 야구혼을 들고 새 선수로/ });
  await rebirth.scrollIntoViewIfNeeded();
  await page.waitForTimeout(1_200);
  await rebirth.click();
  await page.waitForTimeout(2_800);
});

await browser.close();
