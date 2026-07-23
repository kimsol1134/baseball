import { expect, test } from "@playwright/test";
import type { Page } from "@playwright/test";

async function openOfflineApp(page: Page) {
  await page.route("**/api/core", (route) => route.abort("connectionfailed"));
  await page.goto("/");
  await expect(page.getByRole("button", { name: "다시 연결" }).first()).toBeVisible();
}

test("desktop shell keeps recovery and settings usable", async ({ page }, testInfo) => {
  await openOfflineApp(page);
  await expect(page.getByRole("heading", { name: "고교 커리어" })).toBeVisible();
  await expect(page.getByRole("heading", { name: "선수 명단을 아직 불러오지 못했습니다." })).toBeVisible();
  await expect(page.getByText("저장된 커리어는 지워지지 않습니다")).toBeVisible();
  await expect(page.getByRole("button", { name: "다시 연결" })).toHaveCount(1);

  const layout = await page.evaluate(() => ({
    viewport: window.innerWidth,
    content: document.documentElement.scrollWidth,
    headerHeight: document.querySelector("header")?.getBoundingClientRect().height ?? 999,
  }));
  expect(layout.content).toBeLessThanOrEqual(layout.viewport);
  expect(layout.headerHeight).toBeLessThan(180);
  await expect(page).toHaveScreenshot("offline-recovery.png", {
    fullPage: true,
    animations: "disabled",
    caret: "hide",
    maxDiffPixelRatio: 0.12,
    threshold: 0.3,
  });
  await testInfo.attach("desktop-offline", { body: await page.screenshot(), contentType: "image/png" });
});

test("390px, 130% type, and high contrast do not overflow", async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await openOfflineApp(page);

  const settings = page.locator(".settings-menu");
  await settings.locator("summary").click();
  await settings.getByRole("button", { name: /글자/ }).click();
  await settings.getByRole("button", { name: /글자/ }).click();
  await settings.getByRole("button", { name: /고대비/ }).click();

  await expect(page.locator("body")).toHaveClass(/high-contrast/);
  await expect.poll(() => page.evaluate(() => getComputedStyle(document.documentElement).getPropertyValue("--font-scale").trim())).toBe("1.3");
  await settings.locator("summary").click();

  const layout = await page.evaluate(() => ({
    viewport: window.innerWidth,
    content: document.documentElement.scrollWidth,
    headerHeight: document.querySelector("header")?.getBoundingClientRect().height ?? 999,
    retryWidth: document.querySelector<HTMLElement>(".core-unavailable-state button")?.getBoundingClientRect().width ?? 0,
  }));
  expect(layout.content).toBeLessThanOrEqual(layout.viewport);
  expect(layout.headerHeight).toBeLessThan(250);
  expect(layout.retryWidth).toBeGreaterThanOrEqual(44);
  await testInfo.attach("mobile-large-type-high-contrast", { body: await page.screenshot({ fullPage: true }), contentType: "image/png" });
});

test.describe("system motion preference", () => {
  test.use({ reducedMotion: "reduce" });

  test("is merged into the effective app preference", async ({ page }) => {
    await page.emulateMedia({ reducedMotion: "reduce" });
    await openOfflineApp(page);
    await expect(page.locator("body")).toHaveClass(/reduce-motion/);
    await page.locator(".settings-menu summary").click();
    await expect(page.getByRole("button", { name: "모션 감소 시스템 설정" })).toBeDisabled();
  });
});

test("connected core keeps career, result, and GameCast visual baselines", async ({ page }) => {
  await page.emulateMedia({ reducedMotion: "reduce" });
  await page.goto("/");
  await expect(page.getByText("게임 준비 완료")).toBeVisible();
  await expect(page.getByRole("heading", { name: "중학교의 마지막 공에서 드래프트까지" })).toBeVisible();
  await expect(page).toHaveScreenshot("career-setup.png", {
    fullPage: true,
    animations: "disabled",
    caret: "hide",
    maxDiffPixelRatio: 0.12,
    threshold: 0.3,
  });

  await page.getByRole("button", { name: "연습 모드" }).click();
  await expect(page.getByRole("heading", { name: "어떤 투수로 시작할까요?" })).toBeVisible();
  await page.getByRole("button", { name: "훈련 시작" }).click();
  await expect(page.getByRole("heading", { name: "훈련 1회차" })).toBeVisible();
  await page.getByRole("button", { name: "이 훈련 확정" }).click();
  const firstResult = page.locator(".training-result-card");
  await expect(firstResult).toBeVisible();
  await expect(firstResult.getByRole("heading", { name: /결과/ })).toBeVisible();
  await expect(firstResult).toHaveScreenshot("lab-training-result.png", {
    animations: "disabled",
    caret: "hide",
    maxDiffPixelRatio: 0.12,
    threshold: 0.3,
  });

  await page.getByRole("button", { name: "결과 확인하고 계속" }).click();
  await page.getByRole("button", { name: "이 훈련 확정" }).click();
  await page.getByRole("button", { name: "결과 확인하고 계속" }).click();
  await page.getByRole("button", { name: "중요 이닝 시작" }).click();
  await expect(page.getByRole("heading", { name: "중요 이닝" })).toBeVisible();
  await page.getByRole("button", { name: "던지기" }).click();
  const gameCast = page.locator(".gamecast-replay");
  await expect(gameCast).toBeVisible();
  await expect(gameCast).toHaveScreenshot("gamecast-pitch.png", {
    animations: "disabled",
    caret: "hide",
    maxDiffPixelRatio: 0.12,
    threshold: 0.3,
  });
});
