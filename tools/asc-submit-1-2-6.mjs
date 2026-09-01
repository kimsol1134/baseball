#!/usr/bin/env node

// Prepare iOS 1.2.6, attach processed build 64, and submit for manual release.
// Usage: node tools/asc-submit-1-2-6.mjs prepare|attach|inspect|submit

import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const KEY_ID = process.env.ASC_KEY_ID ?? "TW3Y8S4M9V";
const ISSUER = process.env.ASC_ISSUER ?? "f4843e26-5b1f-4b00-bd4a-d24ca4539774";
const APP_ID = process.env.ASC_APP_ID ?? "6794754217";
const VERSION = "1.2.6";
const BUILD_NUMBER = "64";
const SOURCE_VERSION = "1.2.5";
const API_ROOT = "https://api.appstoreconnect.apple.com";
const LOCALES = ["en-US", "en-GB", "en-AU", "en-CA", "ko", "ja"];

const COPY = {
  ko: `가을은 한 경기로 끝나지 않습니다.

정규시즌 순위와 팀 전력이 포스트시즌의 남은 경기까지 이어집니다. 직접 등판한 뒤에도 시리즈 전적이 계속되고, 불펜 투수는 연투할지 결정전을 위해 쉴지 선택할 수 있습니다.

마지막 한 구는 여전히 당신이 직접 던집니다.`,
  ja: `秋は、一試合では終わりません。

レギュラーシーズンの順位とチーム力が、ポストシーズンの残り試合にも反映されます。自分の登板後もシリーズは続き、救援投手は連投するか、決戦に備えて休むかを選べます。

最後の一球は、これまでどおり自分で投げます。`,
  en: `October is bigger than one outing.

Regular-season standings and team strength now carry into every remaining postseason game. The series continues after your appearance, and relievers can choose whether to pitch on consecutive days or rest for a deciding game.

You still throw every important pitch.`,
};

const WHATS_NEW = {
  "en-US": COPY.en,
  "en-GB": COPY.en,
  "en-AU": COPY.en,
  "en-CA": COPY.en,
  ko: COPY.ko,
  ja: COPY.ja,
};

const REVIEW_NOTES = `Version 1.2.6 (build 64) expands the fictional professional postseason into a persistent series rather than resolving the whole result from one player outing. The remaining games use regular-season standings and team strength, while still allowing upsets. A relief pitcher who appeared in the previous game can choose to pitch again with added fatigue or rest for a potential deciding game. The series score, opponent, game history, fatigue choice, and opponent batting memory persist across save and restore.

The default direct-pitch control remains the timing slider. Automatic release is only an optional accessibility setting. No immediate random injury removes the player's opportunity immediately after making the postseason availability choice.

To review in Japanese, set the device language to Japanese or choose Japanese in iOS Settings > Apps > Mound Reborn > Language. The signed binary contains Japanese app-name, launch-screen, Localizable, GameContent, and InfoPlist resources.

No login or demo account is required. This is an offline single-player game. Game Center authentication is optional. The product is a single upfront purchase with no ads and no in-app purchases. Firebase and Amplitude provide unlinked interaction and diagnostic analytics as disclosed in App Privacy and the privacy policy.

All schools, clubs, competitions, players, uniforms, and baseball organizations are fictional. The app does not use or claim affiliation with any real professional league or club.`;

function token() {
  const keyPath = path.join(os.homedir(), ".appstoreconnect", "private_keys", `AuthKey_${KEY_ID}.p8`);
  if (!fs.existsSync(keyPath)) throw new Error(`Missing App Store Connect key: ${keyPath}`);
  const now = Math.floor(Date.now() / 1000);
  const encode = (value) => Buffer.from(JSON.stringify(value)).toString("base64url");
  const header = encode({ alg: "ES256", kid: KEY_ID, typ: "JWT" });
  const payload = encode({ iss: ISSUER, iat: now, exp: now + 600, aud: "appstoreconnect-v1" });
  const signature = crypto.sign("sha256", Buffer.from(`${header}.${payload}`), {
    key: fs.readFileSync(keyPath, "utf8"),
    dsaEncoding: "ieee-p1363",
  }).toString("base64url");
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
  if (!response.ok) throw new Error(`${method} ${url}\n${response.status} ${text.slice(0, 4000)}`);
  return text ? JSON.parse(text) : null;
}

