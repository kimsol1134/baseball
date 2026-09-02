#!/usr/bin/env node
// Create iOS 1.2.5, apply player-facing What's New, attach a processed build, submit review.
//
//   node tools/asc-submit-1-2-5.mjs check
//   node tools/asc-submit-1-2-5.mjs inspect
//   node tools/asc-submit-1-2-5.mjs prepare
//   node tools/asc-submit-1-2-5.mjs attach <buildId>
//   node tools/asc-submit-1-2-5.mjs submit

import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const KEY_ID = process.env.ASC_KEY_ID ?? "TW3Y8S4M9V";
const ISSUER = process.env.ASC_ISSUER ?? "f4843e26-5b1f-4b00-bd4a-d24ca4539774";
const APP_ID = process.env.ASC_APP_ID ?? "6794754217";
const VERSION = process.env.ASC_VERSION ?? "1.2.5";
const SOURCE_VERSION = process.env.ASC_SOURCE_VERSION ?? "1.2.4";
const API_ROOT = "https://api.appstoreconnect.apple.com";
const LOCALES = ["en-US", "en-GB", "en-AU", "en-CA", "ko", "ja"];

const KO_WHATS_NEW = `이번 생이 끝나도, 다음 공이 이어집니다.

은퇴 뒤 다음 투수로 넘어가는 순간을 더 부드럽게 다듬었습니다. 매주 쌓이는 성장은 눈에 보이는 그대로 남고, 투수연구소에서 고른 훈련도 지금까지 키운 성장을 그대로 이어 갑니다.

마지막 한 구는 여전히 당신이 직접 던집니다.`;

const EN_WHATS_NEW = `Your next career is still yours to throw.

This update makes the handoff after a finished season feel seamless. Weekly growth now stays true to what you see on the board, and training you choose in the pitcher lab keeps the growth you already earned.

You still throw every important pitch.`;

const JA_WHATS_NEW = `今生が終わっても、次の一球は続きます。

引退のあと次の投手へ進む瞬間を、よりなめらかに整えました。週ごとの成長は画面どおりに積み上がり、投手研究所で選んだ練習もこれまで積み上げた成長を引き継ぎます。

最後の一球は、これまでどおり自分で投げます。`;

const WHATS_NEW = {
  "en-US": EN_WHATS_NEW,
  "en-GB": EN_WHATS_NEW,
  "en-AU": EN_WHATS_NEW,
  "en-CA": EN_WHATS_NEW,
  ko: KO_WHATS_NEW,
  ja: JA_WHATS_NEW,
};

const REVIEW_NOTES = `Version 1.2.5 (build 63) restores a blocked next-career handoff in the live 1.2.4 build. After retirement, some players saw a storage-space error and could not continue, even with hundreds of GB free. Reinstalling did not help because the blocking record lived in iCloud Key-Value storage. Weekly growth on the board and pitcher-lab training now keep the growth a player already earned.

To review in Japanese, set the device language to Japanese or choose Japanese in iOS Settings > Apps > Mound Reborn > Language, then start a new career. The localized app name, launch screen, system strings, baseball terminology, numbers, and record formatting are included in the binary.

No login or demo account is required. This is an offline single-player game. Game Center authentication is optional and gameplay continues if it is unavailable. The product is a single upfront purchase with no ads and no in-app purchases. Firebase and Amplitude provide unlinked interaction and diagnostic analytics as disclosed in App Privacy and the privacy policy.

All schools, clubs, competitions, players, uniforms, and baseball organizations are fictional. The app does not use or claim affiliation with any real professional league or club.`;

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
  "ドラゴンズ",
  "タイガース",
  "ジャイアンツ",
  "カープ",
  "ベイスターズ",
  "スワローズ",
  "ファイターズ",
  "ホークス",
  "バファローズ",
  "ライオンズ",
  "マリーンズ",
];

function lengthOf(value) {
  return [...(value ?? "")].length;
}

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
  if (!response.ok) throw new Error(`${method} ${url}\n${response.status} ${text.slice(0, 4000)}`);
  return text ? JSON.parse(text) : null;
}

async function all(pathOrUrl) {
  const rows = [];
  let next = pathOrUrl;
  while (next) {
    const page = await request(next.startsWith("http") ? next.replace(API_ROOT, "") : next);
    rows.push(...page.data);
    next = page.links?.next ?? null;
  }
  return rows;
}

async function findVersion(versionString) {
  const versions = await all(`/v1/apps/${APP_ID}/appStoreVersions?filter[platform]=IOS&limit=200`);
  return versions.find((item) => item.attributes.versionString === versionString) ?? null;
}

