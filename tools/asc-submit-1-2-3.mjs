#!/usr/bin/env node
// Create an iOS version, apply ko/en/ja listing copy, attach a processed build, and submit review.
//
//   node tools/asc-submit-1-2-3.mjs prepare
//   node tools/asc-submit-1-2-3.mjs attach <buildId>
//   node tools/asc-submit-1-2-3.mjs submit

import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const KEY_ID = process.env.ASC_KEY_ID ?? "TW3Y8S4M9V";
const ISSUER = process.env.ASC_ISSUER ?? "f4843e26-5b1f-4b00-bd4a-d24ca4539774";
const APP_ID = process.env.ASC_APP_ID ?? "6794754217";
const BUNDLE_IDENTIFIER = process.env.ASC_BUNDLE_IDENTIFIER ?? "com.solkim.baseball.ios";
const VERSION = process.env.ASC_VERSION ?? "1.2.3";
const SOURCE_VERSION = process.env.ASC_SOURCE_VERSION ?? "1.2.2";
const API_ROOT = "https://api.appstoreconnect.apple.com";

const KO_PROMO =
  "마지막 한 구를 직접 던집니다. 구종·코스를 고르고 손 떼는 타이밍으로 제구가 갈립니다. 지명받지 못하면 다시 태어나 전 생의 한 가지를 남깁니다. 광고·뽑기·인앱 결제 없이, 한 번 사면 고교부터 은퇴까지 전부입니다.";
const EN_PROMO =
  "You throw every important pitch. Pick the spot, time the release. Miss the draft, begin again with one thing from the last life. Pay once. No ads, gacha, or IAP.";
const JA_PROMO =
  "最後の一球も自分で投げる。球種とコースを選び、離すタイミングで制球が決まる。指名されなければまた転生し、前の人生を次の投手に残す。広告・ガチャ・追加課金なし。一度買えば高校から引退まで全部。";

const KO_KEYWORDS =
  "로그라이트,회귀,드래프트,고교,에이스,삼진,오프라인,싱글,광고없음,커리어,성장,선수,타이밍,마운드,제구,구속,구종,선발,신인,피칭,전략,트레이닝,변화구,불펜,포수,회차,각성,사인";
const EN_KEYWORDS =
  "pitcher,simulation,rebirth,high school,rookie,scout,ace,bullpen,rotation,legacy,timing,command";
const JA_KEYWORDS =
  "シミュレーション,ドラフト,高校野球,変化球,リリース,球種,コース,買い切り,オフライン,ブルペン,制球,握り,キャリア,配球,サイン,ウィンドアップ,先発,救援,記録";

const JA_SUBTITLE = "一球ずつ投げて指名を目指すシミュ";

const KO_WHATS_NEW =
  "한 구씩 직접 던지는 손맛은 그대로입니다. 스토어 소개를 그에 맞게 다듬었고, 광고·뽑기·인앱 결제 없이 한 번 사면 고교부터 은퇴까지 열린다는 점을 더 분명히 했습니다.";
const EN_WHATS_NEW =
  "You still throw every important pitch. We sharpened the product page to match: time the release, carry one thing into the next life, and pay once with no ads, gacha, or in-app purchases.";
const JA_WHATS_NEW =
  "一球ずつ自分で投げる手触りはそのままです。ストアの紹介をそれに合わせ、広告・ガチャ・追加課金なしで、一度の購入で高校から引退まで開くことをはっきりさせました。";

const REVIEW_KO_WHATS_NEW =
  "부상이 생기면 원인과 회복 기간, 다음 행동을 바로 알려 줍니다. 반복 설명은 처음만 자세히 보고 이후에는 간단히 접을 수 있습니다. 능력은 익숙한 1–100으로 표시되며, 100 이후에도 숙련 레벨로 계속 성장합니다.";
const REVIEW_EN_WHATS_NEW =
  "Injuries now explain their cause, recovery time, and next step. Repeated explanations can collapse after the first read. Ratings use a familiar 1–100 scale, and pitchers keep growing through mastery after reaching 100.";
