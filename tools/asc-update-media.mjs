#!/usr/bin/env node

import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const KEY_ID = process.env.ASC_KEY_ID ?? "TW3Y8S4M9V";
const ISSUER = process.env.ASC_ISSUER ?? "f4843e26-5b1f-4b00-bd4a-d24ca4539774";
const APP_ID = process.env.ASC_APP_ID ?? "6794754217";
const VERSION = process.env.ASC_VERSION ?? "1.0.4";
const SOURCE_VERSION = process.env.ASC_SOURCE_VERSION ?? "1.0.3";
const LOCALE = process.env.ASC_LOCALE ?? "ko";
const API_ROOT = "https://api.appstoreconnect.apple.com";
const MEDIA_ROOT = path.resolve(
  process.env.ASC_MEDIA_ROOT ?? "marketing/appstore/asc-2026-08-rebirth",
);
const PREVIEW_TIMECODE = process.env.ASC_PREVIEW_TIMECODE ?? "00:00:01:00";
const KEYWORDS =
  "로그라이트,회귀,드래프트,고교,에이스,삼진,오프라인,싱글,광고없음,커리어,성장,스토리,인디,유료,베이스볼,선수,타이밍,마운드,제구,구속,구종,선발,신인,루키,피칭,전략,트레이닝";

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

async function context(versionString = VERSION) {
  const versions = await all(`/v1/apps/${APP_ID}/appStoreVersions?filter[platform]=IOS&limit=200`);
  const version = versions.find((item) => item.attributes.versionString === versionString);
  if (!version) {
    throw new Error(`iOS ${versionString} 버전을 찾지 못했습니다. 현재: ${versions.map((v) => v.attributes.versionString).join(", ")}`);
  }
  const localizations = await all(`/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations?limit=200`);
  const localization = localizations.find((item) => item.attributes.locale === LOCALE);
  if (!localization) throw new Error(`${versionString}의 ${LOCALE} 현지화를 찾지 못했습니다.`);
  const screenshotSets = await all(`/v1/appStoreVersionLocalizations/${localization.id}/appScreenshotSets?limit=50`);
  const previewSets = await all(`/v1/appStoreVersionLocalizations/${localization.id}/appPreviewSets?limit=50`);
  return {version, localization, screenshotSets, previewSets};
}

async function createMediaSet(localizationId, type, displayType) {
  const isScreenshot = type === "appScreenshotSets";
  const attributes = isScreenshot
    ? {screenshotDisplayType: displayType}
    : {previewType: displayType};
  return (
    await request(`/v1/${type}`, {
      method: "POST",
      body: {
        data: {
          type,
          attributes,
          relationships: {
            appStoreVersionLocalization: {
              data: {type: "appStoreVersionLocalizations", id: localizationId},
            },
          },
        },
      },
    })
  ).data;
}

async function ensureMediaSets(localization) {
  let screenshotSets = await all(
    `/v1/appStoreVersionLocalizations/${localization.id}/appScreenshotSets?limit=50`,
  );
  let previewSets = await all(
    `/v1/appStoreVersionLocalizations/${localization.id}/appPreviewSets?limit=50`,
  );
  for (const displayType of ["APP_IPHONE_67", "APP_IPHONE_65"]) {
    if (!screenshotSets.some((set) => set.attributes.screenshotDisplayType === displayType)) {
      const created = await createMediaSet(localization.id, "appScreenshotSets", displayType);
      console.log(`  스크린샷 세트 생성: ${displayType} (${created.id})`);
    }
  }
  for (const displayType of ["IPHONE_67", "IPHONE_65"]) {
    if (!previewSets.some((set) => set.attributes.previewType === displayType)) {
      const created = await createMediaSet(localization.id, "appPreviewSets", displayType);
      console.log(`  미리보기 세트 생성: ${displayType} (${created.id})`);
    }
  }
  screenshotSets = await all(
    `/v1/appStoreVersionLocalizations/${localization.id}/appScreenshotSets?limit=50`,
  );
  previewSets = await all(
    `/v1/appStoreVersionLocalizations/${localization.id}/appPreviewSets?limit=50`,
  );
  return {screenshotSets, previewSets};
}