function assertCopy() {
  for (const locale of LOCALES) {
    const copy = WHATS_NEW[locale];
    if (!copy) throw new Error(`카피가 없습니다: ${locale}`);
    if (lengthOf(copy) > 4_000) {
      throw new Error(`${locale} whatsNew가 4,000자를 초과합니다: ${lengthOf(copy)}`);
    }
    const forbidden = FORBIDDEN_TERMS.filter((term) => copy.toLocaleLowerCase().includes(term.toLocaleLowerCase()));
    if (forbidden.length > 0) throw new Error(`${locale} 실존 명칭 의심 단어: ${forbidden.join(", ")}`);
    if (/진척|스키마|schema|deadlock|3\/2|저장 공간 오류/u.test(copy)) {
      throw new Error(`${locale} 개발자용 표현이 What's New에 남아 있습니다.`);
    }
    console.log(`${locale}: whatsNew ${lengthOf(copy)}/4000`);
  }
}

async function inspect() {
  const version = await findVersion(VERSION);
  if (!version) {
    console.log(JSON.stringify({ version: VERSION, exists: false }, null, 2));
    const submissions = await all(`/v1/apps/${APP_ID}/reviewSubmissions?filter[platform]=IOS&limit=20`);
    for (const sub of submissions.slice(0, 5)) {
      console.log(`submission ${sub.id} state=${sub.attributes.state} submitted=${sub.attributes.submittedDate ?? "-"}`);
    }
    return;
  }
  const localizations = await all(`/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations?limit=200`);
  console.log(JSON.stringify({
    version: VERSION,
    versionID: version.id,
    appStoreState: version.attributes.appStoreState,
    releaseType: version.attributes.releaseType,
  }, null, 2));
  for (const locale of LOCALES) {
    const loc = localizations.find((item) => item.attributes.locale === locale);
    if (!loc) {
      console.log(`${locale}: missing`);
      continue;
    }
    const wanted = WHATS_NEW[locale];
    console.log(JSON.stringify({
      locale,
      id: loc.id,
      whatsNewMatches: loc.attributes.whatsNew === wanted,
      whatsNewLength: lengthOf(loc.attributes.whatsNew),
      descriptionLength: lengthOf(loc.attributes.description),
      whatsNew: loc.attributes.whatsNew ?? "",
    }, null, 2));
  }
  const submissions = await all(`/v1/apps/${APP_ID}/reviewSubmissions?filter[platform]=IOS&limit=20`);
  for (const sub of submissions.slice(0, 5)) {
    console.log(`submission ${sub.id} state=${sub.attributes.state} submitted=${sub.attributes.submittedDate ?? "-"}`);
  }
}

async function waitForLocalizations(versionId, { timeoutMs = 120_000 } = {}) {
  const started = Date.now();
  while (Date.now() - started < timeoutMs) {
    const localizations = await all(`/v1/appStoreVersions/${versionId}/appStoreVersionLocalizations?limit=200`);
    const missing = LOCALES.filter((locale) => !localizations.some((item) => item.attributes.locale === locale));
    if (missing.length === 0) return localizations;
    console.log(`현지화 대기 중: ${missing.join(", ")}`);
    await new Promise((resolve) => setTimeout(resolve, 3000));
  }
  throw new Error("1.2.5 현지화가 제시간에 생성되지 않았습니다.");
}

