import React from "react";
import { AbsoluteFill, Img, staticFile, useCurrentFrame } from "remotion";
import { fontStack, palette } from "./theme";

/// App Store 스크린샷.
///
/// 규격은 App Store Connect가 요구하는 6.5" 크기(1242×2688)다. 6.9"로 뽑아 두었다가 슬롯에
/// 안 맞아 다시 만들었다 — ASC가 어떤 크기를 요구하는지 먼저 확인하고 만들어야 한다.
///
/// 판을 짜는 규칙:
///  - 검색 결과에는 앞 3장만 그대로 보인다. 첫 장에서 이 게임이 무엇인지 끝나야 한다.
///  - 한 장에 한 가지. 캡션은 3초 안에 읽혀야 하므로 한 줄, 굵게.
///  - 실제 앱 화면을 쓴다(심사 지침 2.3.3). 배경만 디자인한다.
///  - 라임은 근거 한 줄에만 쓴다. 두 군데 이상 쓰면 시선이 갈라진다.
const FRAME = { width: 1242, height: 2688 };
const CAPTURE = { width: 1206, height: 2622, statusBar: 130 };

type Shot = {
  screen: string;
  caption: React.ReactNode;
  proof: string;
};

export const SHOTS: Shot[] = [
  {
    screen: "04-decision",
    caption: (
      <>
        승부처의 공을
        <br />
        직접 던집니다
      </>
    ),
    proof: "구종 · 코스 · 노림을 내가 고른다",
  },
  {
    screen: "05-verdict",
    caption: (
      <>
        결과의 이유가
        <br />
        그 자리에서 보입니다
      </>
    ),
    proof: "궤적 · 구속 · 존 판정",
  },
  {
    screen: "08-training",
    caption: (
      <>
        고교 3년을
        <br />
        직접 설계합니다
      </>
    ),
    proof: "훈련에는 항상 대가가 있다",
  },
  {
    screen: "03-karma",
    caption: (
      <>
        실패해도
        <br />
        기억은 남습니다
      </>
    ),
    proof: "지명받지 못하면 다음 선수로",
  },
  {
    // 캡션과 화면이 어긋나면 사는 사람이 가장 먼저 알아챈다. "다시 시작"은 선수 생성 화면이다.
    screen: "02-archetype",
    caption: (
      <>
        몇 번이든
        <br />
        다시 시작합니다
      </>
    ),
    proof: "한 번 구매 · 광고 없음 · 앱 내 구입 없음",
  },
];

/// 한 장. `frame`이 곧 몇 번째 스크린샷인지를 가리킨다.
export const Screenshots: React.FC = () => {
  const index = Math.min(SHOTS.length - 1, Math.max(0, useCurrentFrame()));
  const shot = SHOTS[index];

  // 앱 화면. 상태 표시줄을 잘라 내고 아래로 흘려보낸다. 기기 테두리는 그리지 않는다.
  const screenWidth = FRAME.width - 150;
  const scale = screenWidth / CAPTURE.width;
  const screenTop = 700;

  return (
    <AbsoluteFill style={{ background: palette.ink, overflow: "hidden" }}>
      <AbsoluteFill
        style={{
          background: `radial-gradient(64% 40% at 50% 20%, rgba(183,243,107,0.12) 0%, rgba(20,42,30,0.42) 36%, ${palette.ink} 74%)`,
        }}
      />

      <div style={{ padding: "150px 76px 0", textAlign: "center" }}>
        <h2
          style={{
            margin: 0,
            fontFamily: fontStack,
            fontSize: 104,
            lineHeight: 1.18,
            fontWeight: 900,
            letterSpacing: "-0.045em",
            color: palette.bone,
            wordBreak: "keep-all",
          }}
        >
          {shot.caption}
        </h2>
        <p
          style={{
            margin: "36px 0 0",
            fontFamily: fontStack,
            fontSize: 44,
            fontWeight: 700,
            letterSpacing: "-0.01em",
            color: palette.lime,
            wordBreak: "keep-all",
          }}
        >
          {shot.proof}
        </p>
      </div>

      {/* 실제 앱 화면. 아래로 잘려 나가는 편이 기기 안을 들여다보는 느낌을 준다. */}
      <div
        style={{
          position: "absolute",
          top: screenTop,
          left: 75,
          width: screenWidth,
          height: FRAME.height - screenTop,
          overflow: "hidden",
          borderRadius: 52,
          border: `2px solid ${palette.hairline}`,
          background: palette.surface,
        }}
      >
        <Img
          src={staticFile(`screens/${shot.screen}.png`)}
          style={{
            position: "absolute",
            top: -CAPTURE.statusBar * scale,
            width: screenWidth,
            height: CAPTURE.height * scale,
          }}
        />
      </div>
    </AbsoluteFill>
  );
};