async function all(pathOrUrl) {
  const rows = [];
  let next = pathOrUrl;
  while (next) {
    const page = await request(next.startsWith(API_ROOT) ? next.slice(API_ROOT.length) : next);
    rows.push(...page.data);
    next = page.links?.next ?? null;
  }
  return rows;
}

async function findVersion(versionString) {
  const versions = await all(`/v1/apps/${APP_ID}/appStoreVersions?filter[platform]=IOS&limit=200`);
  return versions.find((item) => item.attributes.versionString === versionString) ?? null;
}

async function findBuild() {
  const builds = await all(`/v1/builds?filter[app]=${APP_ID}&filter[version]=${BUILD_NUMBER}&limit=10`);
  return builds.find((item) => item.attributes.version === BUILD_NUMBER && !item.attributes.expired) ?? null;
}

async function waitForLocalizations(versionID, timeoutMs = 120_000) {
  const started = Date.now();
  while (Date.now() - started < timeoutMs) {
    const rows = await all(`/v1/appStoreVersions/${versionID}/appStoreVersionLocalizations?limit=200`);
    if (LOCALES.every((locale) => rows.some((row) => row.attributes.locale === locale))) return rows;
    await new Promise((resolve) => setTimeout(resolve, 3000));
  }
  throw new Error("Timed out waiting for App Store localizations");
}

async function prepare() {
  const source = await findVersion(SOURCE_VERSION);
  if (!source) throw new Error(`Missing source version ${SOURCE_VERSION}`);
  let version = await findVersion(VERSION);
  if (!version) {
    version = (await request("/v1/appStoreVersions", {
      method: "POST",
      body: {
        data: {
          type: "appStoreVersions",
          attributes: {
            platform: "IOS",
            versionString: VERSION,
            copyright: source.attributes.copyright ?? "© 2026 Sol Kim",
            releaseType: "MANUAL",
          },
          relationships: { app: { data: { type: "apps", id: APP_ID } } },
        },
      },
    })).data;
    console.log(`Created version ${VERSION}: ${version.id}`);
  }

  const sourceLocalizations = await all(`/v1/appStoreVersions/${source.id}/appStoreVersionLocalizations?limit=200`);
  let localizations = await all(`/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations?limit=200`);
  for (const locale of LOCALES) {
    if (localizations.some((row) => row.attributes.locale === locale)) continue;
    const sourceLocalization = sourceLocalizations.find((row) => row.attributes.locale === locale);
    await request("/v1/appStoreVersionLocalizations", {
      method: "POST",
      body: {
        data: {
          type: "appStoreVersionLocalizations",
          attributes: {
            locale,
            whatsNew: WHATS_NEW[locale],
            description: sourceLocalization?.attributes.description ?? WHATS_NEW[locale],
            keywords: sourceLocalization?.attributes.keywords,
            promotionalText: sourceLocalization?.attributes.promotionalText,
            marketingUrl: sourceLocalization?.attributes.marketingUrl,
            supportUrl: sourceLocalization?.attributes.supportUrl,
          },
          relationships: { appStoreVersion: { data: { type: "appStoreVersions", id: version.id } } },
        },
      },
    });
  }
  localizations = await waitForLocalizations(version.id);
  for (const locale of LOCALES) {
    const localization = localizations.find((row) => row.attributes.locale === locale);
    if (localization.attributes.whatsNew === WHATS_NEW[locale]) continue;
    await request(`/v1/appStoreVersionLocalizations/${localization.id}`, {
      method: "PATCH",
      body: {
        data: {
          type: "appStoreVersionLocalizations",
          id: localization.id,
          attributes: { whatsNew: WHATS_NEW[locale] },
        },
      },
    });
  }

  let sourceDetail;
  try {
    sourceDetail = (await request(`/v1/appStoreVersions/${source.id}/appStoreReviewDetail`)).data;
  } catch {
    sourceDetail = null;
  }
  let detail;
  try {
    detail = (await request(`/v1/appStoreVersions/${version.id}/appStoreReviewDetail`)).data;
  } catch {
    detail = null;
  }
  const attributes = {
    contactFirstName: sourceDetail?.attributes.contactFirstName,
    contactLastName: sourceDetail?.attributes.contactLastName,
    contactPhone: sourceDetail?.attributes.contactPhone,
    contactEmail: sourceDetail?.attributes.contactEmail,
    demoAccountRequired: false,
    notes: REVIEW_NOTES,
  };
  if (detail) {
    await request(`/v1/appStoreReviewDetails/${detail.id}`, {
      method: "PATCH",
      body: { data: { type: "appStoreReviewDetails", id: detail.id, attributes } },
    });
  } else {
    await request("/v1/appStoreReviewDetails", {
      method: "POST",
      body: {
        data: {
          type: "appStoreReviewDetails",
          attributes,
          relationships: { appStoreVersion: { data: { type: "appStoreVersions", id: version.id } } },
        },
      },
    });
  }
  console.log(`Prepared ${VERSION} for manual release`);
}