function desiredLocalizationAttributes(sourceAttributes) {
  return Object.fromEntries(
    Object.entries({
      description: sourceAttributes.description?.replace("지명되면 12시즌", "지명되면 20시즌"),
      keywords: KEYWORDS,
      marketingUrl: sourceAttributes.marketingUrl,
      promotionalText: sourceAttributes.promotionalText,
      supportUrl: sourceAttributes.supportUrl,
      whatsNew:
        "· 프로 커리어를 20시즌으로 확장했습니다.\n" +
        "· 투수 청사진과 스킬 트리로 성장 방향을 더 분명하게 확인할 수 있습니다.\n" +
        "· 한 선수의 실제 성장과 경기 기록으로 대표 유산이 만들어지고, 다음 선수에게 이어집니다.\n" +
        "· 타자와 포수 연출, 투구 결과 화면, 개인 최고 기록 피드백을 개선했습니다.",
    }).filter(([, value]) => value !== null && value !== undefined),
  );
}

async function updateLocalization(localization, sourceAttributes) {
  const attributes = desiredLocalizationAttributes(sourceAttributes);
  const updated = (
    await request(`/v1/appStoreVersionLocalizations/${localization.id}`, {
      method: "PATCH",
      body: {
        data: {
          type: "appStoreVersionLocalizations",
          id: localization.id,
          attributes,
        },
      },
    })
  ).data;
  console.log(`  ${LOCALE} 메타데이터 갱신: ${updated.id}`);
  return updated;
}

async function ensureEditableContext() {
  const versions = await all(`/v1/apps/${APP_ID}/appStoreVersions?filter[platform]=IOS&limit=200`);
  let version = versions.find((item) => item.attributes.versionString === VERSION);
  const source = await context(SOURCE_VERSION);
  if (!version) {
    console.log(`[${VERSION}] 새 App Store 버전 초안 생성`);
    version = (
      await request("/v1/appStoreVersions", {
        method: "POST",
        body: {
          data: {
            type: "appStoreVersions",
            attributes: {
              platform: "IOS",
              versionString: VERSION,
              copyright: source.version.attributes.copyright,
              releaseType: source.version.attributes.releaseType,
            },
            relationships: {app: {data: {type: "apps", id: APP_ID}}},
          },
        },
      })
    ).data;
    console.log(`  버전 생성: ${version.id}`);

    let localizations = await all(
      `/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations?limit=200`,
    );
    let localization = localizations.find((item) => item.attributes.locale === LOCALE);
    if (!localization) {
      localization = (
        await request("/v1/appStoreVersionLocalizations", {
          method: "POST",
          body: {
            data: {
              type: "appStoreVersionLocalizations",
              attributes: {locale: LOCALE, ...desiredLocalizationAttributes(source.localization.attributes)},
              relationships: {
                appStoreVersion: {data: {type: "appStoreVersions", id: version.id}},
              },
            },
          },
        })
      ).data;
      console.log(`  ${LOCALE} 현지화 생성: ${localization.id}`);
    } else {
      localization = await updateLocalization(localization, source.localization.attributes);
    }
    const sets = await ensureMediaSets(localization);
    return {version, localization, ...sets};
  }

  const localizations = await all(`/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations?limit=200`);
  let localization = localizations.find((item) => item.attributes.locale === LOCALE);
  if (!localization) {
    throw new Error(`기존 ${VERSION} 버전에 ${LOCALE} 현지화가 없습니다. 자동 복제는 새 버전에만 수행합니다.`);
  }
  localization = await updateLocalization(localization, source.localization.attributes);
  const sets = await ensureMediaSets(localization);
  return {version, localization, ...sets};
}

