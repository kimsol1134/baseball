import assert from "node:assert/strict";
import { test } from "node:test";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

// Load the shipped TypeScript helper the /en page actually calls.
const linksPath = join(dirname(fileURLToPath(import.meta.url)), "../lib/links.ts");
const { appStoreUrl, primaryCta, STOREFRONT_NEUTRAL_APP_STORE_URL, APP_STORE_ID } = await import(
  linksPath
);

test("English CTA sends buyers to a storefront-neutral listing with $ language", () => {
  const cta = primaryCta("hero", { withPrice: true, locale: "en" });
  const href = appStoreUrl("hero", "en");

  assert.equal(cta.href, href, "page CTA must use the same helper as appStoreUrl");
  assert.match(cta.href, /apps\.apple\.com/);
  assert.match(cta.href, new RegExp(APP_STORE_ID));
  assert.doesNotMatch(cta.href, /apps\.apple\.com\/kr\//);
  assert.doesNotMatch(cta.label, /₩/);
  assert.match(cta.label, /\$2\.99/);
  assert.match(STOREFRONT_NEUTRAL_APP_STORE_URL, /apps\.apple\.com\/app\/id6794754217/);
  assert.doesNotMatch(STOREFRONT_NEUTRAL_APP_STORE_URL, /\/kr\//);
});

test("English header CTA also stays off the Korea storefront", () => {
  const cta = primaryCta("header", { locale: "en" });
  assert.match(cta.href, /6794754217/);
  assert.doesNotMatch(cta.href, /\/kr\//);
  assert.doesNotMatch(cta.label, /₩/);
  assert.match(cta.label, /Get on the App Store/);
});