async function prepare() {
  assertCopy();
  const source = await findVersion(SOURCE_VERSION);
  if (!source) throw new Error(`${SOURCE_VERSION} 없음`);
  let version = await findVersion(VERSION);
  if (!version) {
    version = (
      await request("/v1/appStoreVersions", {
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
      })
    ).data;
    console.log(`버전 생성 ${VERSION} ${version.id}`);
  } else {
    console.log(`기존 버전 ${VERSION} ${version.attributes.appStoreState} ${version.id}`);
  }

  const sourceLocs = await all(`/v1/appStoreVersions/${source.id}/appStoreVersionLocalizations?limit=200`);
  const locs = await waitForLocalizations(version.id);
  for (const locale of LOCALES) {
    const wantedWhatsNew = WHATS_NEW[locale];
    let loc = locs.find((item) => item.attributes.locale === locale);
    const sourceLoc = sourceLocs.find((item) => item.attributes.locale === locale);
    if (!loc) {
      loc = (
        await request("/v1/appStoreVersionLocalizations", {
          method: "POST",
          body: {
            data: {
              type: "appStoreVersionLocalizations",
              attributes: {
                locale,
                whatsNew: wantedWhatsNew,
                description: sourceLoc?.attributes.description ?? wantedWhatsNew,
                keywords: sourceLoc?.attributes.keywords,
                promotionalText: sourceLoc?.attributes.promotionalText,
                marketingUrl: sourceLoc?.attributes.marketingUrl,
                supportUrl: sourceLoc?.attributes.supportUrl,
              },
              relationships: {
                appStoreVersion: { data: { type: "appStoreVersions", id: version.id } },
              },
            },
          },
        })
      ).data;
      console.log(`현지화 생성 ${locale} ${loc.id}`);
      continue;
    }
    if (loc.attributes.whatsNew === wantedWhatsNew) {
      console.log(`${locale}: What's New 이미 반영됨`);
      continue;
    }
    await request(`/v1/appStoreVersionLocalizations/${loc.id}`, {
      method: "PATCH",
      body: {
        data: {
          type: "appStoreVersionLocalizations",
          id: loc.id,
          attributes: { whatsNew: wantedWhatsNew },
        },
      },
    });
    console.log(`${locale}: What's New 갱신 ${loc.id}`);
  }

  let detail;
  try {
    detail = (await request(`/v1/appStoreVersions/${version.id}/appStoreReviewDetail`)).data;
  } catch {
    const sourceDetail = (await request(`/v1/appStoreVersions/${source.id}/appStoreReviewDetail`)).data;
    detail = (
      await request("/v1/appStoreReviewDetails", {
        method: "POST",
        body: {
          data: {
            type: "appStoreReviewDetails",
            attributes: {
              contactFirstName: sourceDetail.attributes.contactFirstName,
              contactLastName: sourceDetail.attributes.contactLastName,
              contactPhone: sourceDetail.attributes.contactPhone,
              contactEmail: sourceDetail.attributes.contactEmail,
              demoAccountRequired: false,
              notes: REVIEW_NOTES,
            },
            relationships: {
              appStoreVersion: { data: { type: "appStoreVersions", id: version.id } },
            },
          },
        },
      })
    ).data;
    console.log(`심사 메모 생성 ${detail.id}`);
    return version;
  }
  if (detail.attributes.notes !== REVIEW_NOTES) {
    await request(`/v1/appStoreReviewDetails/${detail.id}`, {
      method: "PATCH",
      body: {
        data: {
          type: "appStoreReviewDetails",
          id: detail.id,
          attributes: { notes: REVIEW_NOTES, demoAccountRequired: false },
        },
      },
    });
    console.log(`심사 메모 갱신 ${detail.id}`);
  } else {
    console.log(`심사 메모 이미 반영됨 ${detail.id}`);
  }
  return version;
}

async function attach(buildId) {
  if (!buildId) throw new Error("빌드 ID가 필요합니다.");
  const version = await findVersion(VERSION);
  if (!version) throw new Error(`${VERSION} 없음. 먼저 prepare`);
  await request(`/v1/appStoreVersions/${version.id}/relationships/build`, {
    method: "PATCH",
    body: { data: { type: "builds", id: buildId } },
  });
  console.log(`빌드 ${buildId} 를 ${VERSION} (${version.id})에 연결`);
}

async function submit() {
  const version = await findVersion(VERSION);
  if (!version) throw new Error(`${VERSION} 없음`);
  console.log(`버전 상태 ${version.attributes.appStoreState}`);
  const submissions = await all(`/v1/apps/${APP_ID}/reviewSubmissions?filter[platform]=IOS&limit=50`);
  let submission = submissions.find((sub) =>
    ["READY_FOR_REVIEW", "WAITING_FOR_REVIEW"].includes(sub.attributes.state),
  );
  if (submission?.attributes.state === "WAITING_FOR_REVIEW") {
    console.log(`이미 심사 대기 ${submission.id}`);
    return;
  }
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
    console.log(`제출 생성 ${submission.id}`);
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
        data: {
          type: "reviewSubmissions",
          id: submission.id,
          attributes: { submitted: true },
        },
      },
    })
  ).data;
  console.log(`심사 제출 ${submitted.id} state=${submitted.attributes.state}`);
}

const [command, ...args] = process.argv.slice(2);
if (command === "check") assertCopy();
else if (command === "inspect") await inspect();
else if (command === "prepare") await prepare();
else if (command === "attach") await attach(args[0]);
else if (command === "submit") await submit();
else throw new Error("check | inspect | prepare | attach <buildId> | submit");
