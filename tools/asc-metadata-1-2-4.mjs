#!/usr/bin/env node

// App Store Connect metadata-only operations for iOS 1.2.4.
//
// This script intentionally never creates versions, changes app-info fields,
// touches screenshots/previews, attaches builds, or submits a review.
//
//   node tools/asc-metadata-1-2-4.mjs check
//   node tools/asc-metadata-1-2-4.mjs inspect
//   node tools/asc-metadata-1-2-4.mjs apply
//   node tools/asc-metadata-1-2-4.mjs verify

import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const KEY_ID = process.env.ASC_KEY_ID ?? "TW3Y8S4M9V";
const ISSUER = process.env.ASC_ISSUER ?? "f4843e26-5b1f-4b00-bd4a-d24ca4539774";
const APP_ID = process.env.ASC_APP_ID ?? "6794754217";
const VERSION = process.env.ASC_VERSION ?? "1.2.4";
const API_ROOT = "https://api.appstoreconnect.apple.com";

const LOCALES = ["en-US", "en-GB", "en-AU", "en-CA", "ko", "ja"];

const EN_DESCRIPTION = `Call the pitch. Pick your spot. Finish the throw.

Mound Reborn is a baseball career built around pitching: develop a player through three years of high school and fight to hear your name called on draft day. Choose a pitch, read the hitter, aim for the zone, time the release, and live with the result.

BUILD A PITCHER
Train velocity, command, movement, stamina, and your pitch mix across a complete high-school career. A direct pitch slider puts every important throw in your hands.

THINK THROUGH EVERY AT-BAT
Mix pitches and locations while hitters learn your patterns and adjust to what you have shown them. The catcher offers a reasoned call; follow it or change the plan. Replay the pitch path and result after every delivery.

SEE THE RISK, THEN CHOOSE
Fatigue and workload matter. If an injury happens, see its cause, recovery time, and next step right away so you can choose what to do next.

KEEP THE STORY MOVING
Career scenes and repeated explanations open with context the first time. Once you know them, they become a compact, readable summary that you can expand whenever you want the full story.

READ YOUR GROWTH
Ability ratings use a familiar 1–100 scale, so a new player can understand the board at a glance. When a rating reaches its base cap, development continues through separate mastery levels and effects—not an endless ability number.

CHASE THE DRAFT
Getting drafted is never guaranteed. A bad outing, mounting fatigue, or one choice under pressure can change the path of a career. If your run ends, choose a memory or legacy from that player, begin again with a new prospect, and turn the last career’s failure into the next one’s head start.

GO BEYOND HIGH SCHOOL
If you are drafted, continue into a professional career with roles, contracts, call-ups, seasons, records, and retirement. Relationships, regional atmosphere, and your choices become part of an enduring player chronicle.

- Premium game: pay once
- No ads, in-app purchases, or gacha
- Playable offline
- English, Korean, and Japanese

Mound Reborn takes place in an original fictional baseball world shaped by regional baseball culture and atmosphere. It is not affiliated with any real league, club, school, or player.`;

