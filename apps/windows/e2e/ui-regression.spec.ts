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
  await expect(page.getByText("저장된 커리어는 지워지지 않습니다")).toBeVisible();

  const layout = await page.evaluate(() => ({
    viewport: window.innerWidth,
    content: document.documentElement.scrollWidth,
    headerHeight: document.querySelector("header")?.getBoundingClientRect().height ?? 999,
  }));
  expect(layout.content).toBeLessThanOrEqual(layout.viewport);
  expect(layout.headerHeight).toBeLessThan(180);
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