const REVIEW_JA_WHATS_NEW =
  "負傷時に原因・回復期間・次の行動をすぐ確認できるようになりました。繰り返し説明は最初だけ詳しく表示し、その後は簡潔にできます。能力は1〜100表示になり、100到達後も熟練レベルで成長し続けます。";

const releaseWhatsNew = (legacy, review) => VERSION === "1.2.4" ? review : legacy;

const KO_DESCRIPTION = `공 하나하나를 당신이 직접 던지는 야구 게임입니다.

구종과 코스를 고르고, 화면을 길게 눌러 와인드업하고, 손을 떼는 타이밍으로 제구가 갈립니다. 자동으로 굴러가는 시뮬레이션을 구경하는 게임이 아닙니다.

고교 3년, 단 한 번의 드래프트. 지명받지 못하면 다시 태어나 기억 세 장만 안고 1학년 봄부터 다시 시작합니다.

■ 한 구의 무게
· 구종 4종 × 코스 9칸 × 노림 3종 × 힘 배분 3단
· 포수가 이유와 함께 사인을 냅니다. 따를지 고칠지는 당신이 정합니다
· 같은 공을 반복하면 타자가 읽습니다. 화면이 그 정도를 알려 줍니다
· 던진 공은 궤적과 타구로 다시 재생됩니다 — 구속·회전·낙차까지

■ 3년의 선택
· 학교 선택 — 감독과 포수가 정해지고, 3년 동안 바꿀 수 없습니다
· 훈련·관계·중요 경기가 매주 당신의 시간을 두고 다툽니다
· 재능에는 등급이 있고, 벽은 두드려야 열립니다(만개)
· 각성 3회 — 되돌릴 수 없는 선택으로 투수의 정체성이 정해집니다
· 팔은 소모품입니다. 무리하면 그 회차가 거기서 끝납니다

■ 환생, 그리고 다음 회차
· 회차가 끝나면 야구혼과 기억 카드가 남습니다
· 영혼 상점에서 야구혼으로 재능 돌파·기억 확장 같은 규칙을 바꿉니다. 실제 돈은 쓰지 않습니다
· 자발적 핸디캡(카르마)을 걸수록 다음 회차 계승이 커집니다
· 회차마다 바람·숙적·약속이 달라져 같은 3년이 반복되지 않습니다

■ 프로, 그리고 기록
· 지명되면 계약서가 옵니다 — 조건을 읽고 직접 서명하는 순간 프로 인생이 시작됩니다
· 시즌이 끝나면 연봉이 들어오고, 팬이 늘고, 구단에 발자취가 남습니다
· 벌어들인 돈은 다음 시즌에 투자하고, FA의 갈림길에선 잔류와 이적을 직접 저울질합니다
· 잘 살아낸 커리어는 은퇴식과 구단에 남는 기록으로 기억됩니다
· 통산 기록·별명·연대기가 회차를 넘어 쌓이고, 회차 카드 한 장으로 공유합니다

■ 약속
· 광고 없음 · 인앱 결제 없음 · 확률형 뽑기 없음
· 한 번 구매하면 전부입니다
· 오프라인으로 즐길 수 있고, iCloud로 기기 사이를 오갑니다
· 한국어·영어·일본어 지원 — 언어별 야구 용어와 기록 표기를 제공합니다

투수의 3년을 한 구씩 살아 보세요.`;

const EN_DESCRIPTION = `Call the pitch. Pick your spot. Finish the throw.

Mound Reborn is a baseball career simulation where you develop a pitcher through three years of high school and fight to hear your name called on draft day. Every important at-bat puts the decisions in your hands: choose a pitch, read the hitter, aim for the zone, and live with the result.

Getting drafted is never guaranteed. A bad outing, mounting fatigue, or one choice under pressure can change the path of a career. If your run ends, the time you invested does not disappear. Choose a memory or legacy from that player, begin again with a new prospect, and turn the last career's failure into the next one's head start.

BUILD A PITCHER
Train your velocity, command, movement, stamina, and pitch mix across a complete high-school career.

THINK THROUGH EVERY AT-BAT
Mix pitches and locations while hitters learn your patterns and adjust to what you have shown them.

CHASE THE DRAFT
Face the pressure of decisive games, scouting judgments, and a draft outcome earned by the career you played.

LEAVE SOMETHING BEHIND
Carry selected memories and signature legacies across rebirths. A new player is never quite a blank slate.

GO BEYOND HIGH SCHOOL
If you are drafted, continue into a professional career with roles, contracts, call-ups, seasons, records, and retirement.

YOUR CAREER, YOUR STORY
Relationships, regional atmosphere, career milestones, and the choices you made become part of an enduring player chronicle.

- Premium game: pay once
- No ads
- No in-app purchases
- No gacha
- Playable offline
- English, Korean, and Japanese

Mound Reborn takes place in an original fictional baseball world inspired by the regional culture and atmosphere of Korean baseball. It is not affiliated with any real league, club, school, or player.`;

