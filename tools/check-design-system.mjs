import { readFileSync, readdirSync } from "node:fs";
import { extname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../", import.meta.url));
const windowsSource = join(root, "apps/windows/src");
const designSystemPath = join(windowsSource, "design-system.css");
const iosSource = join(root, "apps/ios/Sources");
const iosDesignSystemPath = join(iosSource, "DesignSystem.swift");
const allowedExtensions = new Set([".css", ".ts", ".tsx"]);

function filesUnder(directory, extensions = allowedExtensions) {
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) return filesUnder(path, extensions);
    return extensions.has(extname(path)) ? [path] : [];
  });
}

const failures = [];
const rawColorPattern = /#[0-9a-fA-F]{3,8}\b|rgba?\(\s*\d+/g;
const legacyTokenPattern = /var\(--(?:bg|surface|surface-raised|surface-soft|line|line-strong|text|muted|subtle|lime|lime-strong|lime-dark|amber|red|blue|shadow)\)/g;
const sceneSelectorAllowlist = /(gamecast|trajectory)/;

for (const path of filesUnder(windowsSource)) {
  const source = readFileSync(path, "utf8");
  const label = relative(root, path);
  if (path !== designSystemPath && rawColorPattern.test(source)) failures.push(`${label}: 중앙 토큰 밖의 원시 색상 값`);
  rawColorPattern.lastIndex = 0;
  if (legacyTokenPattern.test(source)) failures.push(`${label}: 레거시 색상 토큰 참조`);
  legacyTokenPattern.lastIndex = 0;
  if (path.endsWith(".css") && path !== designSystemPath) {
    const fixedSizes = [...source.matchAll(/font-size:\s*([^;]+);/g)]
      .map((match) => match[1].trim())
      .filter((value) => !/^(?:var|clamp|calc)\(/.test(value));
    if (fixedSizes.length > 0) failures.push(`${label}: 역할 토큰 밖의 고정 글자 크기 — ${[...new Set(fixedSizes)].join(", ")}`);

    for (const rule of source.matchAll(/([^{}]+)\{([^{}]*)\}/g)) {
      if (rule[1].includes("@media") && !rule[2].includes("var(--scene-")) continue;
      if (rule[2].includes("var(--scene-") && !sceneSelectorAllowlist.test(rule[1])) {
        failures.push(`${label}: 구장 전용 scene 토큰을 일반 UI에서 사용함 — ${rule[1].trim().replace(/\s+/g, " ")}`);
      }
      if (sceneSelectorAllowlist.test(rule[1]) && rule[2].includes("var(--color-milestone")) {
        failures.push(`${label}: 플레이 장면이 서사 전용 milestone 토큰을 사용함 — ${rule[1].trim().replace(/\s+/g, " ")}`);
      }
    }
  }
  if (path.endsWith(".tsx")) {
    for (const match of source.matchAll(/className="([^"]*(?:primary-action|lab-primary)[^"]*)"/g)) {
      if (!match[1].includes("ds-button--primary")) failures.push(`${label}: 기본 CTA가 공통 primary 버튼 계약을 우회함 — ${match[1]}`);
    }
  }
}

// iOS 셸도 같은 규칙을 따른다. 색은 DesignSystem.swift 한 곳에서만 정의하고, 글자 크기는
// 고정값 대신 Dynamic Type 역할 스타일을 쓴다. 이 검사가 없던 동안 AppShell.swift에
// hex 리터럴 30여 개가 쌓였다(DOC-IOS-PAID §1.3 G6).
const swiftColorPatterns = [
  [/0x[0-9A-Fa-f]{6}(?![0-9A-Fa-f_])/g, "중앙 토큰 밖의 원시 색상 값"],
  [/(?:UIColor|Color)\(\s*(?:red|white|hue):/g, "중앙 토큰 밖의 직접 색상 생성"],
  [/Color\(\s*\.sRGB/g, "중앙 토큰 밖의 직접 색상 생성"],
];

for (const path of filesUnder(iosSource, new Set([".swift"]))) {
  const source = readFileSync(path, "utf8");
  const label = relative(root, path);
  if (path !== iosDesignSystemPath) {
    for (const [pattern, message] of swiftColorPatterns) {
      if (pattern.test(source)) failures.push(`${label}: ${message}`);
      pattern.lastIndex = 0;
    }
  }
  // 숫자 뒤에 곧바로 `,`나 `)`가 오는 것만 잡는다. `13 * scale`처럼 배율에 곱한 값은
  // Canvas 장면 좌표계에 비례하는 크기라 Dynamic Type 대상이 아니다(PitchDramaView).
  const fixedFonts = [...source.matchAll(/\.system\(size:\s*([0-9.]+)\s*[,)]/g)].map((match) => match[1]);
  if (fixedFonts.length > 0) {
    failures.push(`${label}: Dynamic Type 밖의 고정 글자 크기 — ${[...new Set(fixedFonts)].join(", ")}`);
  }
}

// 디자인 시스템은 다크 전용이다(design-system.css 첫 줄의 `color-scheme: dark`). iOS가 기기
// 설정을 따라 라이트로 렌더하면 "Midnight Dugout" 방향이 통째로 사라진다. 색 토큰이 한 파일에서
// 온다는 것만으로는 이 사고를 못 잡아서, 명암 모드 분기 자체를 금지한다.
const themeSource = readFileSync(iosDesignSystemPath, "utf8");
if (/userInterfaceStyle|adaptive\(\s*light:/.test(themeSource)) {
  failures.push("apps/ios/Sources/DesignSystem.swift: 다크 전용 팔레트에 명암 모드 분기가 있음");
}
for (const path of filesUnder(iosSource, new Set([".swift"]))) {
  const source = readFileSync(path, "utf8");
  if (/colorScheme\s*==\s*\.light|preferredColorScheme\(\.light\)/.test(source)) {
    failures.push(`${relative(root, path)}: 라이트 모드 분기`);
  }
}

// 시스템 기본 강조 버튼(`.borderedProminent`)을 금지한다.
//
// 이 스타일은 글자색을 SwiftUI가 알아서 고른다. 앱 tint가 라임(밝은 색)이라 흰 글자가
// 얹히고, 실기기에서 "1주 진행이 흰 글씨라 잘 안 보인다"는 말이 나왔다. `PrimaryPill`은
// 라임 바탕에 어두운 잉크(`actionInk`)를 명시해 대비를 보장한다 — 주 행동은 그것만 쓴다.
for (const path of filesUnder(iosSource, new Set([".swift"]))) {
  const source = readFileSync(path, "utf8");
  if (/buttonStyle\(\.borderedProminent\)/.test(source)) {
    failures.push(
      `${relative(root, path)}: .borderedProminent는 글자색을 시스템이 정해 라임 바탕에서 대비가 깨진다. PrimaryPill을 쓴다`
    );
  }
}

// 좌측 강조 레일을 카드 기본값으로 되돌리는 회귀를 막는다(DOC-19 §7.2). 데스크톱도 한 곳에만
// 쓰는 장치이고, 모든 카드가 반복하면 신호가 아니라 배경이 된다.
const designSystemSwift = readFileSync(iosDesignSystemPath, "utf8");
const cardBlock = designSystemSwift.slice(designSystemSwift.indexOf("struct BaseballCard"));
if (/overlay\(alignment:\s*\.leading\)/.test(cardBlock.slice(0, cardBlock.indexOf("struct StatTile")))) {
  failures.push("apps/ios/Sources/DesignSystem.swift: 카드 기본값에 좌측 강조 레일이 있음");
}

// 레일은 `BaseballCard` 밖에서도 되살아난다. 실제로 `SummaryBanner`가 HStack 왼쪽에 2pt
// 사각형을 세워 매 단계 화면마다 반복되고 있었다 — 카드가 아니어서 위 검사에 걸리지 않았다.
// 그래서 얇은 세로 막대 자체를 금지하고, 정당한 곳만 이름으로 열어 둔다. 새로 필요하면
// 여기 추가하면서 왜 필요한지 적게 만드는 것이 목적이다.
const narrowBarAllowlist = new Map([
  // 능력 게이지 위의 "이전 값" 눈금. 가로 막대 위의 표식이라 텍스트 레일이 아니다.
  ["apps/ios/Sources/AbilityGaugeView.swift", 1],
  // 와인드업 미터를 오가는 바늘. 이것도 가로 막대 위의 표식이다.
  ["apps/ios/Sources/DeliveryControl.swift", 1],
]);
for (const path of filesUnder(iosSource, new Set([".swift"]))) {
  const relativePath = relative(root, path);
  const source = readFileSync(path, "utf8");
  // 폭이 상수인 얇은 프레임. 진행 막대는 폭을 GeometryReader로 계산하므로 걸리지 않는다.
  const hits = source.match(/\.frame\(width:\s*[1-6]\)/g) ?? [];
  const allowed = narrowBarAllowlist.get(relativePath) ?? 0;
  if (hits.length > allowed) {
    failures.push(
      `${relativePath}: 얇은 세로 막대 ${hits.length}개(허용 ${allowed}). 좌측 강조 레일은 쓰지 않는다(DOC-19 §7.2)`
    );
  }
}

const contractChecks = [
  // 유료앱 권한 모델과 iOS 출고 규격. 되돌아가면 릴리스 빌드가 다시 빈 화면이 된다.
  // 시즌 등판 기록이 화면에서 사라지면 3주 건너뛰기가 다시 커리어를 증발시킨다.
  ["apps/ios/Sources/RecordView.swift", "gameLines"],
  ["apps/ios/Sources/AppShell.swift", "최근 등판"],
  ["apps/ios/Sources/CareerBootstrap.swift", "source: .purchase"],
  ["apps/ios/Sources/MobileCareerStore.swift", "case needsSetup"],
  ["apps/ios/Sources/PitchSession.swift", "engine.submitPitch"],
  ["apps/ios/Sources/CareerFlowView.swift", "PitchView(session: session"],
  ["apps/ios/Sources/DesignSystem.swift", "minimumTapTarget"],
  ["apps/ios/project.yml", "UILaunchScreen"],
  ["apps/ios/project.yml", "UISupportedInterfaceOrientations"],
  // 5위권 작업(DOC-IOS-TOP)의 계약. 되돌아가면 손맛·소리·환생 루프가 조용히 사라진다.
  ["apps/ios/Sources/DeliveryControl.swift", "autoRelease"],
  ["apps/ios/Sources/GameAudio.swift", ".mixWithOthers"],
  ["apps/ios/Sources/GameAudio.swift", "nonisolated static func makeSourceNode"],
  ["apps/ios/Sources/HighSchoolCareerStore.swift", "nextInheritance"],
  ["apps/ios/Sources/HighSchoolCareerView.swift", "case .legacy:"],
  ["apps/ios/Sources/AchievementStore.swift", "isGameCenterAuthenticated"],
  ["apps/ios/Sources/SettingsView.swift", "자동 릴리스"],
  // 다크 고정과 중계 그래픽 계약. 큰 숫자·라임 알약·눈썹 라벨이 이 앱의 얼굴이다.
  ["apps/ios/Sources/BaseballApp.swift", "preferredColorScheme(.dark)"],
  ["apps/ios/Sources/DesignSystem.swift", "actionInk"],
  ["apps/ios/Sources/DesignSystem.swift", "struct StatTile"],
  ["apps/ios/Sources/DesignSystem.swift", "struct PrimaryPill"],
  ["apps/ios/Sources/DesignSystem.swift", "heroNumeral"],
  ["apps/ios/Sources/DesignSystem.swift", "func eyebrowStyle"],
  // 승부 5초. 결과가 텍스트 카드로만 돌아가던 상태로 되돌아가면 이 게임의 클립이 사라진다.
  ["apps/ios/Sources/PitchDramaView.swift", "drawFieldShot"],
  ["apps/ios/Sources/PitchDramaView.swift", "drawImpact"],
  ["apps/ios/Sources/PitchView.swift", "PitchDramaView("],
  // A안 카드 언어(DOC-19 §7.2): 의미색이 붙은 것만 면을 갖는다.
  ["apps/ios/Sources/DesignSystem.swift", "var carriesSurface: Bool"],
  ["docs/docs/19_baseball_sim_visual_direction.md", "## 7. iOS 화면 언어"],
  ["apps/ios/Sources/Assets.xcassets/AppIcon.appiconset/Contents.json", '"value" : "tinted"'],
  [".github/workflows/ci.yml", "xcodebuild"],
  ["apps/windows/src/App.tsx", "ds-chip"],
  ["apps/windows/src/HighSchoolCareerView.tsx", "ds-chip"],
  ["apps/windows/src/CareerNewsFeed.tsx", "ds-chip"],
  ["apps/windows/src/main.tsx", 'import "./design-system.css"'],
  ["apps/windows/src/App.tsx", "ds-card ds-player-card panel player-panel"],
  ["apps/windows/src/App.tsx", "ds-button ds-button--primary primary-action"],
  ["apps/windows/src/PitcherLabView.tsx", 'data-stage={snapshot.phase}'],
  ["apps/windows/src/HighSchoolCareerView.tsx", 'data-stage={state.phase}'],
  ["apps/windows/src/HighSchoolCareerView.tsx", 'data-school={state.school?.id}'],
  ["apps/windows/src/HighSchoolCareerView.tsx", 'aria-label={`${metric.label} 1 감소`}'],
  ["apps/windows/src/HighSchoolCareerView.tsx", 'className="mobile-action-jump"'],
  ["apps/windows/src/HighSchoolCareerView.tsx", "<AccessibleModal"],
  ["apps/windows/src/ProCareerView.tsx", 'data-team={state.team.id}'],
  ["apps/windows/src/CoreUnavailableState.tsx", 'aria-live="polite"'],
  ["apps/windows/src/PitcherLabView.tsx", "hasPendingResult"],
  ["apps/windows/src/PitcherLabView.tsx", "writeLabResultAcknowledgement"],
  ["apps/windows/src/PitcherLabView.tsx", "ratingPointsApplied"],
  ["apps/windows/src/PitcherLabView.tsx", "labTrainingForecast"],
  ["apps/windows/src/App.tsx", "effectiveReducedMotion"],
  ["apps/windows/src/App.tsx", "gameStateForReplay"],
  ["apps/windows/src/App.tsx", "pitcherRoleLabel"],
  ["apps/windows/src/App.tsx", "batterScoutingReport"],
  ["apps/windows/src/App.tsx", "coreRecoveryMessage(status.message)"],
  ["apps/windows/src/coreRecoveryMessage.test.ts", "does not expose internal paths"],
  ["apps/windows/src/CharacterProfile.tsx", 'loading="lazy"'],
  ["apps/windows/src/CharacterProfile.tsx", 'decoding="async"'],
  ["apps/windows/src/styles.css", ".app-shell--high-school"],
  ["apps/windows/src/styles.css", ".app-shell--pro"],
  ["apps/windows/src/styles.css", ".app-shell--lab"],
  ["apps/windows/vite.config.ts", 'publicDir: "public"'],
  ["apps/windows/src/HighSchoolCareerView.tsx", 'import { CharacterProfile } from "./CharacterProfile"'],
  ["apps/windows/src/HighSchoolCareerView.tsx", "ds-card ds-card--result training-result-card"],
  ["apps/windows/src/HighSchoolCareerView.tsx", "라이벌의 인정"],
  ["apps/windows/src/ProCareerView.tsx", 'import { CharacterProfile } from "./CharacterProfile"'],
  ["apps/windows/src/CharacterProfile.tsx", 'className={classes}'],
  ["apps/windows/src/ProCareerView.tsx", '"pro_debut"'],
  ["apps/windows/src/ProCareerView.tsx", '"major_debut"'],
  ["apps/windows/src/design-system.css", '.ds-card--milestone'],
  ["apps/windows/src/design-system.css", '.ds-card.ds-card--result.ds-card--positive'],
  ["apps/windows/src/design-system.css", '.ds-scoreboard'],
  ["apps/windows/src/design-system.css", '[data-stage="pro_debut"]'],
  ["apps/windows/src/design-system.css", '[data-stage="major_debut"]'],
  ["apps/windows/src/design-system.css", ':root:has(body.high-contrast)'],
  ["apps/windows/e2e/ui-regression.spec.ts", '390px, 130% type, and high contrast do not overflow'],
  [".github/workflows/ci.yml", "npm run test:e2e"],
  [".github/workflows/ci.yml", "npm run check:web-assets"],
];

for (const [path, expected] of contractChecks) {
  if (!readFileSync(join(root, path), "utf8").includes(expected)) failures.push(`${path}: 필수 계약 누락 — ${expected}`);
}

// 커리어 생성·복원이 다시 빌드 구성에 따라 갈리면 릴리스 빌드에서만 게임이 열리지 않는
// 결함(DOC-IOS-PAID §1.2 D1)이 되살아난다. 시뮬레이터 QA가 배포 빌드를 대표하려면 같은 경로여야 한다.
const careerStoreSource = readFileSync(join(root, "apps/ios/Sources/MobileCareerStore.swift"), "utf8");
if (/#if\s+!?DEBUG/.test(careerStoreSource)) {
  failures.push("apps/ios/Sources/MobileCareerStore.swift: 커리어 생성·복원이 빌드 구성으로 갈림");
}

const mainSource = readFileSync(join(root, "apps/windows/src/main.tsx"), "utf8");
if (mainSource.indexOf('import "./design-system.css"') < mainSource.indexOf('import "./styles.css"')) {
  failures.push("apps/windows/src/main.tsx: 공통 컴포넌트 계약이 기능별 스타일보다 먼저 로드됨");
}

const designSystemSource = readFileSync(designSystemPath, "utf8");
const rootBlock = designSystemSource.match(/^:root\s*\{([\s\S]*?)\n\}/m)?.[1] ?? "";
const highContrastBlock = designSystemSource.match(/:root:has\(body\.high-contrast\),\s*body\.high-contrast\s*\{([\s\S]*?)\n\}/m)?.[1] ?? "";

function tokenMap(block) {
  return new Map([...block.matchAll(/(--[a-z0-9-]+):\s*([^;]+);/g)].map((match) => [match[1], match[2].trim()]));
}

const defaultTokens = tokenMap(rootBlock);
const highContrastTokens = tokenMap(highContrastBlock);
const adaptiveTokenNames = [...defaultTokens.keys()].filter((name) =>
  name.startsWith("--color-") || name.startsWith("--scene-") || (name.startsWith("--team-") && name !== "--team-decoration")
);

for (const name of adaptiveTokenNames) {
  if (!highContrastTokens.has(name)) failures.push(`apps/windows/src/design-system.css: 고대비 대응값 누락 — ${name}`);
}

for (const rule of designSystemSource.matchAll(/([^{}]*\[data-team=[^{}]+)\{([^{}]*)\}/g)) {
  if (/var\(--(?:color|scene)-/.test(rule[2])) {
    failures.push(`apps/windows/src/design-system.css: 구단 장식이 상태색 또는 장면색을 재사용함 — ${rule[1].trim().replace(/\s+/g, " ")}`);
  }
}

function luminance(hex) {
  const channels = hex.slice(1).match(/.{2}/g)?.map((channel) => Number.parseInt(channel, 16) / 255) ?? [];
  const linear = channels.map((channel) => channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4);
  return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2];
}

function contrastRatio(first, second) {
  const brighter = Math.max(luminance(first), luminance(second));
  const darker = Math.min(luminance(first), luminance(second));
  return (brighter + 0.05) / (darker + 0.05);
}

const contrastPairs = [
  ["--color-text-primary", "--color-canvas"],
  ["--color-text-primary", "--color-surface"],
  ["--color-text-secondary", "--color-surface"],
  ["--color-text-tertiary", "--color-surface"],
  ["--color-action-ink", "--color-action"],
  ["--color-selection", "--color-surface"],
  ["--color-milestone", "--color-surface"],
  ["--color-positive", "--color-surface"],
  ["--color-warning", "--color-surface"],
  ["--color-negative", "--color-surface"],
  ["--color-information", "--color-surface"],
];

for (const [mode, tokens] of [["기본", defaultTokens], ["고대비", highContrastTokens]]) {
  for (const [foreground, background] of contrastPairs) {
    const foregroundValue = tokens.get(foreground);
    const backgroundValue = tokens.get(background);
    if (!/^#[0-9a-f]{6}$/i.test(foregroundValue ?? "") || !/^#[0-9a-f]{6}$/i.test(backgroundValue ?? "")) {
      failures.push(`apps/windows/src/design-system.css: ${mode} 대비 검사에 필요한 HEX 토큰 누락 — ${foreground}, ${background}`);
      continue;
    }
    const ratio = contrastRatio(foregroundValue, backgroundValue);
    if (ratio < 4.5) failures.push(`apps/windows/src/design-system.css: ${mode} 텍스트 대비 ${ratio.toFixed(2)}:1 — ${foreground} / ${background}`);
  }
}

if (failures.length > 0) {
  console.error(`디자인 시스템 검사 실패 (${failures.length})`);
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}

{
  const dsSource = readFileSync(designSystemPath, "utf8");
  const chipBlock = dsSource.match(/\.ds-chip \{[^}]+\}/)?.[0] ?? "";
  for (const required of ["display: inline-flex", "align-items: center", "line-height: 1", "padding-block: 1px 0"]) {
    if (!chipBlock.includes(required)) failures.push(`design-system.css: ds-chip 계약에 '${required}' 누락`);
  }
  if (failures.length > 0) {
    console.error(`디자인 시스템 검사 실패 (${failures.length})`);
    for (const failure of failures) console.error(`- ${failure}`);
    process.exit(1);
  }
}
console.log("디자인 시스템 검사 통과: 원시 색상·레거시 토큰·scene/milestone 역할 오용 0, 고정 본문 크기 0, 고대비 토큰 대응 및 WCAG AA 대비, 공통 컴포넌트 계약 확인");
