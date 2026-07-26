import { readFileSync, readdirSync } from "node:fs";
import { extname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../", import.meta.url));
const sourceRoots = [
  "apps/windows/src",
  "apps/ios/Sources",
  "packages/simulation-core/Sources/SimulationCore",
];
const allowedExtensions = new Set([".swift", ".ts", ".tsx"]);
const excludedSuffixes = [".test.ts", ".test.tsx"];

// 화면에서 뜻을 바로 알 수 있는 말로 바꾼 표현들입니다. 새 콘텐츠가 예전
// 내부 용어를 다시 노출하면 CI에서 발견할 수 있도록 정확한 문구만 검사합니다.
const blockedCopy = [
  "스트라이크 재현성",
  "목표점 재현",
  "경계 재현",
  "코스 재현",
  "현재 능력과 잠재 범위",
  "정보 정확도",
  "관계 신뢰",
  "감독 신뢰",
  "포수 신뢰",
  "커리어 이정표",
  "보직 경쟁 평가전",
  "다음 보직",
  "이번 구간",
  "실행 품질",
  "타구 품질 지수",
  "경기 설계",
  "릴리스 반복",
  "반복되는 릴리스",
  "노림수 형성",
  "커맨드",
  "무브먼트",
  // 능력치 `stuff`를 부르는 이름은 "구위" 하나다. 한때 화면마다 "공의 위력"·"구속"으로
  // 달리 불러서, 사는 사람이 훈련 항목과 능력치 항목을 이어 붙이지 못했다.
  // "구속"은 실제 속도(km/h)를 말할 때만 쓴다.
  "공의 위력",
  // 능력치 `movement`는 "변화구"다.
  "공의 움직임",
];

// 기본 배포 콘텐츠는 독자적인 가상 야구 세계관만 사용합니다. 약칭 하나만
// 검사하면 코드 식별자와 충돌할 수 있어, 실제 리그·구단의 식별 가능한 정식
// 표현을 소스와 사용자 문구에서 차단합니다. 문서와 테스트 fixture는 제외합니다.
const blockedWorldTerms = [
  "KBO",
  "한국야구위원회",
  "LG 트윈스",
  "한화 이글스",
  "SSG 랜더스",
  "삼성 라이온즈",
  "롯데 자이언츠",
  "KIA 타이거즈",
  "두산 베어스",
  "KT 위즈",
  "kt wiz",
  "NC 다이노스",
  "키움 히어로즈",
  // 실제 대구 경원고등학교와 정확히 충돌해 교체한 이전 가상 학교명.
  "대구경원고",
  // 공식 학교 데이터·독립구단 이력과 정확히 겹치거나 오인 위험이 높아 은퇴한 명칭.
  "수원화홍고",
  "수원매원고",
  "고양백송고",
  "인천 웨이브스",
  "인천제문포고",
  "수원유림고",
  "대전한별고",
  "대전대림고",
  "광주제원고",
  "광주동진고",
  "광주진광고",
  "대구상림고",
  "부산개원고",
  "부산남경고",
  "청주원흥고",
  "천안북원고",
  "아산온천고",
  "전주완성고",
  "군산상림고",
  "순천효원고",
  "포항해철고",
  "창원용해고",
  "창원기성고",
  "마산용해고",
  "김해가원고",
  "거제옥림고",
];

function filesUnder(directory) {
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) return filesUnder(path);
    if (!allowedExtensions.has(extname(path)) || excludedSuffixes.some((suffix) => path.endsWith(suffix))) return [];
    return [path];
  });
}

const failures = [];
for (const sourceRoot of sourceRoots) {
  for (const path of filesUnder(join(root, sourceRoot))) {
    const source = readFileSync(path, "utf8");
    const lines = source.split("\n");
    for (const blocked of blockedCopy) {
      lines.forEach((line, index) => {
        if (line.includes(blocked)) failures.push(`${relative(root, path)}:${index + 1} — ${blocked}`);
      });
    }
    for (const blocked of blockedWorldTerms) {
      lines.forEach((line, index) => {
        if (line.includes(blocked)) failures.push(`${relative(root, path)}:${index + 1} — 실존 야구 IP 직접 지칭: ${blocked}`);
      });
    }
  }
}

if (failures.length > 0) {
  console.error(`문구 품질 검사 실패 (${failures.length})`);
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}

console.log(`문구 품질 검사 통과: 내부 용어 ${blockedCopy.length}종·실존 야구 IP ${blockedWorldTerms.length}종 미노출`);