const JA_DESCRIPTION = `一球ずつ、自分で読む。選ぶ。投げ切る。

球種とコースを選び、離すタイミングで制球が決まる。試合を眺めているだけのシミュレーションではない。

高校3年、ドラフトは一度きり。指名されなければまた転生し、前の投手が残した記憶を次の人生へ渡す。

主な特徴：
・韓国野球の地域文化と雰囲気をモチーフにした、完全オリジナルの架空野球世界
・地域ごとに特色の異なる多数の架空高校
・12の架空プロ球団と二つの架空リーグ
・球種、コース、配球、リリースを選ぶ一球勝負
・高校からプロ、引退まで続く投手人生
・記憶と技術を次の投手へ渡す「また転生」
・広告なし。追加課金なし。ガチャなし。一度の購入で全部
・オフラインで遊べる
・日本語・韓国語・英語

本作の学校、球団、大会、リーグ、選手、ロゴはすべて架空です。実在する団体や人物とは関係ありません。`;

const COPY = {
  ko: {
    keywords: KO_KEYWORDS,
    promotionalText: KO_PROMO,
    description: KO_DESCRIPTION,
    whatsNew: releaseWhatsNew(KO_WHATS_NEW, REVIEW_KO_WHATS_NEW),
    marketingUrl: "https://baseball-reincarnation.vercel.app",
    supportUrl: "https://baseball-reincarnation.vercel.app/#faq",
  },
  ja: {
    keywords: JA_KEYWORDS,
    promotionalText: JA_PROMO,
    description: JA_DESCRIPTION,
    whatsNew: releaseWhatsNew(JA_WHATS_NEW, REVIEW_JA_WHATS_NEW),
    marketingUrl: "https://baseball-reincarnation.vercel.app",
    supportUrl: "https://baseball-reincarnation.vercel.app/#faq",
  },
  "en-US": {
    keywords: EN_KEYWORDS,
    promotionalText: EN_PROMO,
    description: EN_DESCRIPTION,
    whatsNew: releaseWhatsNew(EN_WHATS_NEW, REVIEW_EN_WHATS_NEW),
    marketingUrl: "https://baseball-reincarnation.vercel.app/en",
    supportUrl: "https://baseball-reincarnation.vercel.app/en/support",
  },
};
COPY["en-GB"] = COPY["en-US"];
COPY["en-CA"] = COPY["en-US"];
COPY["en-AU"] = COPY["en-US"];

function assertLimits() {
  const checks = [
    ["ko promo", KO_PROMO, 170],
    ["en promo", EN_PROMO, 170],
    ["ja promo", JA_PROMO, 170],
    ["ko kw", KO_KEYWORDS, 100],
    ["en kw", EN_KEYWORDS, 100],
    ["ja kw", JA_KEYWORDS, 100],
    ["ja sub", JA_SUBTITLE, 30],
    ["ko desc", KO_DESCRIPTION, 4000],
    ["en desc", EN_DESCRIPTION, 4000],
    ["ja desc", JA_DESCRIPTION, 4000],
    ["ko whats", KO_WHATS_NEW, 4000],
    ["en whats", EN_WHATS_NEW, 4000],
    ["ja whats", JA_WHATS_NEW, 4000],
  ];
  for (const [label, value, max] of checks) {
    const n = [...value].length;
    if (n > max) throw new Error(`${label} ${n}/${max}`);
    console.log(`  ${label}: ${n}/${max}`);
  }
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
    const page = await request(next);
    rows.push(...page.data);
    next = page.links?.next ?? null;
  }
  return rows;
}