async function inspect() {
  const ctx = await context();
  const screenshots = [];
  for (const set of ctx.screenshotSets) {
    const items = await all(`/v1/appScreenshotSets/${set.id}/appScreenshots?limit=50`);
    screenshots.push({id: set.id, displayType: set.attributes.screenshotDisplayType, items});
  }
  const previews = [];
  for (const set of ctx.previewSets) {
    const items = await all(`/v1/appPreviewSets/${set.id}/appPreviews?limit=50`);
    previews.push({id: set.id, displayType: set.attributes.previewType, items});
  }
  const result = {
    appId: APP_ID,
    version: {
      id: ctx.version.id,
      attributes: ctx.version.attributes,
    },
    localization: {id: ctx.localization.id, attributes: ctx.localization.attributes},
    screenshots: screenshots.map((set) => ({
      id: set.id,
      displayType: set.displayType,
      items: set.items.map((item) => ({id: item.id, attributes: item.attributes})),
    })),
    previews: previews.map((set) => ({
      id: set.id,
      displayType: set.displayType,
      items: set.items.map((item) => ({id: item.id, attributes: item.attributes})),
    })),
  };
  console.log(JSON.stringify(result, null, 2));
}

function checksum(file) {
  return crypto.createHash("md5").update(fs.readFileSync(file)).digest("hex");
}

