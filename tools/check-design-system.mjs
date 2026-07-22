import { readFileSync, readdirSync } from "node:fs";
import { extname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../", import.meta.url));
const windowsSource = join(root, "apps/windows/src");
const designSystemPath = join(windowsSource, "design-system.css");
const allowedExtensions = new Set([".css", ".ts", ".tsx"]);

function filesUnder(directory) {
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const path = join(directory, entry.name);
    return entry.isDirectory() ? filesUnder(path) : allowedExtensions.has(extname(path)) ? [path] : [];
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
    }
  }
  if (path.endsWith(".tsx")) {
    for (const match of source.matchAll(/className="([^"]*(?:primary-action|lab-primary)[^"]*)"/g)) {
      if (!match[1].includes("ds-button--primary")) failures.push(`${label}: 기본 CTA가 공통 primary 버튼 계약을 우회함 — ${match[1]}`);
    }
  }
}

const contractChecks = [
  ["apps/windows/src/main.tsx", 'import "./design-system.css"'],
  ["apps/windows/src/App.tsx", "ds-card ds-player-card panel player-panel"],
  ["apps/windows/src/App.tsx", "ds-button ds-button--primary primary-action"],
  ["apps/windows/src/PitcherLabView.tsx", 'data-stage={snapshot.phase}'],
  ["apps/windows/src/HighSchoolCareerView.tsx", 'data-stage={state.phase}'],
  ["apps/windows/src/ProCareerView.tsx", 'data-team={state.team.id}'],
  ["apps/windows/src/ProCareerView.tsx", '"pro_debut"'],
  ["apps/windows/src/ProCareerView.tsx", '"major_debut"'],
  ["apps/windows/src/design-system.css", '.ds-card--milestone'],
  ["apps/windows/src/design-system.css", '.ds-scoreboard'],
  ["apps/windows/src/design-system.css", '[data-stage="pro_debut"]'],
  ["apps/windows/src/design-system.css", '[data-stage="major_debut"]'],
  ["apps/windows/src/design-system.css", ':root:has(body.high-contrast)'],
];

for (const [path, expected] of contractChecks) {
  if (!readFileSync(join(root, path), "utf8").includes(expected)) failures.push(`${path}: 필수 계약 누락 — ${expected}`);
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

console.log("디자인 시스템 검사 통과: 원시 색상·레거시 토큰·scene 오용 0, 고정 본문 크기 0, 고대비 토큰 대응 및 WCAG AA 대비, 공통 컴포넌트 계약 확인");