const KO_DESCRIPTION = `공 하나하나를 직접 던지고, 한 투수의 인생을 선택하는 야구 게임입니다.

구종과 코스를 고르고, 화면을 길게 눌러 와인드업한 뒤 손을 떼는 타이밍으로 제구가 갈립니다. 자동으로 굴러가는 경기를 구경하는 게임이 아닙니다. 중요한 공은 투구 슬라이더로 직접 던집니다.

■ 한 구의 무게
구종과 코스, 노림과 힘 배분을 고릅니다. 포수는 이유와 함께 사인을 내고, 따를지 고칠지는 당신이 정합니다. 같은 공을 반복하면 타자가 읽고 적응합니다. 던진 공은 궤적과 타구로 다시 확인할 수 있습니다.

■ 3년의 선택
고교 3년 동안 훈련·관계·중요 경기·각성이 이어집니다. 팔 상태와 피로를 무시하면 부상을 입을 수 있습니다. 부상이 생기면 원인, 회복 기간, 다음 행동을 결과 화면에서 바로 알려 줍니다. 쉴지, 훈련할지, 다시 승부할지 당신이 결정합니다.

■ 더 읽기 쉬워진 커리어
스토리와 반복 설명은 처음 볼 때 맥락을 충분히 보여 줍니다. 한 번 읽은 뒤에는 간결한 요약으로 접어 한눈에 읽을 수 있고, 원하면 언제든 다시 펼칠 수 있습니다.

■ 누구나 이해하는 성장
능력 수치는 익숙한 1–100으로 보여 줍니다. 기본 능력치가 100에 닿은 뒤에는 숫자가 끝없이 커지지 않습니다. 대신 별도의 숙련 레벨과 효과를 쌓아 다음 성장을 이어 갑니다.

■ 다시 태어나기
지명받지 못하면 기억과 대표 유산을 남기고 새 선수로 다시 시작합니다. 전 생의 실패가 다음 회차의 출발점이 됩니다. 학교·감독·포수·라이벌·일정도 회차마다 새로 짜입니다.

■ 프로, 그리고 기록
지명되면 프로에 진출해 역할·계약·콜업·시즌·기록·은퇴를 이어 갑니다. 관계와 지역의 분위기, 당신이 내린 선택이 한 투수의 연대기가 됩니다.

■ 약속
· 광고 없음 · 인앱 결제 없음 · 확률형 뽑기 없음
· 한 번 구매하면 고교부터 은퇴까지 전부
· 오프라인 플레이 가능
· 한국어·영어·일본어 지원

실존 리그·구단·학교·선수와 관련이 없는 독자적인 가상 야구 세계입니다.`;

const JA_DESCRIPTION = `一球ずつ、自分で読む。選ぶ。投げ切る。

『野球がダメならまた転生』は、高校3年間で投手を育て、ドラフトで名前を呼ばれることを目指す野球キャリアです。球種とコースを選び、打者を読み、ストライクゾーンを狙い、離すタイミングまで自分で決めます。

■ 一球の重さ
球種・コース・狙い・力配分を選びます。捕手は理由付きでサインを出しますが、従うか自分の配球に変えるかはあなた次第。同じ球を続ければ打者に読まれます。投げた球は軌道と打球で振り返れます。

■ リスクを見て決める
疲労と登板量はキャリアを変えます。負傷したときは、原因・回復期間・次に取る行動をすぐ確認できます。休むか、鍛えるか、もう一度勝負するかを選びましょう。

■ 読みやすいキャリア
ストーリーや繰り返し表示される説明は、初回は背景まで詳しく表示。一度読んだ後はコンパクトな要約に折りたたんで、流れを止めずに読み進められます。必要なときはいつでも展開できます。

■ 成長を分かりやすく
能力値は、なじみのある1〜100で表示します。基本上限の100に達した後も、数値が無限に伸びるのではありません。別枠の熟練レベルと効果で、次の成長を積み重ねます。

■ ドラフトと転生
指名は保証されません。キャリアが終わっても、前の投手から記憶やレガシーを選び、新しい投手の出発点にできます。高校・捕手・ライバル・日程も、転生するたびに変わります。

■ 高校の先へ
指名されればプロへ進み、役割・契約・昇格・シーズン・記録・引退まで続きます。関係、地域の空気、あなたの選択が一人の投手の年代記になります。

・買い切り。広告なし、追加課金なし、ガチャなし
・オフラインでプレイ可能
・日本語・韓国語・英語に対応

本作は地域の野球文化と空気感をモチーフにした、完全オリジナルの架空野球世界です。実在のリーグ、球団、学校、選手とは関係ありません。`;

const EN_WHATS_NEW = `This update makes every decision easier to read.

• See an injury’s cause, recovery time, and next step right away.
• Repeated story moments and explanations collapse into a compact summary after the first read, and can be expanded whenever you want the detail.
• Ability ratings now use a familiar 1–100 scale. After the base cap, separate mastery levels and effects keep development moving without turning ratings into endless numbers.

Your next pitch—and your next career—are easier to follow.`;

const KO_WHATS_NEW = `이번 업데이트에서는 플레이 중 막히는 순간을 더 쉽게 읽을 수 있게 다듬었습니다.

· 부상이 생기면 원인·회복 기간·다음 행동을 결과 화면에서 바로 확인할 수 있습니다.
· 한 번 본 스토리와 설명은 반복해서 볼 때 간결한 요약으로 접어 두고, 필요할 때 다시 펼칠 수 있습니다.
· 능력 수치를 익숙한 1–100으로 표시합니다. 100 이후에는 능력치 숫자가 끝없이 커지는 대신 별도의 숙련 레벨과 효과로 성장을 이어 갑니다.

한 구씩 직접 던지는 손맛과, 다음 커리어를 만들어 가는 선택은 그대로입니다.`;

