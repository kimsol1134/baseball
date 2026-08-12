/// 게임 화면과 같은 색을 쓴다. 영상만 다른 팔레트를 쓰면 앱을 열었을 때 다른 물건처럼 보인다.
/// 값의 출처는 apps/ios/Sources/DesignSystem.swift의 다크 팔레트다.
export const palette = {
  ink: "#070C0A",
  surface: "#0E1512",
  surfaceRaised: "#141D19",
  hairline: "#26332C",
  bone: "#F1F4EE",
  muted: "#8A9C90",
  lime: "#B7F36B",
  amber: "#E8B24C",
  rust: "#D9714B",
} as const;

/// 한글 굵은 제목은 시스템 폰트가 가장 깨끗하다. 렌더는 macOS 헤드리스 크롬에서 돌아가므로
/// Apple SD Gothic Neo가 실제로 잡힌다. 웹폰트를 링크하면 렌더 중 조용히 대체될 위험이 있다.
export const fontStack =
  '"Apple SD Gothic Neo", "Pretendard", -apple-system, system-ui, sans-serif';

/// 일본어 스토어 자산은 macOS에 기본 포함된 히라기노를 우선한다. 한국어용 폰트로
/// 렌더하면 가나와 한자의 굵기·자간이 흔들려 작은 검색 결과 카드에서 더 거칠게 보인다.
export const japaneseFontStack =
  '"Hiragino Sans", "Hiragino Kaku Gothic ProN", -apple-system, system-ui, sans-serif';

/// 영상은 멀리서 본다. 랜딩페이지 스케일을 그대로 쓰면 아무것도 안 읽힌다.
export const type = {
  display: 108,
  title: 76,
  lead: 40,
  body: 30,
  label: 24,
} as const;
