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
  "pro.role-request.title": entry("보직 지원", "Role request", "役割希望"),
  "pro.role-request.body": entry(
    "이번 시즌 등판 보직을 고릅니다. 수락 전망은 지금 능력과 믿음을 기준으로 합니다.",
    "Choose your outing role for this season. Outlook uses your current ability and trust.",
    "今シーズンの登板役割を選びます。見通しは今の能力と信頼が基準です。"
  ),
  "pro.role-request.outlook.likely": entry("유력", "Likely", "有力"),
  "pro.role-request.outlook.conditional": entry("조건부", "Conditional", "条件付き"),
  "pro.role-request.outlook.difficult": entry("어려움", "Unlikely", "厳しい"),
  "pro.role-request.condition.starter.likely": entry(
    "체력 %lld, 감독의 믿음 %lld — 선발 유력",
    "Stamina %lld, manager faith %lld — starter is likely",
    "体力 %lld、監督の信頼 %lld — 先発が有力"
  ),
  "pro.role-request.condition.starter.conditional": entry(
    "체력 %lld — 6주차에 다시 정합니다",
    "Stamina %lld — reviewed again in week 6",
    "体力 %lld — 第6週に再確認します"
  ),
  "pro.role-request.condition.starter.difficult": entry(
    "체력 %lld — 선발 기준에 미치지 않습니다",
    "Stamina %lld — below the starter bar",
    "体力 %lld — 先発の基準に届きません"
  ),
  "pro.role-request.condition.closer.likely": entry(
    "구위 %lld, 포수와의 호흡 %lld — 마무리 유력",
    "Stuff %lld, catcher trust %lld — closer is likely",
    "球威 %lld、捕手との呼吸 %lld — 抑えが有力"
  ),
  "pro.role-request.condition.closer.conditional": entry(
    "구위 %lld — 6주차에 다시 정합니다",
    "Stuff %lld — reviewed again in week 6",
    "球威 %lld — 第6週に再確認します"
  ),
  "pro.role-request.condition.closer.difficult": entry(
    "구위 %lld — 마무리 기준에 미치지 않습니다",
    "Stuff %lld — below the closer bar",
    "球威 %lld — 抑えの基準に届きません"
  ),
  "pro.role-request.condition.middle": entry(
    "중간 보직은 항상 수락됩니다",
    "Middle relief is always accepted",
    "中継ぎは常に受け入れられます"
  ),
  "settings.glossary.title": entry("용어 설명", "Glossary", "用語の説明"),
  "settings.glossary.footer": entry(
    "구위·제구처럼 화면에 나오는 말을 짧게 풀어 둡니다.",
    "Short definitions for terms that appear on screen, such as Stuff and Command.",
    "球威や制球など、画面に出る言葉を短く説明します。"
  ),
  "glossary.term.hint": entry(
    "용어, 탭하면 설명",
    "Glossary term, tap for the definition",
    "用語、タップで説明"
  ),
  "glossary.sheet.close": entry("닫기", "Close", "閉じる"),
};