async function findVersion(versionString) {
  const versions = await all(`/v1/apps/${APP_ID}/appStoreVersions?filter[platform]=IOS&limit=200`);
  return versions.find((item) => item.attributes.versionString === versionString) ?? null;
}

async function prepare() {
  assertLimits();
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
              copyright: source.attributes.copyright,
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

  const sourceLocs = await all(
    `/v1/appStoreVersions/${source.id}/appStoreVersionLocalizations?limit=200`,
  );
  let locs = await all(`/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations?limit=200`);
  for (const locale of Object.keys(COPY)) {
    const wanted = COPY[locale];
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
                ...wanted,
                ...(sourceLoc?.attributes.supportUrl && !wanted.supportUrl
                  ? { supportUrl: sourceLoc.attributes.supportUrl }
                  : {}),
              },
              relationships: {
                appStoreVersion: { data: { type: "appStoreVersions", id: version.id } },
              },
            },
          },
        })
      ).data;
      console.log(`현지화 생성 ${locale} ${loc.id}`);
    } else {
      await request(`/v1/appStoreVersionLocalizations/${loc.id}`, {
        method: "PATCH",
        body: {
          data: {
            type: "appStoreVersionLocalizations",
            id: loc.id,
            attributes: wanted,
          },
        },
      });
      console.log(`현지화 갱신 ${locale} ${loc.id}`);
    }
  }

  const infos = await all(`/v1/apps/${APP_ID}/appInfos?limit=20`);
  for (const info of infos) {
    const infoLocs = await all(`/v1/appInfos/${info.id}/appInfoLocalizations?limit=50`);
    const ja = infoLocs.find((item) => item.attributes.locale === "ja");
    if (!ja) continue;
    try {
      await request(`/v1/appInfoLocalizations/${ja.id}`, {
        method: "PATCH",
        body: {
          data: {
            type: "appInfoLocalizations",
            id: ja.id,
            attributes: { subtitle: JA_SUBTITLE },
          },
        },
      });
      console.log(`일본어 부제 갱신 appInfo=${info.id} state=${info.attributes.appStoreState}`);
    } catch (error) {
      console.log(`일본어 부제 건너뜀 appInfo=${info.id}: ${String(error).split("\n")[0]}`);
    }
  }

  locs = await all(`/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations?limit=200`);
  for (const loc of locs) {
    const shots = await all(`/v1/appStoreVersionLocalizations/${loc.id}/appScreenshotSets?limit=50`);
    const previews = await all(`/v1/appStoreVersionLocalizations/${loc.id}/appPreviewSets?limit=50`);
    const shotCount = (
      await Promise.all(
        shots.map((set) => all(`/v1/appScreenshotSets/${set.id}/appScreenshots?limit=50`)),
      )
    ).reduce((sum, rows) => sum + rows.length, 0);
    const previewCount = (
      await Promise.all(
        previews.map((set) => all(`/v1/appPreviewSets/${set.id}/appPreviews?limit=50`)),
      )
    ).reduce((sum, rows) => sum + rows.length, 0);
    console.log(
      `미디어 ${loc.attributes.locale}: screenshotSets=${shots.length} shots=${shotCount} previewSets=${previews.length} previews=${previewCount}`,
    );
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

async function listSigning() {
  const bundleIds = await all(`/v1/bundleIds?filter[identifier]=${encodeURIComponent(BUNDLE_IDENTIFIER)}&limit=20`);
  const certificates = await all("/v1/certificates?limit=200");
  const profiles = await all("/v1/profiles?limit=200");
  const devices = await all("/v1/devices?limit=200");
  console.log(JSON.stringify({
    bundleIds: bundleIds.map(({ id, attributes }) => ({ id, attributes })),
    certificates: certificates.map(({ id, attributes }) => ({
      id,
      name: attributes.name,
      displayName: attributes.displayName,
      serialNumber: attributes.serialNumber,
      certificateType: attributes.certificateType,
      expirationDate: attributes.expirationDate,
    })),
    profiles: profiles
      .filter((item) => item.attributes.bundleId === BUNDLE_IDENTIFIER
        || item.attributes.name?.includes("baseball"))
      .map(({ id, attributes }) => ({ id, name: attributes.name, profileType: attributes.profileType,
        uuid: attributes.uuid, expirationDate: attributes.expirationDate })),
    devices: devices.map(({ id, attributes }) => ({ id, name: attributes.name,
      udid: attributes.udid, deviceClass: attributes.deviceClass, status: attributes.status,
      platform: attributes.platform })),
  }, null, 2));
}

async function createProfile(certificateId, outputPath, deviceId) {
  if (!certificateId || !outputPath) throw new Error("create-profile <certificateId> <outputPath>");
  const bundleIds = await all(`/v1/bundleIds?filter[identifier]=${encodeURIComponent(BUNDLE_IDENTIFIER)}&limit=20`);
  const bundleId = bundleIds[0];
  if (!bundleId) throw new Error("bundle id 없음");
  const created = (
    await request("/v1/profiles", {
      method: "POST",
      body: {
        data: {
          type: "profiles",
          attributes: {
            name: `Baseball App Store ${VERSION} ${Date.now()}`,
            profileType: process.env.ASC_PROFILE_TYPE ?? "IOS_APP_STORE",
          },
          relationships: {
            bundleId: { data: { type: "bundleIds", id: bundleId.id } },
            certificates: { data: [{ type: "certificates", id: certificateId }] },
            ...(deviceId ? { devices: { data: [{ type: "devices", id: deviceId }] } } : {}),
          },
        },
      },
    })
  ).data;
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, Buffer.from(created.attributes.profileContent, "base64"));
  console.log(JSON.stringify({ id: created.id, uuid: created.attributes.uuid,
    name: created.attributes.name, outputPath }));
}

