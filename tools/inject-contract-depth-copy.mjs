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
  "pro.contract.offer.interest.hot": entry("관심 높음", "High interest", "関心が高い"),
  "pro.contract.offer.interest.warm": entry("관심 보통", "Moderate interest", "関心は普通"),
  "pro.contract.offer.interest.cool": entry("관심 낮음", "Low interest", "関心が低い"),
  "pro.contract.offer.counter.action": entry("요구하기", "Make a demand", "要求する"),
  "pro.contract.offer.counter.title": entry("잔류 조건을 요구합니다", "Ask to stay on better terms", "残留条件を求めます"),
  "pro.contract.offer.counter.extra-year": entry("계약 연수 +1", "Add one year", "契約年数+1"),
  "pro.contract.offer.counter.raise-salary": entry("연봉 +10%", "Raise salary 10%", "年俸+10%"),
  "pro.contract.offer.counter.accepted": entry("구단이 요구를 받아들였습니다.", "The club accepted the demand.", "球団が要求を受け入れました。"),
  "pro.contract.offer.counter.rejected": entry("구단이 요구를 거절했습니다. 팬 지지가 조금 줄었습니다.", "The club declined. Fan support dipped.", "球団が要求を断りました。ファン支持が少し下がりました。"),
  "pro.contract.kind.long-term": entry("장기 안정", "Long-term stability", "長期安定"),
  "pro.offseason.investment.choice.equipment": entry("장비 업그레이드", "Equipment upgrade", "用具アップグレード"),
  "pro.offseason.investment.choice.personal-trainer": entry("개인 트레이너", "Personal trainer", "専属トレーナー"),
  "pro.offseason.investment.benefit.equipment": entry("다음 시즌 부상 압력이 줄어듭니다.", "Next season's injury pressure drops.", "次のシーズンの故障圧力が下がります。"),
  "pro.offseason.investment.benefit.personal-trainer": entry("다음 시즌 훈련 성장이 빨라집니다.", "Next season's training growth is faster.", "次のシーズンの練習成長が速くなります。"),
};

const gameContent = {
  "content.contract.counter.unavailable.years": entry(
    "계약 연수를 더 늘릴 수 없습니다.",
    "The deal cannot add another year.",
    "契約年数はこれ以上増やせません。"
  ),
  "content.contract.counter.unavailable.dominance": entry(
    "이 요구는 다른 제안과 균형을 깨뜨립니다.",
    "This demand would unbalance the other offers.",
    "この要求は他の提示とのバランスを崩します。"
  ),
  "content.contract.counter.unavailable.salary-band": entry(
    "이 요구는 허용된 연봉 범위를 벗어납니다.",
    "This demand would leave the allowed salary range.",
    "この要求は認められる年俸の範囲を外れます。"
  ),
  "content.contract.interest.hot.demand": entry(
    "이 구단은 지금 투수 수요가 커서 강하게 접촉합니다.",
    "This club needs pitching and is pressing hard.",
    "この球団は今投手需要が大きく、強く接触しています。"
  ),
  "content.contract.interest.hot.contention": entry(
    "우승을 노리는 구단이라 영입 온도가 높습니다.",
    "A contender, so the pursuit is hot.",
    "優勝を狙う球団なので獲得の温度が高いです。"
  ),
  "content.contract.interest.warm.loyalty": entry(
    "함께 한 시즌이 있어 잔류 접촉은 꾸준합니다.",
    "Shared seasons keep the stay talks steady.",
    "一緒に過ごしたシーズンがあり、残留の接触は安定しています。"
  ),
  "content.contract.interest.warm.demand": entry(
    "전력에 보탤 여지는 있지만 최우선은 아닙니다.",
    "They could use the help, but it is not their top chase.",
    "戦力にはなりますが、最優先ではありません。"
  ),
  "content.contract.interest.cool.opportunity": entry(
    "재건 중인 구단이라 접촉은 가벼운 편입니다.",
    "A rebuilding club, so the outreach is light.",
    "再建中の球団なので接触は軽めです。"
  ),
  "content.contract.interest.cool.depth": entry(
    "이미 투수진이 두터워 관심은 낮습니다.",
    "Their pitching depth is already thick, so interest is low.",
    "すでに投手陣が厚く、関心は低めです。"
  ),
  "content.glossary.signing-bonus.name": entry("계약금", "Signing bonus", "契約金"),
  "content.glossary.signing-bonus.definition": entry(
    "계약을 맺을 때 먼저 받는 돈입니다. 연봉과 별도로 통장에 들어옵니다.",
    "Money paid up front when you sign, separate from annual salary.",
    "契約を結ぶときに先に受け取るお金です。年俸とは別に口座に入ります。"
  ),
  "content.glossary.club-interest.name": entry("구단 관심", "Club interest", "球団の関心"),
  "content.glossary.club-interest.definition": entry(
    "지금 이 선수를 얼마나 원하는지입니다. 높음·보통·낮음으로 표시됩니다.",
    "How badly the club wants you right now, shown as high, moderate, or low.",
    "今この選手をどれだけ欲しいかです。高い・普通・低いで示されます。"
  ),
};

function mergeCatalog(relativePath, additions) {
  const path = join(root, relativePath);
  const catalog = JSON.parse(readFileSync(path, "utf8"));
  catalog.strings = { ...catalog.strings, ...additions };
  writeFileSync(path, JSON.stringify(catalog, null, 2) + "\n");
}

mergeCatalog("apps/ios/Sources/Presentation/Localization/Localizable.xcstrings", localizable);
mergeCatalog("apps/ios/Sources/Presentation/Localization/GameContent.xcstrings", gameContent);
