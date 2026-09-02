#!/usr/bin/env node
/**
 * 카피 배치 주입기. 여러 작업자가 xcstrings를 동시에 편집해 충돌하지 않도록,
 * 각자 JSON 파일에 {"Localizable"|"GameContent": {"key": {"ko","en","ja"}}, "__delete": [...]}
 * 형식으로 적어 두면 여기서 한 번에 카탈로그에 넣는다.
 *
 *   node tools/inject-copy-batch.mjs path/to/copy-a.json path/to/copy-b.json
 *
 * 기존 키는 값만 바꾸고(상태 translated), 새 키는 추가한다. 세 언어의 플레이스홀더
 * 서명(%@ / %lld 순서)이 다르면 실패한다.
 */
import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { join } from "node:path";

const root = fileURLToPath(new URL("../", import.meta.url));
const catalogs = {
  Localizable: join(root, "apps/ios/Sources/Presentation/Localization/Localizable.xcstrings"),
  GameContent: join(root, "apps/ios/Sources/Presentation/Localization/GameContent.xcstrings"),
};

function signature(value) {
  return [...value.matchAll(/%(?:\d+\$)?[-+ #0]*\d*(?:\.\d+)?l{0,2}([@diufFeEgG])/g)].map((m) => m[1]).join(",");
}

const files = process.argv.slice(2);
if (files.length === 0) {
  console.error("usage: inject-copy-batch.mjs <copy.json>...");
  process.exit(2);
}

const loaded = Object.fromEntries(
  Object.entries(catalogs).map(([name, path]) => [name, { path, json: JSON.parse(readFileSync(path, "utf8")) }])
);
let added = 0, replaced = 0, deleted = 0;
const failures = [];

for (const file of files) {
  const batch = JSON.parse(readFileSync(file, "utf8"));
  for (const [catalogName, entries] of Object.entries(batch)) {
    if (catalogName === "__delete") continue;
    const catalog = loaded[catalogName];
    if (!catalog) {
      failures.push(`${file}: 알 수 없는 카탈로그 ${catalogName}`);
      continue;
    }
    for (const [key, values] of Object.entries(entries)) {
      const { ko, en, ja } = values;
      if (typeof ko !== "string" || typeof en !== "string" || typeof ja !== "string") {
        failures.push(`${file}: ${key} — ko/en/ja 세 값이 모두 필요`);
        continue;
      }
      const sig = signature(ko);
      if (signature(en) !== sig || signature(ja) !== sig) {
        failures.push(`${file}: ${key} — 플레이스홀더 서명 불일치 (ko=${sig} en=${signature(en)} ja=${signature(ja)})`);
        continue;
      }
      const unit = (value) => ({ stringUnit: { state: "translated", value } });
      const existing = catalog.json.strings[key];
      if (existing) replaced += 1; else added += 1;
      catalog.json.strings[key] = {
        ...(existing ?? {}),
        localizations: { en: unit(en), ja: unit(ja), ko: unit(ko) },
      };
    }
  }
  for (const key of batch.__delete ?? []) {
    for (const catalog of Object.values(loaded)) {
      if (catalog.json.strings[key]) {
        delete catalog.json.strings[key];
        deleted += 1;
      }
    }
  }
}

if (failures.length > 0) {
  console.error(failures.join("\n"));
  process.exit(1);
}

for (const catalog of Object.values(loaded)) {
  // 기존 키 순서를 그대로 두고(새 키는 뒤에 붙는다) 2칸 들여쓰기로 저장해 diff를 작게 유지한다.
  writeFileSync(catalog.path, `${JSON.stringify(catalog.json, null, 2)}\n`);
}
console.log(`추가 ${added} · 교체 ${replaced} · 삭제 ${deleted}`);
