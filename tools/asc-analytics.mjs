#!/usr/bin/env node
// App Store Connect 애널리틱스 리포트를 내려받는다.
//
// 왜 필요한가: Firebase·Amplitude는 "앱을 연 뒤"만 본다. 임프레션 → 제품 페이지 조회 →
// 다운로드로 이어지는 스토어 앞단은 여기서만 나온다. 유료 앱은 그 앞단이 매출 그 자체다.
//
//   node tools/asc-analytics.mjs list                     # 받을 수 있는 리포트 목록
//   node tools/asc-analytics.mjs pull "App Downloads Standard"
//   node tools/asc-analytics.mjs pull "App Store Discovery and Engagement Standard" --weekly
//   node tools/asc-analytics.mjs sales 2026-07-20 2026-08-07   # 일별 판매 유닛·수익
//
// 인증: ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8
//   ASC_KEY_ID(기본 TW3Y8S4M9V) · ASC_ISSUER(기본 팀 발급자) 환경변수로 바꿀 수 있다.
//
// 리포트 요청(analyticsReportRequests)은 2026-08-08에 ONGOING으로 한 번 생성해 뒀다.
// 인스턴스는 Apple이 하루 단위로 만들어 붙이므로, 요청 직후 하루 정도는 비어 있는 게 정상이다.

import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import zlib from "node:zlib";

const KEY_ID = process.env.ASC_KEY_ID ?? "TW3Y8S4M9V";
const ISSUER = process.env.ASC_ISSUER ?? "f4843e26-5b1f-4b00-bd4a-d24ca4539774";
const APP_ID = process.env.ASC_APP_ID ?? "6794754217";
/// 판매 리포트 전용. ASC 웹 "결제 및 재무 보고서"의 공급업체 번호이고, API로는 조회할 수 없다.
const VENDOR = process.env.ASC_VENDOR ?? "93867732";
const OUT_DIR = path.join(process.cwd(), "artifacts", "analytics");

function token() {
  const keyPath = path.join(os.homedir(), ".appstoreconnect", "private_keys", `AuthKey_${KEY_ID}.p8`);
  if (!fs.existsSync(keyPath)) throw new Error(`인증 키가 없습니다: ${keyPath}`);
  const now = Math.floor(Date.now() / 1000);
  const encode = (o) => Buffer.from(JSON.stringify(o)).toString("base64url");
  const head = encode({ alg: "ES256", kid: KEY_ID, typ: "JWT" });
  const body = encode({ iss: ISSUER, iat: now, exp: now + 600, aud: "appstoreconnect-v1" });
  // ES256은 반드시 ieee-p1363 — 기본 DER 서명은 Apple이 401로 거절한다.
  const sig = crypto
    .sign("sha256", Buffer.from(`${head}.${body}`), { key: fs.readFileSync(keyPath, "utf8"), dsaEncoding: "ieee-p1363" })
    .toString("base64url");
  return `${head}.${body}.${sig}`;
}

async function api(pathOrUrl) {
  const url = pathOrUrl.startsWith("http") ? pathOrUrl : `https://api.appstoreconnect.apple.com${pathOrUrl}`;
  const res = await fetch(url, { headers: { Authorization: `Bearer ${token()}` } });
  const text = await res.text();
  if (!res.ok) throw new Error(`${res.status} ${url}\n${text.slice(0, 500)}`);
  return JSON.parse(text);
}

/// 이 앱의 리포트 요청. 없으면 만들라고 알려 준다 — 조용히 새로 만들면
/// 요청이 계정에 중복으로 쌓인다.
async function requestID() {
  const { data } = await api(`/v1/apps/${APP_ID}/analyticsReportRequests?limit=20`);
  const ongoing = data.find((d) => d.attributes.accessType === "ONGOING") ?? data[0];
  if (!ongoing) throw new Error("리포트 요청이 없습니다. ASC에서 ONGOING 요청을 먼저 만드세요.");
  return ongoing.id;
}

async function reports() {
  const { data } = await api(`/v1/analyticsReportRequests/${await requestID()}/reports?limit=200`);
  return data;
}

async function list() {
  const wanted = new Set(["COMMERCE", "APP_STORE_ENGAGEMENT", "APP_USAGE"]);
  const rows = (await reports())
    .filter((r) => wanted.has(r.attributes.category))
    .sort((a, b) => a.attributes.category.localeCompare(b.attributes.category));
  for (const r of rows) console.log(`${r.attributes.category.padEnd(22)} ${r.attributes.name}`);
  console.log(`\n(장사 지표는 COMMERCE·APP_STORE_ENGAGEMENT부터 본다. 전체 ${rows.length}종)`);
}