function localFiles(directory) {
  if (!fs.existsSync(directory)) throw new Error(`미디어 폴더가 없습니다: ${directory}`);
  return fs
    .readdirSync(directory)
    .filter((name) => /^\d{2}\.(png|jpg|jpeg)$/i.test(name))
    .sort()
    .map((name) => {
      const file = path.join(directory, name);
      return {
        file,
        name: `asc-rebirth-${name}`,
        size: fs.statSync(file).size,
        md5: checksum(file),
      };
    });
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
        `바이너리 업로드 실패 ${response.status} ${operation.method} ${operation.url}\n${(
          await response.text()
        ).slice(0, 1000)}`,
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

async function waitFor(
  resourceType,
  id,
  predicate,
  {timeoutMs = 20 * 60 * 1000, intervalMs = 3000, label = id} = {},
) {
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

async function deleteResource(type, id, label) {
  await request(`/v1/${type}/${id}`, {method: "DELETE"});
  console.log(`  기존 ${label} 제거: ${id}`);
}

async function createScreenshot(setId, item) {
  const created = (
    await request("/v1/appScreenshots", {
      method: "POST",
      body: {
        data: {
          type: "appScreenshots",
          attributes: {fileName: item.name, fileSize: item.size},
          relationships: {
            appScreenshotSet: {data: {type: "appScreenshotSets", id: setId}},
          },
        },
      },
    })
  ).data;
  console.log(`  예약: ${item.name} (${created.id})`);
  await uploadOperations(created.attributes.uploadOperations, item.file);
  await request(`/v1/appScreenshots/${created.id}`, {
    method: "PATCH",
    body: {
      data: {type: "appScreenshots", id: created.id, attributes: {uploaded: true}},
    },
  });
  return waitFor(
    "appScreenshots",
    created.id,
    (resource) => resource.attributes.assetDeliveryState?.state === "COMPLETE",
    {label: item.name},
  );
}

function completedMatch(resources, item) {
  return resources.find(
    (resource) =>
      resource.attributes.fileName === item.name &&
      resource.attributes.assetDeliveryState?.state === "COMPLETE" &&
      // ASC can report COMPLETE before sourceFileChecksum appears in the
      // relationship listing. These filenames are unique to this campaign,
      // so a missing checksum is safe to accept while it propagates.
      (!resource.attributes.sourceFileChecksum ||
        resource.attributes.sourceFileChecksum === item.md5),
  );
}

function isWantedComplete(resource, wanted) {
  const item = wanted.find((candidate) => candidate.name === resource.attributes.fileName);
  return Boolean(
    item &&
      resource.attributes.assetDeliveryState?.state === "COMPLETE" &&
      (!resource.attributes.sourceFileChecksum ||
        resource.attributes.sourceFileChecksum === item.md5),
  );
}

async function updateScreenshotSet(set, directory) {
  const wanted = localFiles(directory);
  if (wanted.length !== 7) throw new Error(`${directory}: 스크린샷이 7장이 아닙니다.`);
  console.log(`\n[${set.attributes.screenshotDisplayType}] 스크린샷 교체`);
  let current = await all(`/v1/appScreenshotSets/${set.id}/appScreenshots?limit=50`);

  // 중단된 이전 업로드가 슬롯을 차지하면 같은 이름으로 재시도하기 전에 제거한다.
  for (const resource of current) {
    if (
      resource.attributes.fileName?.startsWith("asc-rebirth-") &&
      resource.attributes.assetDeliveryState?.state !== "COMPLETE"
    ) {
      await deleteResource("appScreenshots", resource.id, resource.attributes.fileName);
    }
  }
  current = await all(`/v1/appScreenshotSets/${set.id}/appScreenshots?limit=50`);

  // Creation order is the storefront order and ASC has no reorder endpoint.
  // If a previous interrupted run left 02..07 without 01, rebuild only this
  // campaign's draft assets so the final order starts at 01.
  const expectedNames = wanted.map((item) => item.name);
  const campaignScreenshots = current.filter(
    (resource) =>
      resource.attributes.fileName?.startsWith("asc-rebirth-") &&
      resource.attributes.assetDeliveryState?.state === "COMPLETE",
  );
  const campaignNames = campaignScreenshots.map((resource) => resource.attributes.fileName);
  const expectedPrefix = expectedNames.slice(0, campaignNames.length);
  if (JSON.stringify(campaignNames) !== JSON.stringify(expectedPrefix)) {
    console.log("  이전 중단 상태의 순서가 달라 캠페인 자산만 순서대로 재구성합니다.");
    for (const resource of campaignScreenshots) {
      await deleteResource("appScreenshots", resource.id, resource.attributes.fileName);
    }
    current = await all(`/v1/appScreenshotSets/${set.id}/appScreenshots?limit=50`);
  }

  // 9장인 기존 세트에 새 1번을 먼저 올리면 10장 제한 안에서 새 자산을 검증할 수 있다.
  let first = completedMatch(current, wanted[0]);
  if (!first) first = await createScreenshot(set.id, wanted[0]);

  current = await all(`/v1/appScreenshotSets/${set.id}/appScreenshots?limit=50`);
  for (const resource of current) {
    const keep = isWantedComplete(resource, wanted);
    if (!keep) await deleteResource("appScreenshots", resource.id, resource.attributes.fileName);
  }

  current = await all(`/v1/appScreenshotSets/${set.id}/appScreenshots?limit=50`);
  for (const item of wanted) {
    if (!completedMatch(current, item)) {
      await createScreenshot(set.id, item);
      current = await all(`/v1/appScreenshotSets/${set.id}/appScreenshots?limit=50`);
    }
  }

  const final = await all(`/v1/appScreenshotSets/${set.id}/appScreenshots?limit=50`);
  const names = final.map((resource) => resource.attributes.fileName);
  const expected = wanted.map((item) => item.name);
  if (JSON.stringify(names) !== JSON.stringify(expected)) {
    throw new Error(`최종 순서 불일치\n기대: ${expected.join(", ")}\n실제: ${names.join(", ")}`);
  }
  console.log(`  완료: ${names.join(" → ")}`);
}

async function createPreview(setId, item) {
  const created = (
    await request("/v1/appPreviews", {
      method: "POST",
      body: {
        data: {
          type: "appPreviews",
          attributes: {
            fileName: item.name,
            fileSize: item.size,
            mimeType: "video/mp4",
          },
          relationships: {appPreviewSet: {data: {type: "appPreviewSets", id: setId}}},
        },
      },
    })
  ).data;
  console.log(`  예약: ${item.name} (${created.id})`);
  await uploadOperations(created.attributes.uploadOperations, item.file);
  await request(`/v1/appPreviews/${created.id}`, {
    method: "PATCH",
    body: {
      data: {type: "appPreviews", id: created.id, attributes: {uploaded: true}},
    },
  });
  return waitFor(
    "appPreviews",
    created.id,
    (resource) =>
      resource.attributes.assetDeliveryState?.state === "COMPLETE" &&
      resource.attributes.videoDeliveryState?.state === "COMPLETE",
    {label: item.name},
  );
}

async function updatePreviewSet(set, previewPath) {
  const item = {
    file: previewPath,
    name: "asc-rebirth-preview.mp4",
    size: fs.statSync(previewPath).size,
    md5: checksum(previewPath),
  };
  console.log(`\n[${set.attributes.previewType}] 앱 미리보기 교체`);
  let current = await all(`/v1/appPreviewSets/${set.id}/appPreviews?limit=50`);
  for (const resource of current) {
    if (
      resource.attributes.fileName === item.name &&
      (resource.attributes.assetDeliveryState?.state === "FAILED" ||
        resource.attributes.videoDeliveryState?.state === "FAILED")
    ) {
      await deleteResource("appPreviews", resource.id, resource.attributes.fileName);
    }
  }
  current = await all(`/v1/appPreviewSets/${set.id}/appPreviews?limit=50`);
  let target = completedMatch(current, item);
  if (!target || target.attributes.videoDeliveryState?.state !== "COMPLETE") {
    target = await createPreview(set.id, item);
  }
  await request(`/v1/appPreviews/${target.id}`, {
    method: "PATCH",
    body: {
      data: {
        type: "appPreviews",
        id: target.id,
        attributes: {previewFrameTimeCode: PREVIEW_TIMECODE},
      },
    },
  });
  await waitFor(
    "appPreviews",
    target.id,
    (resource) =>
      resource.attributes.previewFrameTimeCode === PREVIEW_TIMECODE &&
      resource.attributes.previewFrameImage?.state?.state === "COMPLETE",
    {label: `${item.name} 포스터`},
  );

  current = await all(`/v1/appPreviewSets/${set.id}/appPreviews?limit=50`);
  for (const resource of current) {
    if (resource.id !== target.id) {
      await deleteResource("appPreviews", resource.id, resource.attributes.fileName);
    }
  }
  console.log(`  완료: ${item.name} · 포스터 ${PREVIEW_TIMECODE}`);
}

async function update() {
  const ctx = await ensureEditableContext();
  if (ctx.version.attributes.appStoreState === "READY_FOR_SALE") {
    throw new Error(`${VERSION}은 판매 중이라 미디어를 변경할 수 없습니다.`);
  }
  const screenshotMap = new Map(
    ctx.screenshotSets.map((set) => [set.attributes.screenshotDisplayType, set]),
  );
  const previewMap = new Map(ctx.previewSets.map((set) => [set.attributes.previewType, set]));
  const targets = [
    {screenshot: "APP_IPHONE_67", preview: "IPHONE_67", directory: "screenshots-6.7"},
    {screenshot: "APP_IPHONE_65", preview: "IPHONE_65", directory: "screenshots-6.5"},
  ];
  for (const target of targets) {
    const set = screenshotMap.get(target.screenshot);
    if (!set) throw new Error(`${target.screenshot} 스크린샷 세트가 없습니다.`);
    await updateScreenshotSet(set, path.join(MEDIA_ROOT, target.directory));
  }
  const previewPath = path.join(MEDIA_ROOT, "preview", "preview-kr-886x1920.mp4");
  for (const target of targets) {
    const set = previewMap.get(target.preview);
    if (!set) throw new Error(`${target.preview} 미리보기 세트가 없습니다.`);
    await updatePreviewSet(set, previewPath);
  }
  console.log("\nASC 미디어 교체 완료");
}

const command = process.argv[2] ?? "inspect";
if (command === "inspect") await inspect();
else if (command === "update") await update();
else throw new Error(`알 수 없는 명령: ${command}`);
