import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");

function unit(value) {
  return { stringUnit: { state: "translated", value } };
}

function entry(ko, en, ja) {
  return { localizations: { en: unit(en), ja: unit(ja), ko: unit(ko) } };
}

const localizable = {
  "pro.role-request.condition.assigned": entry(
    "이미 맡은 보직입니다",
    "This is already your assigned role",
    "すでに割り当てられた役割です"
  ),
  "pro.summary.week-span.spring-camp": entry(
    "스프링캠프",
    "Spring camp",
    "スプリングキャンプ"
  ),
  "pro.summary.week-span.single": entry(
    "%lld주차",
    "Week %lld",
    "第%lld週"
  ),
  "pro.summary.week-span.range": entry(
    "%1$lld~%2$lld주차",
    "Weeks %1$lld–%2$lld",
    "第%1$lld〜%2$lld週"
  ),
  "pro.decision.followup.runs": entry(
    "실점 %lld",
    "R %lld",
    "失点 %lld"
  ),
  "meta.growth.meaning.best": entry(
    "세대 최고 수준",
    "Generational peak",
    "世代最高レベル"
  ),
  "meta.growth.meaning.pro-top": entry(
    "프로 최상급",
    "Elite pro",
    "プロ最上"
  ),
  "meta.growth.meaning.above-pro": entry(
    "프로 평균 이상",
    "Above pro average",
    "プロ平均以上"
  ),
  "meta.growth.meaning.pro-average": entry(
    "프로 평균",
    "Pro average",
    "プロ平均"
  ),
  "meta.growth.meaning.rotation": entry(
    "1군 로테이션 경쟁",
    "Competing for a major rotation",
    "一軍ローテーション争い"
  ),
  "meta.growth.meaning.call-up": entry(
    "1군 승격",
    "Major-league call-up",
    "一軍昇格"
  ),
  "meta.growth.meaning.role": entry(
    "보직 경쟁",
    "Competing for a role",
    "役割争い"
  ),
  "meta.growth.meaning.farm": entry(
    "2군 정착",
    "Settling in the minors",
    "二軍定着"
  ),
  "meta.growth.meaning.adjusting": entry(
    "2군 적응",
    "Adjusting in the minors",
    "二軍適応"
  ),
};

function mergeCatalog(relativePath, additions) {
  const path = join(root, relativePath);
  const catalog = JSON.parse(readFileSync(path, "utf8"));
  catalog.strings = { ...catalog.strings, ...additions };
  writeFileSync(path, `${JSON.stringify(catalog, null, 2)}\n`);
}

mergeCatalog("apps/ios/Sources/Presentation/Localization/Localizable.xcstrings", localizable);
console.log(`merged ${Object.keys(localizable).length} Localizable keys`);
