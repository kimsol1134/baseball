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
  "record.goal-board.title": entry("커리어 목표판", "Career goal board", "キャリア目標板"),
  "record.goal-board.progress": entry("%lld/%lld", "%lld/%lld", "%lld/%lld"),
  "record.goal-board.completed": entry("완료", "Done", "達成"),
  "record.goal-board.conditions": entry("조건", "Conditions", "条件"),
  "pro.weekly.goal-board.title": entry("다음 목표", "Next goal", "次の目標"),
  "pro.weekly.goal-board.line": entry(
    "%@ %lld/%lld",
    "%@ %lld/%lld",
    "%@ %lld/%lld"
  ),
  "pro.weekly.goal-board.complete": entry(
    "칸을 다 채웠습니다",
    "Every cell is filled",
    "マスをすべて埋めました"
  ),
  "pro.weekly.goal-board.hint": entry(
    "기록 탭에서 목표판을 엽니다",
    "Opens the goal board on Records",
    "記録タブで目標板を開きます"
  ),
};

const gameContent = {
  "content.goal-board.ambition-metric.anchor-team-seasons.title": entry(
    "기준 구단 시즌",
    "Anchor-team seasons",
    "アンカーチーム在籍年数"
  ),
  "content.goal-board.ambition-metric.anchor-team-seasons.hint": entry(
    "같은 팀에서 시즌을 이어 한 구단의 상징에 다가갑니다.",
    "Stay with the same club to close in on franchise icon.",
    "同じチームでシーズンを重ね、球団の象徴に近づきます。"
  ),
  "content.goal-board.ambition-metric.anchor-team-legacy.title": entry(
    "기준 구단 유산",
    "Anchor-team legacy",
    "アンカーチームのレガシー"
  ),
  "content.goal-board.ambition-metric.anchor-team-legacy.hint": entry(
    "한 팀의 레거시 점수를 80까지 올립니다.",
    "Raise one club's legacy score to 80.",
    "1チームのレガシースコアを80まで上げます。"
  ),
  "content.goal-board.ambition-metric.hall-of-fame-projection.title": entry(
    "명예의 전당 예상",
    "Hall of Fame projection",
    "殿堂入り予想"
  ),
  "content.goal-board.ambition-metric.hall-of-fame-projection.hint": entry(
    "통산 성적과 수상으로 명예의 전당 예측을 올립니다.",
    "Build counting stats and awards to lift the Hall of Fame projection.",
    "通算成績と受賞で殿堂入り予想を上げます。"
  ),
  "content.goal-board.ambition-metric.awards.title": entry(
    "인정 수상",
    "Recognized awards",
    "認定された受賞"
  ),
  "content.goal-board.ambition-metric.awards.hint": entry(
    "시즌 수상을 모아 기록으로 남깁니다.",
    "Collect season awards to land in the record book.",
    "シーズンの受賞を集めて記録に残します。"
  ),
  "content.goal-board.ambition-metric.pro-seasons.title": entry(
    "프로 시즌",
    "Pro seasons",
    "プロ在籍シーズン"
  ),
  "content.goal-board.ambition-metric.pro-seasons.hint": entry(
    "시즌을 이어 프로 생활을 길게 가져갑니다.",
    "Keep taking seasons to stretch a long pro career.",
    "シーズンを重ねて長いプロ生活を続けます。"
  ),
  "content.goal-board.ambition-metric.major-service-years.title": entry(
    "1군 등록",
    "Major-league service",
    "一軍在籍"
  ),
  "content.goal-board.ambition-metric.major-service-years.hint": entry(
    "1군 시즌을 쌓아 근속을 채웁니다.",
    "Stack major-level seasons to fill service time.",
    "一軍シーズンを積んで在籍年数を満たします。"
  ),
  "content.goal-board.retired-number.title": entry("영구결번", "Retired number", "永久欠番"),
  "content.goal-board.retired-number.hint": entry(
    "이적하면 마지막 팀 시즌과 레거시가 다시 쌓입니다.",
    "A transfer resets last-team seasons and legacy.",
    "移籍すると最後のチームの在籍年数とレガシーが積み直しになります。"
  ),
  "content.goal-board.retired-number.seasons.title": entry(
    "마지막 팀 시즌",
    "Last-team seasons",
    "最後のチーム在籍年数"
  ),
  "content.goal-board.retired-number.legacy.title": entry(
    "마지막 팀 레거시",
    "Last-team legacy",
    "最後のチームレガシー"
  ),
  "content.goal-board.retired-number.fan.title": entry("팬 지지", "Fan support", "ファン支持"),
  "content.goal-board.club-hall.title": entry(
    "구단 명예의 전당",
    "Club hall",
    "球団殿堂"
  ),
  "content.goal-board.club-hall.hint": entry(
    "영구결번을 받은 팀은 구단 명예의 전당에서 빠집니다.",
    "A retired-number club is left out of club hall.",
    "永久欠番になったチームは球団殿堂から外れます。"
  ),
  "content.goal-board.club-hall.seasons.title": entry("구단 시즌", "Club seasons", "球団在籍年数"),
  "content.goal-board.club-hall.legacy.title": entry("구단 레거시", "Club legacy", "球団レガシー"),
  "content.goal-board.hall-of-fame.title": entry("명예의 전당", "Hall of Fame", "殿堂入り"),
  "content.goal-board.hall-of-fame.hint": entry(
    "시즌을 쌓고 수상하면 예측 점수가 오릅니다.",
    "More seasons and awards raise the projection.",
    "シーズンと受賞を重ねると予想点が上がります。"
  ),
  "content.goal-board.milestone-games.title": entry("통산 경기", "Career games", "通算登板"),
  "content.goal-board.milestone-games.hint": entry(
    "등판을 이어 다음 경기 기록에 닿습니다.",
    "Keep taking the mound to reach the next game mark.",
    "登板を重ねて次の試合記録に届きます。"
  ),
  "content.goal-board.milestone-strikeouts.title": entry(
    "통산 탈삼진",
    "Career strikeouts",
    "通算奪三振"
  ),
  "content.goal-board.milestone-strikeouts.hint": entry(
    "삼진을 모아 다음 탈삼진 기록에 닿습니다.",
    "Keep striking hitters out to reach the next mark.",
    "三振を集めて次の奪三振記録に届きます。"
  ),
  "content.goal-board.team-legacy-tier.title": entry("팀 레거시", "Team legacy", "チームレガシー"),
  "content.goal-board.team-legacy-tier.hint": entry(
    "한 팀에서 시즌을 이어 레거시 점수를 올립니다.",
    "Stay with one club and raise its legacy score.",
    "1チームでシーズンを重ねレガシースコアを上げます。"
  ),
};

function mergeCatalog(relativePath, additions) {
  const path = join(root, relativePath);
  const json = JSON.parse(readFileSync(path, "utf8"));
  json.strings = { ...json.strings, ...additions };
  writeFileSync(path, `${JSON.stringify(json, null, 2)}\n`);
}

mergeCatalog("apps/ios/Sources/Presentation/Localization/Localizable.xcstrings", localizable);
mergeCatalog("apps/ios/Sources/Presentation/Localization/GameContent.xcstrings", gameContent);
console.log(
  `injected ${Object.keys(localizable).length} localizable keys and ${Object.keys(gameContent).length} game-content keys`
);
