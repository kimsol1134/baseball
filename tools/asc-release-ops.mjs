#!/usr/bin/env node

// App Store Connect 릴리스 운영 스크립트 (1.2.0 재제출용)
// 사용법:
//   node tools/asc-release-ops.mjs inspect-submission
//   node tools/asc-release-ops.mjs cancel-submission
//   node tools/asc-release-ops.mjs list-builds
//   node tools/asc-release-ops.mjs attach-build <buildId>
//   node tools/asc-release-ops.mjs update-previews <a1.mp4> <a3.mp4>
//   node tools/asc-release-ops.mjs resubmit

import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const KEY_ID = process.env.ASC_KEY_ID ?? "TW3Y8S4M9V";
const ISSUER = process.env.ASC_ISSUER ?? "f4843e26-5b1f-4b00-bd4a-d24ca4539774";
const APP_ID = process.env.ASC_APP_ID ?? "6794754217";
const VERSION = process.env.ASC_VERSION ?? "1.2.0";
const API_ROOT = "https://api.appstoreconnect.apple.com";
// 미리보기 포스터 프레임 (A1: 슬라이더 클로즈업, A3: 환생 화면)
const POSTER_TIMECODES = (process.env.ASC_POSTER_TIMECODES ?? "00:00:04:00,00:00:04:00").split(",");

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

