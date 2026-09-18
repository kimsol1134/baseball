// Read-only ASC customer reviews and released metadata. Never prints credentials.
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

const dest=path.join(process.cwd(),'marketing/social/2026-09-review-led/evidence');fs.mkdirSync(dest,{recursive:true});
async function all(p){let rows=[];while(p){const r=await api(p);rows.push(...r.data);p=r.links?.next;}return rows;}
const [app,reviews,versions]=await Promise.all([api(`/v1/apps/${APP_ID}`),all(`/v1/apps/${APP_ID}/customerReviews?limit=200&sort=-createdDate`),all(`/v1/apps/${APP_ID}/appStoreVersions?filter[platform]=IOS&limit=200`)]);
const publicReviews=reviews.map(r=>({id:r.id,...r.attributes}));
fs.writeFileSync(path.join(dest,'asc-reviews.json'),JSON.stringify({fetchedAt:new Date().toISOString(),appId:APP_ID,reviews:publicReviews},null,2));
fs.writeFileSync(path.join(dest,'asc-versions.json'),JSON.stringify(versions,null,2));
const released=versions.filter(v=>['READY_FOR_SALE','READY_FOR_DISTRIBUTION'].includes(v.attributes.appStoreState)).slice(0,4);
const releaseNotes=[];for(const v of released){releaseNotes.push({version:v.attributes,...await api(`/v1/appStoreVersions/${v.id}/appStoreVersionLocalizations?limit=200`)});}
fs.writeFileSync(path.join(dest,'asc-release-notes.json'),JSON.stringify(releaseNotes,null,2));
const lookup=await fetch(`https://itunes.apple.com/lookup?id=${APP_ID}&country=kr`).then(r=>r.json());fs.writeFileSync(path.join(dest,'apple-kr-lookup.json'),JSON.stringify({fetchedAt:new Date().toISOString(),...lookup},null,2));
console.log(JSON.stringify({app:app.data.attributes.name,reviews:reviews.length,byRating:reviews.reduce((a,r)=>(a[r.attributes.rating]=(a[r.attributes.rating]||0)+1,a),{}),versions:versions.slice(0,5).map(v=>v.attributes),store:lookup.results?.map(a=>({name:a.trackName,rating:a.averageUserRating,ratingCount:a.userRatingCount,version:a.version,releaseDate:a.releaseDate}))},null,2));
