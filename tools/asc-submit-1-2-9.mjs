#!/usr/bin/env node

// Prepare iOS 1.2.9, attach a processed build, and submit for manual release.
// Usage: node tools/asc-submit-1-2-9.mjs [--dry-run] prepare|attach|inspect|submit [buildNumber]
//
// What's New is read from marketing/appstore/RELEASE_NOTES_1.2.9.md (ko / en / ja).
// Build number is a CLI argument (1.2.8 was 66). Do not hardcode it.
// --dry-run prints the planned ASC calls without reading the AuthKey or calling the API.
// Do not run prepare/attach/submit against the live API from a paperwork-only task.
//
// Archive / export (separate from this script; copy of the 1.2.4–1.2.5 release path):
//   cd apps/ios
//   xcodegen generate
//   xcodebuild -project Baseball.xcodeproj -scheme BaseballIOS -configuration Release \
//     -destination 'generic/platform=iOS' \
//     -archivePath releases/1.2.9/BaseballIOS-1.2.9-bNN.xcarchive \
//     archive
//   # If xcodebuild prints "Failed to Use Accounts":
//     -authenticationKeyPath "$HOME/.appstoreconnect/private_keys/AuthKey_TW3Y8S4M9V.p8" \
//     -authenticationKeyID TW3Y8S4M9V \
//     -authenticationKeyIssuerID f4843e26-5b1f-4b00-bd4a-d24ca4539774
//   xcodebuild -exportArchive \
//     -archivePath releases/1.2.9/BaseballIOS-1.2.9-bNN.xcarchive \
//     -exportPath releases/1.2.9/export-manual \
//     -exportOptionsPlist releases/1.2.5/ExportOptions-AppStore-1.2.5.plist
//   xcrun altool --validate-app --type ios \
//     --file releases/1.2.9/export-manual/BaseballIOS.ipa \
//     --apiKey TW3Y8S4M9V --apiIssuer f4843e26-5b1f-4b00-bd4a-d24ca4539774
//   xcrun altool --upload-app --type ios \
//     --file releases/1.2.9/export-manual/BaseballIOS.ipa \
//     --apiKey TW3Y8S4M9V --apiIssuer f4843e26-5b1f-4b00-bd4a-d24ca4539774
//
// TestFlight what's New: GET /v1/builds/{id}/betaBuildLocalizations, then POST.
// On 409, GET the existing localization id and PATCH whatsNew.

import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const KEY_ID = process.env.ASC_KEY_ID ?? "TW3Y8S4M9V";
const ISSUER = process.env.ASC_ISSUER ?? "f4843e26-5b1f-4b00-bd4a-d24ca4539774";
const APP_ID = process.env.ASC_APP_ID ?? "6794754217";
const VERSION = "1.2.9";
const SOURCE_VERSION = "1.2.8";
const API_ROOT = "https://api.appstoreconnect.apple.com";
const LOCALES = ["en-US", "en-GB", "en-AU", "en-CA", "ko", "ja"];
const ROOT = fileURLToPath(new URL("..", import.meta.url));
const NOTES_PATH = path.join(ROOT, "marketing/appstore/RELEASE_NOTES_1.2.9.md");
const JAPANESE_FORBIDDEN =
  /(?:日本野球機構|甲子園|読売|阪神|ヤクルト|DeNA|オリックス|ソフトバンク|楽天|西武|ロッテ|日本ハム|中日|広島東洋|ジャイアンツ|タイガース|スワローズ|ベイスターズ|カープ|ドラゴンズ|ファイターズ|イーグルス|ライオンズ|マリーンズ|バファローズ|ホークス|死亡|死ぬ|事故死|死後|あの世|異世界転生)/iu;
const FORBIDDEN_TERMS = [
  "KBO",
  "MLB",
  "NPB",
  "메이저리그",
  "프로야구",
  "자이언츠",
  "타이거즈",
  "베어스",
  "라이온즈",
  "트윈스",
  "이글스",
  "위즈",
  "히어로즈",
];

const argv = process.argv.slice(2);
const dryRun = argv.includes("--dry-run") || argv.includes("-n");
const positional = argv.filter((value) => value !== "--dry-run" && value !== "-n");
const command = positional[0];
const BUILD_NUMBER = positional[1] ?? process.env.ASC_BUILD ?? null;

function lengthOf(value) {
  return [...(value ?? "")].length;
}

