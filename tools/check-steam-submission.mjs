import { readFileSync, readdirSync } from "node:fs";
import { dirname, extname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];
const passes = [];
const warnings = [];

function pass(message) {
  passes.push(message);
}

function fail(message) {
  failures.push(message);
}

function readJson(path) {
  return JSON.parse(readFileSync(join(root, path), "utf8"));
}

function imageSize(path) {
  const bytes = readFileSync(join(root, path));

  if (bytes.subarray(1, 4).toString("ascii") === "PNG") {
    return { width: bytes.readUInt32BE(16), height: bytes.readUInt32BE(20) };
  }

  if (bytes[0] === 0xff && bytes[1] === 0xd8) {
    let offset = 2;
    while (offset < bytes.length) {
      if (bytes[offset] !== 0xff) {
        offset += 1;
        continue;
      }

      const marker = bytes[offset + 1];
      offset += 2;
      if (marker === 0xd8 || marker === 0xd9) continue;

      const segmentLength = bytes.readUInt16BE(offset);
      if (marker >= 0xc0 && marker <= 0xc3) {
        return {
          width: bytes.readUInt16BE(offset + 5),
          height: bytes.readUInt16BE(offset + 3),
        };
      }
      offset += segmentLength;
    }
  }

  throw new Error(`지원하지 않는 이미지 형식: ${path}`);
}

const assets = [
  ["marketing/steam/assets/store/header-capsule.png", 920, 430],
  ["marketing/steam/assets/store/small-capsule.png", 462, 174],
  ["marketing/steam/assets/store/main-capsule.png", 1232, 706],
  ["marketing/steam/assets/store/vertical-capsule.png", 748, 896],
  ["marketing/steam/assets/store/page-background.png", 1438, 810],
  ["marketing/steam/assets/icons/shortcut-icon.png", 256, 256],
  ["marketing/steam/assets/icons/app-icon.jpg", 184, 184],
  ["marketing/steam/assets/library/library-capsule.png", 600, 900],
  ["marketing/steam/assets/library/library-hero.png", 3840, 1240],
  ["marketing/steam/assets/library/library-logo-1280x720.png", 1280, 720],
  ["marketing/steam/assets/library/library-header-capsule.png", 920, 430],
];

for (const [path, expectedWidth, expectedHeight] of assets) {
  try {
    const { width, height } = imageSize(path);
    if (width !== expectedWidth || height !== expectedHeight) {
      fail(`${path}: ${width}x${height}, 기대값 ${expectedWidth}x${expectedHeight}`);
    } else {
      pass(`${path}: ${width}x${height}`);
    }
  } catch (error) {
    fail(`${path}: ${error.message}`);
  }
}

const rootPackage = readJson("package.json");
const windowsPackage = readJson("apps/windows/package.json");
const tauriConfig = readJson("apps/windows/src-tauri/tauri.conf.json");
const cargoToml = readFileSync(join(root, "apps/windows/src-tauri/Cargo.toml"), "utf8");
const cargoVersion = cargoToml.match(/^version\s*=\s*"([^"]+)"/m)?.[1];
const versions = new Map([
  ["root package", rootPackage.version],
  ["windows package", windowsPackage.version],
  ["Tauri", tauriConfig.version],
  ["Cargo", cargoVersion],
]);
const expectedVersion = rootPackage.version;

for (const [name, version] of versions) {
  if (version === expectedVersion) {
    pass(`${name} 버전 ${version}`);
  } else {
    fail(`${name} 버전 ${version ?? "없음"}; 기대값 ${expectedVersion}`);
  }
}

const uiRoot = join(root, "apps/windows/src");
const uiFiles = readdirSync(uiRoot)
  .filter((name) => extname(name) === ".tsx")
  .map((name) => join(uiRoot, name));
const forbiddenCopy = [
  "분석 JSON 내보내기",
  "로컬 분석 미동의",
  "Pitcher Lab",
  "PITCHER LAB",
  "IMPORTANT INNING",
  "YOUR PITCHER",
];

for (const path of uiFiles) {
  const source = readFileSync(path, "utf8");
  for (const phrase of forbiddenCopy) {
    if (source.includes(phrase)) {
      fail(`${relative(root, path)}: 출시 화면 금지 문구 '${phrase}'`);
    }
  }
}
if (!failures.some((message) => message.includes("출시 화면 금지 문구"))) {
  pass("출시 화면의 내부·혼합 언어 문구 검사");
}

warnings.push("실제 플레이 화면 스크린샷 5장 이상과 플레이 트레일러는 Steamworks 제출 전에 별도 검수해야 합니다.");
warnings.push("Windows 코드 서명과 깨끗한 Windows 11 Steam 클라이언트 QA는 실제 기기에서 완료해야 합니다.");
warnings.push("macOS Developer ID 서명·공증과 Intel/Apple Silicon Steam 클라이언트 QA는 인증서와 실제 기기에서 완료해야 합니다.");
warnings.push("Steamworks App ID, 콘텐츠 설문, 가격·세금·지원 연락처와 상점/빌드 검토 상태는 로컬에서 자동 판정할 수 없습니다.");

console.log("\nSteam 제출 자동 점검\n");
for (const message of passes) console.log(`✓ ${message}`);
for (const message of warnings) console.log(`! ${message}`);
for (const message of failures) console.error(`✗ ${message}`);

if (failures.length > 0) {
  console.error(`\n${failures.length}개 자동 게이트가 실패했습니다.`);
  process.exit(1);
}

console.log(`\n자동 게이트 ${passes.length}개 통과. 위 수동 게이트를 완료한 뒤 Valve 검토에 제출하세요.`);