async function request(pathOrUrl, {method = "GET", body, headers = {}} = {}) {
  const url = pathOrUrl.startsWith("http") ? pathOrUrl : `${API_ROOT}${pathOrUrl}`;
  const response = await fetch(url, {
    method,
    headers: {
      Authorization: `Bearer ${token()}`,
      ...(body ? {"Content-Type": "application/json"} : {}),
      ...headers,
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await response.text();
  if (!response.ok) throw new Error(`${method} ${url}\n${response.status} ${text.slice(0, 2000)}`);
  if (!text) return null;
  return JSON.parse(text);
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

async function activeSubmissions() {
  return all(`/v1/apps/${APP_ID}/reviewSubmissions?filter[platform]=IOS&limit=50`);
}

async function inspectSubmission() {
  const submissions = await activeSubmissions();
  for (const sub of submissions) {
    console.log(`${sub.id}  state=${sub.attributes.state}  submitted=${sub.attributes.submittedDate ?? "-"}`);
  }
  if (submissions.length === 0) console.log("리뷰 제출이 없습니다.");
}

async function cancelSubmission() {
  const submissions = await activeSubmissions();
  const cancellable = submissions.filter((sub) =>
    ["WAITING_FOR_REVIEW", "IN_REVIEW", "UNRESOLVED_ISSUES"].includes(sub.attributes.state),
  );
  if (cancellable.length === 0) {
    console.log("취소할 수 있는 제출이 없습니다. 현재 상태:");
    await inspectSubmission();
    return;
  }
  for (const sub of cancellable) {
    await request(`/v1/reviewSubmissions/${sub.id}`, {
      method: "PATCH",
      body: {
        data: {type: "reviewSubmissions", id: sub.id, attributes: {canceled: true}},
      },
    });
    console.log(`제출 취소 완료: ${sub.id} (이전 상태 ${sub.attributes.state})`);
  }
}

async function listBuilds() {
  const builds = await all(
    `/v1/builds?filter[app]=${APP_ID}&sort=-uploadedDate&limit=10&fields[builds]=version,uploadedDate,processingState,expired`,
  );
  for (const build of builds) {
    const a = build.attributes;
    console.log(`${build.id}  build=${a.version}  ${a.processingState}  uploaded=${a.uploadedDate}  expired=${a.expired}`);
  }
}

async function attachBuild(buildId) {
  if (!buildId) throw new Error("빌드 ID가 필요합니다.");
  const version = await findVersion();
  await request(`/v1/appStoreVersions/${version.id}/relationships/build`, {
    method: "PATCH",
    body: {data: {type: "builds", id: buildId}},
  });
  console.log(`버전 ${VERSION} (${version.id})에 빌드 ${buildId} 연결 완료`);
}

function checksum(file) {
  return crypto.createHash("md5").update(fs.readFileSync(file)).digest("hex");
}

async function uploadOperations(operations, file) {
  const source = fs.readFileSync(file);
  if (!Array.isArray(operations) || operations.length === 0) {
    throw new Error(`업로드 작업이 비어 있습니다: ${file}`);
  }
  for (const operation of operations) {
    const headers = Object.fromEntries(
      (operation.requestHeaders ?? []).map(({name, value}) => [name, value]),
    );
    const offset = operation.offset ?? 0;
    const length = operation.length ?? source.length;
    const response = await fetch(operation.url, {
      method: operation.method,
      headers,
      body: source.subarray(offset, offset + length),
    });
    if (!response.ok) {
      throw new Error(
        `바이너리 업로드 실패 ${response.status} ${operation.method} ${operation.url}\n${(await response.text()).slice(0, 1000)}`,
      );
    }
  }
}

function deliveryError(resource) {
  const asset = resource.attributes.assetDeliveryState;
  const video = resource.attributes.videoDeliveryState;
  if (asset?.state === "FAILED") return JSON.stringify(asset.errors ?? []);
  if (video?.state === "FAILED") return JSON.stringify(video.errors ?? []);
  return null;
}

async function waitFor(resourceType, id, predicate, {timeoutMs = 20 * 60 * 1000, intervalMs = 3000, label = id} = {}) {
  const started = Date.now();
  let last = "";
  while (Date.now() - started < timeoutMs) {
    const resource = (await request(`/v1/${resourceType}/${id}`)).data;
    const error = deliveryError(resource);
    if (error) throw new Error(`${label} 처리 실패: ${error}`);
    const state = [
      resource.attributes.assetDeliveryState?.state,
      resource.attributes.videoDeliveryState?.state,
      resource.attributes.previewFrameImage?.state?.state,
    ]
      .filter(Boolean)
      .join("/");
    if (state !== last) {
      console.log(`  ${label}: ${state || "예약됨"}`);
      last = state;
    }
    if (predicate(resource)) return resource;
    await new Promise((resolve) => setTimeout(resolve, intervalMs));
  }
  throw new Error(`${label} 처리 시간이 ${Math.round(timeoutMs / 60000)}분을 넘었습니다.`);
}

async function createPreview(setId, item) {
  const created = (
    await request("/v1/appPreviews", {
      method: "POST",
      body: {
        data: {
          type: "appPreviews",
          attributes: {fileName: item.name, fileSize: item.size, mimeType: "video/mp4"},
          relationships: {appPreviewSet: {data: {type: "appPreviewSets", id: setId}}},
        },
      },
    })
  ).data;
  console.log(`  예약: ${item.name} (${created.id})`);
  await uploadOperations(created.attributes.uploadOperations, item.file);
  await request(`/v1/appPreviews/${created.id}`, {
    method: "PATCH",
    body: {data: {type: "appPreviews", id: created.id, attributes: {uploaded: true}}},
  });
  const done = await waitFor(
    "appPreviews",
    created.id,
    (resource) =>
      resource.attributes.assetDeliveryState?.state === "COMPLETE" &&
      resource.attributes.videoDeliveryState?.state === "COMPLETE",
    {label: item.name},
  );
  await request(`/v1/appPreviews/${done.id}`, {
    method: "PATCH",
    body: {
      data: {type: "appPreviews", id: done.id, attributes: {previewFrameTimeCode: item.poster}},
    },
  });
  await waitFor(
    "appPreviews",
    done.id,
    (resource) =>
      resource.attributes.previewFrameTimeCode === item.poster &&
      resource.attributes.previewFrameImage?.state?.state === "COMPLETE",
    {label: `${item.name} 포스터`},
  );
  return done;
}

async function updatePreviews(a1Path, a3Path) {
  if (!a1Path || !a3Path) throw new Error("A1, A3 미리보기 파일 경로 2개가 필요합니다.");
  for (const file of [a1Path, a3Path]) {
    if (!fs.existsSync(file)) throw new Error(`파일이 없습니다: ${file}`);
  }
  const wanted = [
    {file: a1Path, name: "asc-a1-last-ball.mp4", poster: POSTER_TIMECODES[0]},
    {file: a3Path, name: "asc-a3-rebirth.mp4", poster: POSTER_TIMECODES[1] ?? POSTER_TIMECODES[0]},
  ].map((item) => ({...item, size: fs.statSync(item.file).size, md5: checksum(item.file)}));

  const version = await findVersion();
  if (["READY_FOR_SALE"].includes(version.attributes.appStoreState)) {
    throw new Error(`${VERSION}은 판매 중이라 미디어를 변경할 수 없습니다.`);
  }
  const localizations = await all(
    `/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations?limit=200`,
  );
  const locale = process.env.ASC_LOCALE ?? "ko";
  const localization = localizations.find((item) => item.attributes.locale === locale);
  if (!localization) throw new Error(`${VERSION}의 ${locale} 현지화를 찾지 못했습니다.`);
  const previewSets = await all(
    `/v1/appStoreVersionLocalizations/${localization.id}/appPreviewSets?limit=50`,
  );
  for (const displayType of ["IPHONE_67", "IPHONE_65"]) {
    const set = previewSets.find((candidate) => candidate.attributes.previewType === displayType);
    if (!set) throw new Error(`${displayType} 미리보기 세트가 없습니다.`);
    console.log(`\n[${displayType}] 미리보기 교체: 기존 전체 제거 후 A1 → A3 순서 업로드`);
    const current = await all(`/v1/appPreviewSets/${set.id}/appPreviews?limit=50`);
    for (const resource of current) {
      await request(`/v1/appPreviews/${resource.id}`, {method: "DELETE"});
      console.log(`  기존 미리보기 제거: ${resource.attributes.fileName} (${resource.id})`);
    }
    // 생성 순서가 스토어 노출 순서다: A1(마지막 공) 먼저, A3(환생) 다음.
    for (const item of wanted) {
      await createPreview(set.id, item);
    }
    console.log(`  완료: ${wanted.map((item) => item.name).join(" → ")}`);
  }
  console.log("\n미리보기 교체 완료");
}

async function resubmit() {
  const version = await findVersion();
  console.log(`버전 상태: ${version.attributes.appStoreState}`);
  const submissions = await activeSubmissions();
  let submission = submissions.find((sub) =>
    ["READY_FOR_REVIEW"].includes(sub.attributes.state),
  );
  if (!submission) {
    submission = (
      await request("/v1/reviewSubmissions", {
        method: "POST",
        body: {
          data: {
            type: "reviewSubmissions",
            attributes: {platform: "IOS"},
            relationships: {app: {data: {type: "apps", id: APP_ID}}},
          },
        },
      })
    ).data;
    console.log(`리뷰 제출 생성: ${submission.id}`);
  } else {
    console.log(`기존 편집 중 제출 사용: ${submission.id}`);
  }
  const items = await all(`/v1/reviewSubmissions/${submission.id}/items?limit=50`);
  if (items.length === 0) {
    await request("/v1/reviewSubmissionItems", {
      method: "POST",
      body: {
        data: {
          type: "reviewSubmissionItems",
          relationships: {
            reviewSubmission: {data: {type: "reviewSubmissions", id: submission.id}},
            appStoreVersion: {data: {type: "appStoreVersions", id: version.id}},
          },
        },
      },
    });
    console.log(`제출 아이템 추가: 버전 ${VERSION} (${version.id})`);
  } else {
    console.log(`제출 아이템 ${items.length}개 이미 존재`);
  }
  const submitted = (
    await request(`/v1/reviewSubmissions/${submission.id}`, {
      method: "PATCH",
      body: {
        data: {type: "reviewSubmissions", id: submission.id, attributes: {submitted: true}},
      },
    })
  ).data;
  console.log(`심사 제출 완료: ${submitted.id} state=${submitted.attributes.state}`);
}

const [command, ...args] = process.argv.slice(2);
if (command === "inspect-submission") await inspectSubmission();
else if (command === "cancel-submission") await cancelSubmission();
else if (command === "list-builds") await listBuilds();
else if (command === "attach-build") await attachBuild(args[0]);
else if (command === "update-previews") await updatePreviews(args[0], args[1]);
else if (command === "resubmit") await resubmit();
else throw new Error(`알 수 없는 명령: ${command ?? "(없음)"}`);