const JA_WHATS_NEW = `今回のアップデートでは、プレイ中の判断をもっと読みやすくしました。

・負傷の原因・回復期間・次に取る行動を、結果画面ですぐ確認できます。
・一度読んだストーリーと説明は、次からコンパクトな要約に折りたためます。必要ならいつでも詳しく開けます。
・能力値をなじみのある1〜100で表示。100の基本上限の後は、数値が無限に増えるのではなく、別枠の熟練レベルと効果で成長を続けます。

一球ずつ自分で投げる手触りと、次のキャリアを選ぶ面白さはそのままです。`;

const COPY = {
  "en-US": {description: EN_DESCRIPTION, whatsNew: EN_WHATS_NEW},
  "en-GB": {description: EN_DESCRIPTION, whatsNew: EN_WHATS_NEW},
  "en-AU": {description: EN_DESCRIPTION, whatsNew: EN_WHATS_NEW},
  "en-CA": {description: EN_DESCRIPTION, whatsNew: EN_WHATS_NEW},
  ko: {description: KO_DESCRIPTION, whatsNew: KO_WHATS_NEW},
  ja: {description: JA_DESCRIPTION, whatsNew: JA_WHATS_NEW},
};

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

function token() {
  const keyPath = path.join(os.homedir(), ".appstoreconnect", "private_keys", `AuthKey_${KEY_ID}.p8`);
  if (!fs.existsSync(keyPath)) throw new Error(`인증 키가 없습니다: ${keyPath}`);
  const now = Math.floor(Date.now() / 1000);
  const encode = (value) => Buffer.from(JSON.stringify(value)).toString("base64url");
  const header = encode({alg: "ES256", kid: KEY_ID, typ: "JWT"});
  const payload = encode({iss: ISSUER, iat: now, exp: now + 600, aud: "appstoreconnect-v1"});
  const signature = crypto
    .sign("sha256", Buffer.from(`${header}.${payload}`), {
      key: fs.readFileSync(keyPath, "utf8"),
      dsaEncoding: "ieee-p1363",
    })
    .toString("base64url");
  return `${header}.${payload}.${signature}`;
}