function markdownSection(markdown, heading) {
  const start = markdown.indexOf(heading);
  if (start < 0) return null;
  const rest = markdown.slice(start + heading.length);
  const next = rest.search(/^## /m);
  return (next < 0 ? rest : rest.slice(0, next)).trim();
}

function loadWhatsNew() {
  if (!fs.existsSync(NOTES_PATH)) throw new Error(`Missing release notes: ${NOTES_PATH}`);
  const markdown = fs.readFileSync(NOTES_PATH, "utf8");
  const ko = markdownSection(markdown, "## whatsNew (ko)");
  const en = markdownSection(markdown, "## whatsNew (en)");
  const ja = markdownSection(markdown, "## whatsNew (ja)");
  if (!ko || !en || !ja) {
    throw new Error(`${NOTES_PATH} must contain ## whatsNew (ko), (en), and (ja)`);
  }
  return {
    "en-US": en,
    "en-GB": en,
    "en-AU": en,
    "en-CA": en,
    ko,
    ja,
  };
}

const WHATS_NEW = loadWhatsNew();

function reviewNotes() {
  const buildLabel = BUILD_NUMBER ? ` (build ${BUILD_NUMBER})` : "";
  return `Version 1.2.9${buildLabel} is a bug-fix for a live layout defect: setup-step Hangul titles were clipped under the header and off the left edge after tapping Next, so players could not read the question. The signed binary keeps titles fully on screen.

The default direct-pitch control remains the timing slider. Automatic release is only an optional accessibility setting.

To review in Japanese, set the device language to Japanese or choose Japanese in iOS Settings > Apps > Mound Reborn > Language. The signed binary contains Japanese app-name, launch-screen, Localizable, GameContent, and InfoPlist resources.

No login or demo account is required. This is an offline single-player game. Game Center authentication is optional. The product is a single upfront purchase with no ads and no in-app purchases. Firebase and Amplitude provide unlinked interaction and diagnostic analytics as disclosed in App Privacy and the privacy policy.

All schools, clubs, competitions, players, uniforms, and baseball organizations are fictional. The app does not use or claim affiliation with any real professional league or club.

To reproduce the previous defect on 1.2.8: open a new career, tap Next through setup, and watch the large Hangul title sit under the progress header with the top of the letters cut off.`;
}

function assertCopy() {
  for (const locale of LOCALES) {
    const copy = WHATS_NEW[locale];
    if (!copy) throw new Error(`카피가 없습니다: ${locale}`);
    const length = lengthOf(copy);
    if (length > 4_000) {
      throw new Error(`${locale} whatsNew가 4,000자를 초과합니다: ${length}`);
    }
    const forbidden = FORBIDDEN_TERMS.filter((term) =>
      copy.toLocaleLowerCase().includes(term.toLocaleLowerCase()),
    );
    if (forbidden.length > 0) throw new Error(`${locale} 실존 명칭 의심 단어: ${forbidden.join(", ")}`);
    if (locale === "ja") {
      const match = copy.match(JAPANESE_FORBIDDEN);
      if (match) throw new Error(`ja 금지 표현: ${match[0]}`);
    }
  }
}

function printPlan() {
  assertCopy();
  const notes = reviewNotes();
  console.log(JSON.stringify({
    dryRun,
    command: command ?? null,
    version: VERSION,
    sourceVersion: SOURCE_VERSION,
    buildNumber: BUILD_NUMBER,
    appId: APP_ID,
    locales: LOCALES,
    notesPath: path.relative(ROOT, NOTES_PATH),
    whatsNew: Object.fromEntries(
      LOCALES.map((locale) => [locale, { length: lengthOf(WHATS_NEW[locale]), text: WHATS_NEW[locale] }]),
    ),
    reviewNotesLength: lengthOf(notes),
    plannedCalls: plannedCalls(command),
  }, null, 2));
}

function plannedCalls(action) {
  const versionPath = `/v1/apps/${APP_ID}/appStoreVersions?filter[platform]=IOS&limit=200`;
  if (action === "prepare") {
    return [
      `GET ${versionPath} (find ${SOURCE_VERSION} and ${VERSION})`,
      `POST /v1/appStoreVersions if ${VERSION} is missing (platform IOS, releaseType MANUAL)`,
      `GET /v1/appStoreVersions/{id}/appStoreVersionLocalizations for source and ${VERSION}`,
      `POST /v1/appStoreVersionLocalizations for any missing locale among ${LOCALES.join(", ")}`,
      `PATCH /v1/appStoreVersionLocalizations/{id} whatsNew for each locale that differs`,
      `GET/POST/PATCH /v1/appStoreReviewDetails with review notes`,
    ];
  }
  if (action === "attach") {
    return [
      `GET ${versionPath} (find ${VERSION})`,
      `GET /v1/builds?filter[app]=${APP_ID}&filter[version]=${BUILD_NUMBER ?? "<buildNumber>"}`,
      `PATCH /v1/appStoreVersions/{id}/relationships/build`,
    ];
  }
  if (action === "inspect") {
    return [
      `GET ${versionPath}`,
      `GET /v1/builds?filter[app]=${APP_ID}&filter[version]=${BUILD_NUMBER ?? "<buildNumber>"}`,
      `GET /v1/appStoreVersions/{id}/appStoreVersionLocalizations`,
      `GET /v1/apps/${APP_ID}/reviewSubmissions?filter[platform]=IOS`,
    ];
  }
  if (action === "submit") {
    return [
      `GET ${versionPath} (find ${VERSION})`,
      `GET /v1/apps/${APP_ID}/reviewSubmissions?filter[platform]=IOS`,
      `POST /v1/reviewSubmissions if none is READY_FOR_REVIEW / WAITING_FOR_REVIEW`,
      `POST /v1/reviewSubmissionItems linking ${VERSION}`,
      `PATCH /v1/reviewSubmissions/{id} submitted=true`,
    ];
  }
  return [
    "prepare: create 1.2.9, copy localizations from 1.2.8, set whatsNew and review notes",
    "attach <buildNumber>: attach a VALID processed build",
    "inspect: read version, build, locales, recent submissions",
    "submit: reviewSubmissions flow, manual release",
  ];
}

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
  if (!BUILD_NUMBER) throw new Error("Build number is required: pass it as the last argument");
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
  assertCopy();
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
    notes: reviewNotes(),
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
  const build = BUILD_NUMBER ? await findBuild() : null;
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

if (dryRun) {
  printPlan();
} else if (command === "prepare") await prepare();
else if (command === "attach") await attach();
else if (command === "inspect") await inspect();
else if (command === "submit") await submit();
else throw new Error("Usage: node tools/asc-submit-1-2-9.mjs [--dry-run] prepare|attach|inspect|submit [buildNumber]");