async function createBundleId(identifier) {
  if (!identifier) throw new Error("create-bundle-id <identifier>");
  const existing = await all(`/v1/bundleIds?filter[identifier]=${encodeURIComponent(identifier)}&limit=20`);
  if (existing[0]) {
    console.log(JSON.stringify({ id: existing[0].id, identifier, existing: true }));
    return;
  }
  const created = (await request("/v1/bundleIds", {
    method: "POST",
    body: { data: { type: "bundleIds", attributes: {
      identifier, name: `Baseball QA ${VERSION.replaceAll(".", " ")}`, platform: "IOS",
    } } },
  })).data;
  console.log(JSON.stringify({ id: created.id, identifier, existing: false }));
}

async function deleteResource(type, id) {
  if (!type || !id || !["profiles", "bundleIds"].includes(type)) {
    throw new Error("delete-resource <profiles|bundleIds> <id>");
  }
  await request(`/v1/${type}/${id}`, { method: "DELETE" });
  console.log(JSON.stringify({ deleted: type, id }));
}

async function inspectBuild(buildId) {
  if (!buildId) throw new Error("inspect-build <buildId>");
  const build = await request(`/v1/builds/${buildId}`);
  let bundles = [];
  try { bundles = await all(`/v1/builds/${buildId}/buildBundles?limit=50`); } catch {}
  console.log(JSON.stringify({ build: build.data, bundles }, null, 2));
}

const [command, ...args] = process.argv.slice(2);
if (command === "prepare") await prepare();
else if (command === "attach") await attach(args[0]);
else if (command === "submit") await submit();
else if (command === "check") assertLimits();
else if (command === "list-signing") await listSigning();
else if (command === "create-profile") await createProfile(args[0], args[1], args[2]);
else if (command === "create-bundle-id") await createBundleId(args[0]);
else if (command === "delete-resource") await deleteResource(args[0], args[1]);
else if (command === "inspect-build") await inspectBuild(args[0]);
else throw new Error("prepare | attach <buildId> | submit | check | list-signing | create-profile <certificateId> <outputPath> [deviceId] | create-bundle-id <identifier> | delete-resource <type> <id>");
