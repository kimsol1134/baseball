import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");

function unit(value) {
  return { stringUnit: { state: "translated", value } };
}

function entry(ko, en, ja) {
  return { localizations: { en: unit(en), ja: unit(ja), ko: unit(ko) } };
}

const localizable = {
  "share.card.action": entry("카드 공유", "Share card", "カードを共有"),
  "share.card.preview.title": entry("공유 미리보기", "Share preview", "共有プレビュー"),
  "share.card.preview.share": entry("공유", "Share", "共有"),
  "share.card.render-failed": entry(
    "카드를 그리지 못했습니다. 문구만 공유합니다.",
    "Couldn't draw the card. Sharing the text only.",
    "カードを描けませんでした。テキストだけ共有します。"
  ),
  "share.card.store-badge": entry(
    "App Store에서 받기",
    "On the App Store",
    "App Storeで入手"
  ),
  "share.card.stamp": entry(
    "시드 %@-%lld · 같은 시드로 도전",
    "Seed %@-%lld · Challenge the same seed",
    "シード %@-%lld · 同じシードで挑戦"
  ),
  "share.card.body.challenge": entry(
    "도전 코드 %@-%lld",
    "Challenge code %@-%lld",
    "チャレンジコード %@-%lld"
  ),
  "share.card.summary.retirement": entry(
    "%@, 프로 %lld시즌 은퇴",
    "%@, retired after %lld pro seasons",
    "%@、プロ%lldシーズンで引退"
  ),
  "share.card.summary.draft": entry(
    "%@, %lld라운드 %lld순번 지명",
    "%@ drafted in round %lld, pick %lld",
    "%@、%lld巡目%lld位指名"
  ),
  "share.card.summary.draft-undrafted": entry(
    "%@, 드래프트 미지명",
    "%@ went undrafted",
    "%@、ドラフト指名なし"
  ),
  "share.card.summary.record": entry("%@, %@", "%@, %@", "%@、%@"),
  "share.card.summary.national": entry("%@, %@", "%@, %@", "%@、%@"),
  "share.card.headline.retirement": entry("은퇴", "Retirement", "引退"),
  "share.card.headline.draft": entry("드래프트 지명", "Drafted", "ドラフト指名"),
  "share.card.headline.draft-undrafted": entry("미지명", "Undrafted", "指名なし"),
  "share.card.headline.record": entry("신기록", "New mark", "新記録"),
  "share.card.headline.national": entry("국가대표", "National team", "代表"),
  "share.card.draft.round": entry("라운드", "Round", "巡目"),
  "share.card.draft.pick": entry("순번", "Pick", "順位"),
  "share.card.draft.grade": entry("등급", "Grade", "評価"),
  "share.card.record.qs": entry("QS", "QS", "QS"),
  "share.card.record.runs": entry("실점", "Runs allowed", "失点"),
  "share.card.national.final": entry(
    "결승 %@ %lld-%lld",
    "Final %@ %lld-%lld",
    "決勝 %@ %lld-%lld"
  ),
  "share.card.national.exempted": entry("병역 면제", "Service exemption", "兵役免除"),
};

function mergeCatalog(filename, additions) {
  const path = join(root, "apps/ios/Sources/Presentation/Localization", filename);
  const catalog = JSON.parse(readFileSync(path, "utf8"));
  catalog.strings = { ...catalog.strings, ...additions };
  writeFileSync(path, `${JSON.stringify(catalog, null, 2)}\n`);
}

mergeCatalog("Localizable.xcstrings", localizable);
console.log(`injected ${Object.keys(localizable).length} share.card keys`);
