#!/usr/bin/env node
// Cancel the waiting 1.2.1 review, push US conversion listing (keywords, promo,
// restacked first-three screenshots) to English locales, then resubmit.
//
//   node tools/asc-us-conversion-push.mjs

import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const KEY_ID = process.env.ASC_KEY_ID ?? "TW3Y8S4M9V";
const ISSUER = process.env.ASC_ISSUER ?? "f4843e26-5b1f-4b00-bd4a-d24ca4539774";
const APP_ID = process.env.ASC_APP_ID ?? "6794754217";
const VERSION = process.env.ASC_VERSION ?? "1.2.1";
const API_ROOT = "https://api.appstoreconnect.apple.com";
const LOCALES = ["en-US", "en-GB", "en-CA", "en-AU"];
const MEDIA_ROOT = path.resolve("marketing/appstore/en-US");
const KEYWORDS =
  "pitcher,simulation,rebirth,high school,rookie,scout,ace,franchise,bullpen,rotation,legacy,stats,save";
const PROMO =
  "You throw every important pitch. Build a high-school pitcher, chase the draft, carry one legacy into the next career. Pay once. No ads.";

function token() {
  const keyPath = path.join(os.homedir(), ".appstoreconnect", "private_keys", `AuthKey_${KEY_ID}.p8`);
  if (!fs.existsSync(keyPath)) throw new Error(`인증 키가 없습니다: ${keyPath}`);
  const now = Math.floor(Date.now() / 1000);
  const encode = (value) => Buffer.from(JSON.stringify(value)).toString("base64url");
  const header = encode({ alg: "ES256", kid: KEY_ID, typ: "JWT" });
  const payload = encode({ iss: ISSUER, iat: now, exp: now + 600, aud: "appstoreconnect-v1" });
  const signature = crypto
    .sign("sha256", Buffer.from(`${header}.${payload}`), {
      key: fs.readFileSync(keyPath, "utf8"),
      dsaEncoding: "ieee-p1363",
    })
    .toString("base64url");
  return `${header}.${payload}.${signature}`;
}