const glossary = {
  stuff: {
    name: entry("구위", "Stuff", "球威"),
    definition: entry(
      "공의 힘입니다. 0에서 100까지이며, 높을수록 헛스윙이 늘고 구속이 살아납니다.",
      "Pitch power, scored 0–100. Higher stuff means more whiffs and a livelier fastball.",
      "ボールの力です。0から100までで、高いほど空振りが増え直球が生きます。"
    ),
  },
  command: {
    name: entry("제구", "Command", "制球"),
    definition: entry(
      "원하는 곳에 공을 넣는 힘입니다. 0에서 100까지이며, 볼넷을 줄입니다.",
      "The ability to put the ball where you want, scored 0–100. Better command cuts walks.",
      "狙った場所に投げる力です。0から100までで、四球を減らします。"
    ),
  },
  movement: {
    name: entry("변화구", "Movement", "変化球"),
    definition: entry(
      "공이 얼마나 꺾이고 떨어지는지입니다. 0에서 100까지입니다.",
      "How sharply the ball breaks or drops, scored 0–100.",
      "ボールがどれだけ曲がり落ちるかです。0から100までです。"
    ),
  },
  stamina: {
    name: entry("체력", "Stamina", "体力"),
    definition: entry(
      "긴 이닝을 버티는 힘입니다. 0에서 100까지이며, 선발에 더 많이 필요합니다.",
      "How long you can last, scored 0–100. Starters need more of it.",
      "長いイニングを耐える力です。0から100までで、先発により多く必要です。"
    ),
  },
  fatigue: {
    name: entry("피로", "Fatigue", "疲労"),
    definition: entry(
      "몸이 얼마나 지쳤는지입니다. 높을수록 제구가 흔들리고 부상 위험이 커집니다.",
      "How worn down the arm is. High fatigue shakes command and raises injury risk.",
      "体の消耗です。高いほど制球が揺れ、故障の危険も増えます。"
    ),
  },
  "manager-faith": {
    name: entry("감독의 믿음", "Manager faith", "監督の信頼"),
    definition: entry(
      "감독이 이 투수를 얼마나 쓰려 하는지입니다. 보직과 1군 출전에 영향을 줍니다.",
      "How willing the manager is to use you. It shapes your role and top-level innings.",
      "監督がこの投手をどれだけ使いたいかです。役割と一軍出場に影響します。"
    ),
  },
  "catcher-chemistry": {
    name: entry("포수와의 호흡", "Catcher trust", "捕手との呼吸"),
    definition: entry(
      "배터리로 얼마나 맞춰 던지는지입니다. 제구와 승부 판단에 붙습니다.",
      "How well you and the catcher work as a battery. It helps command and game-calling.",
      "バッテリーとしてどれだけ噛み合うかです。制球と配球に効きます。"
    ),
  },
  mastery: {
    name: entry("숙련", "Mastery", "熟練"),
    definition: entry(
      "같은 능력을 오래 갈아 쌓은 깊이입니다. 레벨이 오르면 같은 수치가 더 잘 나옵니다.",
      "Depth built by repeating the same skill. Higher mastery makes the same rating play better.",
      "同じ能力を長く磨いて積んだ深さです。レベルが上がると同じ数値がより生きます。"
    ),
  },
  "talent-wall": {
    name: entry("재능 벽", "Talent wall", "才能の壁"),
    definition: entry(
      "훈련으로 당장 넘기 어려운 상한입니다. 각성이나 성장 대성공으로 열립니다.",
      "A ceiling that ordinary training cannot cross yet. Awakening or a rare growth burst can open it.",
      "普通の訓練ではすぐ越えにくい上限です。覚醒や大成功で開きます。"
    ),
  },
  "baseball-spirit": {
    name: entry("야구혼", "Baseball spirit", "野球魂"),
    definition: entry(
      "이 선수가 남긴 마음가짐입니다. 다음 회차의 시작 힘과 이야기에 남습니다.",
      "The mindset this pitcher leaves behind. It colors the next run's start and story.",
      "この投手が残す心の持ち方です。次の回の始まりと物語に残ります。"
    ),
  },
  awakening: {
    name: entry("각성", "Awakening", "覚醒"),
    definition: entry(
      "한 시즌의 갈림길에서 능력이 크게 열리는 선택입니다. 얻는 것과 잃는 것이 함께 옵니다.",
      "A season turning point that opens a big ability jump. Every gain comes with a tradeoff.",
      "その季節の分かれ道で能力が大きく開く選択です。得るものと失うものが一緒に来ます。"
    ),
  },
  lineage: {
    name: entry("계승", "Lineage", "継承"),
    definition: entry(
      "지난 선수가 다음 선수에게 남기는 힘입니다. 대표 유산과 기억으로 이어집니다.",
      "Power passed from one pitcher to the next, through a signature legacy and memories.",
      "前の投手が次の投手に残す力です。代表遺産と記憶でつながります。"
    ),
  },
  role: {
    name: entry("보직", "Role", "役割"),
    definition: entry(
      "등판 역할입니다. 선발은 긴 이닝, 중간은 연결, 마무리는 마지막 아웃을 책임집니다.",
      "Your outing job. Starters cover long innings, middle relief bridges, closers finish.",
      "登板の役割です。先発は長いイニング、中継ぎはつなぎ、抑えは最後のアウトを担います。"
    ),
  },
  qs: {
    name: entry("QS", "QS", "QS"),
    definition: entry(
      "선발이 6이닝 이상, 자책 3점 이하로 막은 등판입니다. 로테이션 투수의 안정 지표입니다.",
      "A start of at least six innings with three earned runs or fewer. A stability mark for starters.",
      "先発が6イニング以上、自責3点以下に抑えた登板です。先発の安定指標です。"
    ),
  },
  era: {
    name: entry("ERA", "ERA", "ERA"),
    definition: entry(
      "9이닝당 자책점입니다. 낮을수록 실점을 잘 막았다는 뜻입니다.",
      "Earned runs per nine innings. Lower is better run prevention.",
      "9イニングあたりの自責点です。低いほど失点をよく抑えています。"
    ),
  },
  whip: {
    name: entry("WHIP", "WHIP", "WHIP"),
    definition: entry(
      "이닝당 출루 허용입니다. 안타와 볼넷을 합쳐 이닝으로 나눕니다. 낮을수록 좋습니다.",
      "Baserunners allowed per inning — hits plus walks, divided by innings. Lower is better.",
      "イニングあたりの出塁許可です。安打と四球をイニングで割ります。低いほど良いです。"
    ),
  },
  k9: {
    name: entry("K/9", "K/9", "K/9"),
    definition: entry(
      "9이닝당 삼진입니다. 높을수록 구위와 변화구가 타자를 이겼다는 뜻입니다.",
      "Strikeouts per nine innings. Higher means stuff and movement beat hitters more often.",
      "9イニングあたりの奪三振です。高いほど球威と変化球が打者を上回っています。"
    ),
  },
  platoon: {
    name: entry("플래툰", "Platoon", "プラトゥーン"),
    definition: entry(
      "타자의 좌우에 맞춰 투수를 나누어 쓰는 운용입니다. 반대손 승부에 불리할 때 꺼냅니다.",
      "Splitting pitchers by batter handedness. Used when the opposite-side matchup is a problem.",
      "打者の左右に合わせて投手を分ける運用です。逆方向の勝負が不利なときに出します。"
    ),
  },
  "pitcher-lab": {
    name: entry("투수연구소", "Pitcher lab", "投手研究所"),
    definition: entry(
      "구종을 다듬고 숙련을 쌓는 오프시즌 공간입니다. 실전 전에 감각을 올립니다.",
      "An offseason space to shape pitches and build mastery before live innings.",
      "球種を整え熟練を積むオフシーズンの場です。実戦の前に感覚を上げます。"
    ),
  },
  "season-decision": {
    name: entry("시즌 결정", "Season decision", "シーズン決定"),
    definition: entry(
      "시즌 중간에 멈추는 갈림길입니다. 고른 효과는 바로 적용되고, 어떤 선택은 몇 주 뒤에 결과가 남습니다.",
      "A midseason fork. Effects apply now, and some choices leave a result a few weeks later.",
      "シーズン途中で止まる分かれ道です。選んだ効果はすぐ適用され、いくつかは数週間後に結果が残ります。"
    ),
  },
};

const gameContent = {
  "content.pro-news.role-request.rejected.starter": entry(
    "보직 지원이 거절되었습니다. 체력과 감독의 믿음이 선발 기준에 미치지 않습니다.",
    "The role request was declined. Stamina and manager faith missed the starter bar.",
    "役割希望は見送られました。体力と監督の信頼が先発の基準に届きませんでした。"
  ),
  "content.pro-news.role-request.rejected.closer": entry(
    "보직 지원이 거절되었습니다. 구위와 포수와의 호흡이 마무리 기준에 미치지 않습니다.",
    "The role request was declined. Stuff and catcher trust missed the closer bar.",
    "役割希望は見送られました。球威と捕手との呼吸が抑えの基準に届きませんでした。"
  ),
};

for (const [id, copy] of Object.entries(glossary)) {
  gameContent[`content.glossary.${id}.name`] = copy.name;
  gameContent[`content.glossary.${id}.definition`] = copy.definition;
}

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