async function pull(name, granularity) {
  const report = (await reports()).find((r) => r.attributes.name === name);
  if (!report) throw new Error(`그런 리포트가 없습니다: ${name}\n먼저 'list'로 이름을 확인하세요.`);
  const { data: instances } = await api(
    `/v1/analyticsReports/${report.id}/instances?limit=200&filter[granularity]=${granularity}`,
  );
  if (instances.length === 0) {
    console.log(`아직 인스턴스가 없습니다 (${name} / ${granularity}).`);
    console.log("리포트 요청 직후에는 정상입니다 — Apple이 하루 단위로 만들어 붙입니다.");
    return;
  }
  fs.mkdirSync(OUT_DIR, { recursive: true });
  // 최신 인스턴스 하나면 충분하다 — 인스턴스 하나가 그 기간 전체를 담는다.
  const latest = instances.sort((a, b) => b.attributes.processingDate.localeCompare(a.attributes.processingDate))[0];
  const { data: segments } = await api(`/v1/analyticsReportInstances/${latest.id}/segments?limit=100`);
  for (const [index, segment] of segments.entries()) {
    const res = await fetch(segment.attributes.url); // 서명된 URL이라 인증 헤더를 붙이지 않는다.
    const buf = Buffer.from(await res.arrayBuffer());
    const csv = (() => {
      try {
        return zlib.gunzipSync(buf).toString("utf8");
      } catch {
        return buf.toString("utf8");
      }
    })();
    const slug = name.toLowerCase().replace(/[^a-z0-9]+/g, "-");
    const file = path.join(OUT_DIR, `${slug}-${latest.attributes.processingDate}-${index}.csv`);
    fs.writeFileSync(file, csv);
    console.log(`${path.relative(process.cwd(), file)}  (${csv.split("\n").length - 1}행)`);
  }
}

/// 일별 판매 리포트. 애널리틱스 리포트(다운로드)와 달리 **돈**이 들어 있다 —
/// 유닛·고객 가격·개발자 수익·국가. vendor number가 있어야만 열린다.
async function sales(from, to) {
  const days = [];
  for (let day = new Date(from); day <= new Date(to); day.setDate(day.getDate() + 1)) {
    days.push(day.toISOString().slice(0, 10));
  }
  let units = 0;
  let proceeds = 0;
  const countries = new Map();
  console.log("날짜         구매  업데이트  수익");
  for (const day of days) {
    const query = new URLSearchParams({
      "filter[frequency]": "DAILY",
      "filter[reportSubType]": "SUMMARY",
      "filter[reportType]": "SALES",
      "filter[vendorNumber]": VENDOR,
      "filter[reportDate]": day,
      "filter[version]": "1_1",
    });
    const res = await fetch(`https://api.appstoreconnect.apple.com/v1/salesReports?${query}`, {
      headers: { Authorization: `Bearer ${token()}` },
    });
    if (!res.ok) {
      console.log(`${day}   (리포트 없음 · HTTP ${res.status})`);
      continue;
    }
    const buf = Buffer.from(await res.arrayBuffer());
    const csv = (() => {
      try {
        return zlib.gunzipSync(buf).toString("utf8");
      } catch {
        return buf.toString("utf8");
      }
    })();
    const [header, ...lines] = csv.trim().split("\n");
    const columns = header.split("\t");
    const rows = lines
      .map((line) => Object.fromEntries(columns.map((c, i) => [c, line.split("\t")[i]])))
      .filter((row) => row["Apple Identifier"] === APP_ID);
    // 7로 시작하는 타입은 업데이트다 — 매출이 아니라 기존 사용자 수다. 섞으면 안 된다.
    const isPurchase = (row) => !row["Product Type Identifier"].startsWith("7");
    const bought = rows.filter(isPurchase).reduce((sum, row) => sum + Number(row.Units), 0);
    const updated = rows.filter((row) => !isPurchase(row)).reduce((sum, row) => sum + Number(row.Units), 0);
    const money = rows
      .filter(isPurchase)
      .reduce((sum, row) => sum + Number(row["Developer Proceeds"]) * Number(row.Units), 0);
    for (const row of rows.filter(isPurchase)) {
      countries.set(row["Country Code"], (countries.get(row["Country Code"]) ?? 0) + Number(row.Units));
    }
    units += bought;
    proceeds += money;
    if (bought || updated) {
      console.log(`${day}  ${String(bought).padStart(4)}  ${String(updated).padStart(7)}  ${Math.round(money).toLocaleString()}`);
    }
  }
  console.log(`\n합계: 구매 ${units}건 · 개발자 수익 ${Math.round(proceeds).toLocaleString()}`);
  console.log(`국가: ${[...countries].sort((a, b) => b[1] - a[1]).map(([c, u]) => `${c} ${u}`).join(" · ") || "없음"}`);
}

const [command, ...rest] = process.argv.slice(2);
const granularity = rest.includes("--weekly") ? "WEEKLY" : rest.includes("--monthly") ? "MONTHLY" : "DAILY";
const name = rest.filter((a) => !a.startsWith("--")).join(" ");

try {
  if (command === "list") await list();
  else if (command === "pull" && name) await pull(name, granularity);
  else if (command === "sales") await sales(rest[0] ?? "2026-08-01", rest[1] ?? new Date(Date.now() - 86_400_000).toISOString().slice(0, 10));
  else {
    console.error('사용법: node tools/asc-analytics.mjs list | pull "<리포트 이름>" [--weekly|--monthly] | sales [시작일] [종료일]');
    process.exit(2);
  }
} catch (error) {
  console.error(error.message);
  process.exit(1);
}