async function request(pathOrUrl, {method = "GET", body} = {}) {
  const url = pathOrUrl.startsWith("http") ? pathOrUrl : `${API_ROOT}${pathOrUrl}`;
  const response = await fetch(url, {
    method,
    headers: {
      Authorization: `Bearer ${token()}`,
      ...(body ? {"Content-Type": "application/json"} : {}),
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

async function findVersion() {
  const versions = await all(`/v1/apps/${APP_ID}/appStoreVersions?filter[platform]=IOS&limit=200`);
  const version = versions.find((item) => item.attributes.versionString === VERSION);
  if (!version) throw new Error(`iOS ${VERSION} 버전을 찾지 못했습니다.`);
  return version;
}

async function context() {
  const version = await findVersion();
  const localizations = await all(
    `/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations?limit=200`,
  );
  const byLocale = new Map(localizations.map((item) => [item.attributes.locale, item]));
  const missing = LOCALES.filter((locale) => !byLocale.has(locale));
  if (missing.length > 0) throw new Error(`ASC 현지화가 없습니다: ${missing.join(", ")}`);
  return {version, byLocale};
}

function lengthOf(value) {
  return [...(value ?? "")].length;
}

function assertCopy() {
  for (const locale of LOCALES) {
    const copy = COPY[locale];
    if (!copy) throw new Error(`카피가 없습니다: ${locale}`);
    if (lengthOf(copy.description) > 4_000) {
      throw new Error(`${locale} description이 4,000자를 초과합니다: ${lengthOf(copy.description)}`);
    }
    if (lengthOf(copy.whatsNew) > 4_000) {
      throw new Error(`${locale} whatsNew가 4,000자를 초과합니다: ${lengthOf(copy.whatsNew)}`);
    }
    const combined = `${copy.description}\n${copy.whatsNew}`;
    const forbidden = FORBIDDEN_TERMS.filter((term) => combined.toLocaleLowerCase().includes(term.toLocaleLowerCase()));
    if (forbidden.length > 0) throw new Error(`${locale} 실존 명칭 의심 단어: ${forbidden.join(", ")}`);
    if (!combined.includes("1–100") && !combined.includes("1〜100")) {
      throw new Error(`${locale} 1–100 표시 약속이 없습니다.`);
    }
    if (!/mastery|숙련|熟練/u.test(combined)) {
      throw new Error(`${locale} 숙련 진행 약속이 없습니다.`);
    }
    if (!/endless|끝없이|無限/u.test(combined)) {
      throw new Error(`${locale} 무한 능력치가 아님을 설명하지 않습니다.`);
    }
    console.log(`${locale}: description ${lengthOf(copy.description)}/4000, whatsNew ${lengthOf(copy.whatsNew)}/4000`);
  }
}

function printLocalization(locale, localization, wanted = null) {
  const current = localization.attributes;
  const payload = {
    locale,
    id: localization.id,
    description: current.description ?? "",
    whatsNew: current.whatsNew ?? "",
    descriptionLength: lengthOf(current.description),
    whatsNewLength: lengthOf(current.whatsNew),
  };
  if (wanted) {
    payload.descriptionMatches = current.description === wanted.description;
    payload.whatsNewMatches = current.whatsNew === wanted.whatsNew;
  }
  console.log(JSON.stringify(payload, null, 2));
}

async function inspect() {
  const {version, byLocale} = await context();
  console.log(JSON.stringify({
    version: VERSION,
    versionID: version.id,
    appStoreState: version.attributes.appStoreState,
    editableState: version.attributes.appStoreState === "PREPARE_FOR_SUBMISSION",
    locales: LOCALES,
  }, null, 2));
  for (const locale of LOCALES) printLocalization(locale, byLocale.get(locale));
}

async function apply() {
  assertCopy();
  const {version, byLocale} = await context();
  const state = version.attributes.appStoreState;
  if (state !== "PREPARE_FOR_SUBMISSION") {
    throw new Error(`안전한 메타데이터 편집 상태가 아닙니다: ${state}. 빌드 연결·심사 제출은 수행하지 않습니다.`);
  }
  for (const locale of LOCALES) {
    const localization = byLocale.get(locale);
    const wanted = COPY[locale];
    const before = localization.attributes;
    if (before.description === wanted.description && before.whatsNew === wanted.whatsNew) {
      console.log(`${locale}: 이미 반영됨 (${localization.id})`);
      continue;
    }
    await request(`/v1/appStoreVersionLocalizations/${localization.id}`, {
      method: "PATCH",
      body: {
        data: {
          type: "appStoreVersionLocalizations",
          id: localization.id,
          attributes: {
            description: wanted.description,
            whatsNew: wanted.whatsNew,
          },
        },
      },
    });
    console.log(`${locale}: description + whatsNew 갱신 (${localization.id})`);
  }
  console.log(`완료: ${VERSION} 메타데이터만 갱신. 빌드 연결·심사 제출·미디어 변경 없음.`);
}

async function verify() {
  assertCopy();
  const {version, byLocale} = await context();
  const mismatches = [];
  console.log(JSON.stringify({
    version: VERSION,
    versionID: version.id,
    appStoreState: version.attributes.appStoreState,
  }, null, 2));
  for (const locale of LOCALES) {
    const localization = byLocale.get(locale);
    const wanted = COPY[locale];
    printLocalization(locale, localization, wanted);
    if (localization.attributes.description !== wanted.description) mismatches.push(`${locale}.description`);
    if (localization.attributes.whatsNew !== wanted.whatsNew) mismatches.push(`${locale}.whatsNew`);
  }
  if (mismatches.length > 0) throw new Error(`ASC 카피 불일치: ${mismatches.join(", ")}`);
  console.log(`검증 성공: ${VERSION}의 ${LOCALES.length}개 현지화에서 description/whatsNew 일치.`);
}

const [command] = process.argv.slice(2);
if (command === "check") assertCopy();
else if (command === "inspect") await inspect();
else if (command === "apply") await apply();
else if (command === "verify") await verify();
else throw new Error("check | inspect | apply | verify");