async function attach() {
  const version = await findVersion(VERSION);
  const build = await findBuild();
  if (!version) throw new Error(`Missing version ${VERSION}`);
  if (!build) throw new Error(`Build ${BUILD_NUMBER} is not visible yet`);
  if (build.attributes.processingState !== "VALID") {
    throw new Error(`Build ${BUILD_NUMBER} is ${build.attributes.processingState}`);
  }
  await request(`/v1/appStoreVersions/${version.id}/relationships/build`, {
    method: "PATCH",
    body: { data: { type: "builds", id: build.id } },
  });
  console.log(`Attached build ${BUILD_NUMBER}: ${build.id}`);
}

async function inspect() {
  const version = await findVersion(VERSION);
  const build = await findBuild();
  console.log(JSON.stringify({
    version: version ? { id: version.id, state: version.attributes.appStoreState, releaseType: version.attributes.releaseType } : null,
    build: build ? { id: build.id, number: build.attributes.version, state: build.attributes.processingState, expired: build.attributes.expired } : null,
  }, null, 2));
  if (version) {
    const localizations = await all(`/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations?limit=200`);
    console.log("locales", localizations.map((row) => row.attributes.locale).sort().join(","));
  }
  const submissions = await all(`/v1/apps/${APP_ID}/reviewSubmissions?filter[platform]=IOS&limit=20`);
  for (const submission of submissions.slice(0, 5)) {
    console.log(`submission ${submission.id} ${submission.attributes.state}`);
  }
}

async function submit() {
  const version = await findVersion(VERSION);
  if (!version) throw new Error(`Missing version ${VERSION}`);
  const submissions = await all(`/v1/apps/${APP_ID}/reviewSubmissions?filter[platform]=IOS&limit=50`);
  let submission = submissions.find((item) => ["READY_FOR_REVIEW", "WAITING_FOR_REVIEW"].includes(item.attributes.state));
  if (submission?.attributes.state === "WAITING_FOR_REVIEW") {
    console.log(`Already waiting for review: ${submission.id}`);
    return;
  }
  if (!submission) {
    submission = (await request("/v1/reviewSubmissions", {
      method: "POST",
      body: {
        data: {
          type: "reviewSubmissions",
          attributes: { platform: "IOS" },
          relationships: { app: { data: { type: "apps", id: APP_ID } } },
        },
      },
    })).data;
  }
  const items = await all(`/v1/reviewSubmissions/${submission.id}/items?limit=50`);
  if (!items.some((item) => item.relationships?.appStoreVersion?.data?.id === version.id)) {
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
  }
  const result = (await request(`/v1/reviewSubmissions/${submission.id}`, {
    method: "PATCH",
    body: { data: { type: "reviewSubmissions", id: submission.id, attributes: { submitted: true } } },
  })).data;
  console.log(`Submitted ${result.id}: ${result.attributes.state}`);
}

const command = process.argv[2];
if (command === "prepare") await prepare();
else if (command === "attach") await attach();
else if (command === "inspect") await inspect();
else if (command === "submit") await submit();
else throw new Error("prepare | attach | inspect | submit");