async function request(pathOrUrl, { method = "GET", body } = {}) {
  const url = pathOrUrl.startsWith("http") ? pathOrUrl : `${API_ROOT}${pathOrUrl}`;
  const response = await fetch(url, {
    method,
    headers: {
      Authorization: `Bearer ${token()}`,
      ...(body ? { "Content-Type": "application/json" } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await response.text();
  if (!response.ok) throw new Error(`${method} ${url}\n${response.status} ${text.slice(0, 2000)}`);
  return text ? JSON.parse(text) : null;
}

async function all(pathOrUrl) {
  const rows = [];
  let next = pathOrUrl;
  while (next) {
    const page = await request(next);
    rows.push(...page.data);
    next = page.links?.next ?? null;
  }
  return rows;
}

async function findVersion() {
  const versions = await all(`/v1/apps/${APP_ID}/appStoreVersions?filter[platform]=IOS&limit=200`);
  const version = versions.find((item) => item.attributes.versionString === VERSION);
  if (!version) throw new Error(`iOS ${VERSION} 버전을 찾지 못했습니다.`);
  return version;
}

async function cancelWaiting() {
  const submissions = await all(`/v1/apps/${APP_ID}/reviewSubmissions?filter[platform]=IOS&limit=50`);
  const cancellable = submissions.filter((sub) =>
    ["WAITING_FOR_REVIEW", "IN_REVIEW", "UNRESOLVED_ISSUES"].includes(sub.attributes.state),
  );
  if (cancellable.length === 0) {
    console.log("취소할 제출 없음");
    return;
  }
  for (const sub of cancellable) {
    await request(`/v1/reviewSubmissions/${sub.id}`, {
      method: "PATCH",
      body: {
        data: { type: "reviewSubmissions", id: sub.id, attributes: { canceled: true } },
      },
    });
    console.log(`제출 취소: ${sub.id} (이전 ${sub.attributes.state})`);
  }
}

function screenshotFiles(directory) {
  const dir = path.join(MEDIA_ROOT, directory);
  return fs
    .readdirSync(dir)
    .filter((name) => /^\d{2}\.png$/i.test(name))
    .sort()
    .map((name) => {
      const file = path.join(dir, name);
      return { file, name: `asc-us-conv-${name}`, size: fs.statSync(file).size };
    });
}

async function uploadOperations(operations, file) {
  const source = fs.readFileSync(file);
  for (const operation of operations) {
    const headers = Object.fromEntries(
      (operation.requestHeaders ?? []).map(({ name, value }) => [name, value]),
    );
    const offset = operation.offset ?? 0;
    const length = operation.length ?? source.length;
    const response = await fetch(operation.url, {
      method: operation.method,
      headers,
      body: source.subarray(offset, offset + length),
    });
    if (!response.ok) {
      throw new Error(`업로드 실패 ${response.status} ${operation.url}\n${(await response.text()).slice(0, 400)}`);
    }
  }
}

async function waitComplete(id) {
  const started = Date.now();
  while (Date.now() - started < 20 * 60 * 1000) {
    const resource = (await request(`/v1/appScreenshots/${id}`)).data;
    const state = resource.attributes.assetDeliveryState?.state;
    if (state === "FAILED") {
      throw new Error(`${id} FAILED ${JSON.stringify(resource.attributes.assetDeliveryState)}`);
    }
    if (state === "COMPLETE") return;
    await new Promise((resolve) => setTimeout(resolve, 3000));
  }
  throw new Error(`${id} 처리 시간 초과`);
}

async function replaceScreenshots(set, files) {
  const current = await all(`/v1/appScreenshotSets/${set.id}/appScreenshots?limit=50`);
  for (const resource of current) {
    await request(`/v1/appScreenshots/${resource.id}`, { method: "DELETE" });
    console.log(`  제거 ${resource.attributes.fileName}`);
  }
  for (const item of files) {
    const created = (
      await request("/v1/appScreenshots", {
        method: "POST",
        body: {
          data: {
            type: "appScreenshots",
            attributes: { fileName: item.name, fileSize: item.size },
            relationships: { appScreenshotSet: { data: { type: "appScreenshotSets", id: set.id } } },
          },
        },
      })
    ).data;
    await uploadOperations(created.attributes.uploadOperations, item.file);
    await request(`/v1/appScreenshots/${created.id}`, {
      method: "PATCH",
      body: { data: { type: "appScreenshots", id: created.id, attributes: { uploaded: true } } },
    });
    await waitComplete(created.id);
    console.log(`  완료 ${item.name}`);
  }
}

async function pushLocale(version, locale) {
  const localizations = await all(
    `/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations?limit=200`,
  );
  const localization = localizations.find((item) => item.attributes.locale === locale);
  if (!localization) throw new Error(`${locale} 현지화 없음`);
  await request(`/v1/appStoreVersionLocalizations/${localization.id}`, {
    method: "PATCH",
    body: {
      data: {
        type: "appStoreVersionLocalizations",
        id: localization.id,
        attributes: { keywords: KEYWORDS, promotionalText: PROMO },
      },
    },
  });
  console.log(`[${locale}] keywords + promo 갱신`);
  const sets = await all(`/v1/appStoreVersionLocalizations/${localization.id}/appScreenshotSets?limit=50`);
  const map = new Map(sets.map((set) => [set.attributes.screenshotDisplayType, set]));
  const sixNine = map.get("APP_IPHONE_67");
  const sixFive = map.get("APP_IPHONE_65");
  if (!sixNine || !sixFive) throw new Error(`${locale} 스크린샷 세트 부족`);
  console.log(`[${locale}] 6.9`);
  await replaceScreenshots(sixNine, screenshotFiles("screenshots-6.9"));
  console.log(`[${locale}] 6.5`);
  await replaceScreenshots(sixFive, screenshotFiles("screenshots-6.5"));
}

async function resubmit(version) {
  const submissions = await all(`/v1/apps/${APP_ID}/reviewSubmissions?filter[platform]=IOS&limit=50`);
  let submission = submissions.find((sub) => ["READY_FOR_REVIEW"].includes(sub.attributes.state));
  if (!submission) {
    submission = (
      await request("/v1/reviewSubmissions", {
        method: "POST",
        body: {
          data: {
            type: "reviewSubmissions",
            attributes: { platform: "IOS" },
            relationships: { app: { data: { type: "apps", id: APP_ID } } },
          },
        },
      })
    ).data;
    console.log(`리뷰 제출 생성 ${submission.id}`);
  }
  const items = await all(`/v1/reviewSubmissions/${submission.id}/items?limit=50`);
  if (items.length === 0) {
    await request("/v1/reviewSubmissionItems", {
      method: "POST",
      body: {
        data: {
          type: "reviewSubmissionItems",
          relationships: {
            reviewSubmission: { data: { type: "reviewSubmissions", id: submission.id } },
            appStoreVersion: { data: { type: "appStoreVersions", id: version.id } },
          },
        },
      },
    });
    console.log(`제출 아이템 추가 ${VERSION}`);
  }
  const submitted = (
    await request(`/v1/reviewSubmissions/${submission.id}`, {
      method: "PATCH",
      body: {
        data: { type: "reviewSubmissions", id: submission.id, attributes: { submitted: true } },
      },
    })
  ).data;
  console.log(`재제출 완료 ${submitted.id} state=${submitted.attributes.state}`);
}

if (KEYWORDS.length > 100) throw new Error(`keywords ${KEYWORDS.length}`);
if (PROMO.length > 170) throw new Error(`promo ${PROMO.length}`);

const version = await findVersion();
console.log(`버전 ${VERSION} state=${version.attributes.appStoreState}`);
await cancelWaiting();
for (let i = 0; i < 8; i++) {
  const refreshed = await findVersion();
  console.log(`  상태 대기 ${refreshed.attributes.appStoreState}`);
  if (!["WAITING_FOR_REVIEW", "IN_REVIEW"].includes(refreshed.attributes.appStoreState)) {
    break;
  }
  await new Promise((resolve) => setTimeout(resolve, 4000));
}
const editable = await findVersion();
if (["WAITING_FOR_REVIEW", "IN_REVIEW", "READY_FOR_SALE"].includes(editable.attributes.appStoreState)) {
  throw new Error(`아직 편집 불가: ${editable.attributes.appStoreState}`);
}
for (const locale of LOCALES) {
  await pushLocale(editable, locale);
}
await resubmit(editable);
