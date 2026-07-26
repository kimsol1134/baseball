import React from "react";
import { AbsoluteFill, Img, interpolate, Sequence, staticFile, useCurrentFrame } from "remotion";
import { DramaClip, Rise, StadiumGlow } from "./parts";
import { fontStack, palette } from "./theme";

/// App Store Connect 앱 미리보기.
///
/// 규격(886×1920 · 30fps · 15~30초 · H.264)에 맞춘 세로 판본이다. 가로 트레일러와 두 가지가
/// 다르다:
///  1. 가격과 "App Store에서 받기"를 넣지 않는다. 가격은 지역마다 달라 Apple이 미리보기에
///     넣지 못하게 한다. 스토어 안에서 트는 영상이라 스토어로 가라는 문구도 뜻이 없다.
///  2. 캡처(1206×2622)와 화면비가 거의 같아 앱 화면을 가장자리까지 채운다. 기기 테두리를
///     그리지 않는 것도 Apple의 요구다.
const screen = (name: string) => staticFile(`screens/${name}.png`);
const drama = (name: string) => staticFile(`drama/${name}.mp4`);

const FRAME = { width: 886, height: 1920 };

const Fade: React.FC<{ children: React.ReactNode; length: number }> = ({ children, length }) => {
  const frame = useCurrentFrame();
  const opacity = Math.min(
    interpolate(frame, [0, 7], [0, 1], { extrapolateRight: "clamp" }),
    interpolate(frame, [length - 7, length], [1, 0], { extrapolateLeft: "clamp" }),
  );
  return <AbsoluteFill style={{ opacity }}>{children}</AbsoluteFill>;
};

/// 자막은 화면 위에 놓는다. 이 앱은 주 버튼(“던지기”·“훈련하기”)이 늘 화면 맨 아래에 있어서
/// 아래에 깔면 매번 가장 눈에 띄는 것을 가린다. 위쪽은 스코어보드와 헤더라 덮어도 잃는 것이 적고,
/// 읽는 사람 눈이 먼저 닿는 자리이기도 하다.
const Caption: React.FC<{ eyebrow: string; title: React.ReactNode }> = ({ eyebrow, title }) => (
  <AbsoluteFill style={{ justifyContent: "flex-start" }}>
    <div
      style={{
        padding: "104px 56px 180px",
        background: `linear-gradient(0deg, rgba(7,12,10,0) 0%, rgba(7,12,10,0.92) 19%, ${palette.ink} 34%)`,
      }}
    >
      <Rise>
        <p
          style={{
            margin: "0 0 12px",
            fontFamily: fontStack,
            fontSize: 25,
            fontWeight: 800,
            letterSpacing: "0.14em",
            color: palette.lime,
          }}
        >
          {eyebrow}
        </p>
      </Rise>
      <Rise delay={6}>
        <h2
          style={{
            margin: 0,
            fontFamily: fontStack,
            fontSize: 58,
            lineHeight: 1.24,
            fontWeight: 800,
            letterSpacing: "-0.035em",
            color: palette.bone,
            wordBreak: "keep-all",
          }}
        >
          {title}
        </h2>
      </Rise>
    </div>
  </AbsoluteFill>
);

/// 실제 앱 화면을 가장자리까지 채운다. 캡처 위쪽 상태 표시줄은 통신사 자리가 지워져 있어 잘라 낸다.
const FullScreen: React.FC<{ src: string; length: number; zoom?: number }> = ({
  src,
  length,
  zoom = 1.0,
}) => {
  const frame = useCurrentFrame();
  const statusBar = 130;
  const visible = 2622 - statusBar;
  // 잘라 낸 상태 표시줄만큼 세로가 모자라므로 높이에 맞춰 키운다. 폭에 맞추면 위아래에 여백이
  // 생기고, 그 여백을 메우려 이미지를 내리면 지웠던 상태 표시줄이 다시 나온다.
  const scaleToFill = FRAME.height / visible;
  const height = scaleToFill * 2622;
  const width = scaleToFill * 1206;
  const zoomScale = interpolate(frame, [0, length], [zoom, zoom + 0.035]);
  return (
    <AbsoluteFill style={{ overflow: "hidden", background: palette.ink }}>
      <Img
        src={src}
        style={{
          position: "absolute",
          top: -scaleToFill * statusBar,
          left: (FRAME.width - width) / 2,
          width,
          height,
          transform: `scale(${zoomScale})`,
          transformOrigin: "50% 40%",
        }}
      />
    </AbsoluteFill>
  );
};

/// 스토어 갤러리에서 미리보기는 무음으로 자동재생되고, 넘길지 말지는 3초 안에 정해진다.
/// 그 구간을 검은 로고 화면에 쓰면 앱을 보여 줄 기회를 통째로 버리는 셈이라, 제목은 실제
/// 앱 화면 위에 얹고 1.5초만 머문다.
const Opening: React.FC<{ length: number }> = ({ length }) => (
  <Fade length={length}>
    <AbsoluteFill style={{ background: palette.ink }}>
      <FullScreen src={screen("04-decision")} length={length} />
      <AbsoluteFill style={{ background: "rgba(7,12,10,0.74)" }} />
      <StadiumGlow y="44%" strength={0.5} />
      <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", padding: "0 56px" }}>
        <Rise>
          <h1
            style={{
              margin: 0,
              fontFamily: fontStack,
              fontSize: 92,
              fontWeight: 900,
              letterSpacing: "-0.05em",
              lineHeight: 1.1,
              color: palette.bone,
              textAlign: "center",
            }}
          >
            야구 못하면
            <br />
            <span style={{ color: palette.lime }}>또 환생함</span>
          </h1>
        </Rise>
        <Rise delay={16} style={{ marginTop: 30 }}>
          <p
            style={{
              margin: 0,
              fontFamily: fontStack,
              fontSize: 36,
              fontWeight: 600,
              color: palette.muted,
              textAlign: "center",
              wordBreak: "keep-all",
            }}
          >
            한 구가 인생을 바꾸는 투수 육성 게임
          </p>
        </Rise>
      </AbsoluteFill>
    </AbsoluteFill>
  </Fade>
);

/// 승부 장면. 세로 화면에서는 클립을 가운데 크게 놓고 위아래를 어둠으로 남긴다.
/// 한 타석을 통째로 보여 준다. 한 구만 보여 주면 "공 하나 던지는 게임"으로 읽히고,
/// 이 게임의 이야기는 스트라이크를 잡다가 한 구에 무너지는 데 있다.
/// 확대율은 판정 글자 길이에 맞춘다. "루킹 스트라이크"는 "헛스윙"보다 두 배 넓어서
/// 같은 배율로 당기면 양끝이 잘린다.
const PITCHES = [
  { clip: "called-strike", length: 54, zoom: 1.0, focusY: 0.5, eyebrow: "승부처만 직접 던집니다", title: "노린 곳에 꽂히면 스트라이크." },
  { clip: "swinging-strike", length: 54, zoom: 1.28, focusY: 0.14, eyebrow: "구종과 코스가 다릅니다", title: "같은 공도, 던지는 사람이 다릅니다." },
  { clip: "home-run", length: 108, zoom: 1.1, focusY: 0.5, eyebrow: "한 구의 대가", title: null },
] as const;

const Moment: React.FC<{ length: number }> = ({ length }) => {
  // 각 구가 시작하는 프레임. 마지막 구는 남은 시간을 전부 쓴다.
  let cursor = 0;
  const starts = PITCHES.map((pitch) => {
    const from = cursor;
    cursor += pitch.length;
    return from;
  });

  return (
    <Fade length={length}>
      <AbsoluteFill style={{ background: palette.ink }}>
        <StadiumGlow y="38%" strength={0.85} />
        {PITCHES.map((pitch, order) => {
          const isLast = order === PITCHES.length - 1;
          return (
            // 클립마다 Sequence를 따로 준다. 하나로 묶으면 재생 위치가 장면 시작이 아니라
            // 구간 전체 기준으로 흘러서 2구·3구가 중간부터 나온다.
            <Sequence
              key={pitch.clip}
              from={starts[order]}
              durationInFrames={isLast ? length - starts[order] : pitch.length}
            >
              {/* 화면 폭을 꽉 채운다. 테두리 달린 카드로 두면 앞뒤의 전면 화면들과 따로 논다. */}
              <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", paddingTop: 150 }}>
                <DramaClip
                  src={drama(pitch.clip)}
                  height={1044}
                  startFrom={18}
                  zoom={pitch.zoom}
                  focusY={pitch.focusY}
                  bare
                />
              </AbsoluteFill>
              <Caption
                eyebrow={pitch.eyebrow}
                title={
                  pitch.title ?? (
                    <>
                      한 구가 <span style={{ color: palette.rust }}>커리어를 끝내기도</span> 합니다.
                    </>
                  )
                }
              />
            </Sequence>
          );
        })}
      </AbsoluteFill>
    </Fade>
  );
};

const Beat: React.FC<{
  length: number;
  src: string;
  eyebrow: string;
  title: React.ReactNode;
}> = ({ length, src, eyebrow, title }) => (
  <Fade length={length}>
    <FullScreen src={src} length={length} />
    <Caption eyebrow={eyebrow} title={title} />
  </Fade>
);

/// 닫는 화면. 가격도, 스토어로 가라는 말도 넣지 않는다.
const Closing: React.FC<{ length: number }> = ({ length }) => (
  <Fade length={length}>
    <AbsoluteFill style={{ background: palette.ink }}>
      <StadiumGlow y="42%" strength={0.95} />
      <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", padding: "0 56px" }}>
        <Rise>
          <h2
            style={{
              margin: 0,
              fontFamily: fontStack,
              fontSize: 84,
              fontWeight: 900,
              letterSpacing: "-0.05em",
              color: palette.bone,
              textAlign: "center",
              lineHeight: 1.16,
            }}
          >
            이번 생엔,
            <br />
            <span style={{ color: palette.lime }}>이름이 불릴까.</span>
          </h2>
        </Rise>
      </AbsoluteFill>
    </AbsoluteFill>
  </Fade>
);

/// 30fps 기준. 합은 15~30초 안에 들어와야 한다.
export const PREVIEW_BEATS = {
  opening: 46,
  choose: 124,
  moment: 216,
  train: 118,
  school: 100,
  rebirth: 118,
  closing: 66,
} as const;

export const PREVIEW_FRAMES = Object.values(PREVIEW_BEATS).reduce((sum, n) => sum + n, 0);

export const AppPreview: React.FC = () => {
  let cursor = 0;
  const at = (length: number) => {
    const from = cursor;
    cursor += length;
    return { from, durationInFrames: length };
  };

  return (
    <AbsoluteFill style={{ background: palette.ink }}>
      <Sequence {...at(PREVIEW_BEATS.opening)}>
        <Opening length={PREVIEW_BEATS.opening} />
      </Sequence>
      <Sequence {...at(PREVIEW_BEATS.choose)}>
        <Beat
          length={PREVIEW_BEATS.choose}
          src={screen("04-decision")}
          eyebrow="포수의 사인을 읽습니다"
          title="구종과 코스를 직접 고릅니다."
        />
      </Sequence>
      <Sequence {...at(PREVIEW_BEATS.moment)}>
        <Moment length={PREVIEW_BEATS.moment} />
      </Sequence>
      <Sequence {...at(PREVIEW_BEATS.train)}>
        <Beat
          length={PREVIEW_BEATS.train}
          src={screen("08-training")}
          eyebrow="증명할 시간은 3년"
          title="훈련에는 항상 대가가 있습니다."
        />
      </Sequence>
      <Sequence {...at(PREVIEW_BEATS.school)}>
        <Beat
          length={PREVIEW_BEATS.school}
          src={screen("07-school")}
          eyebrow="학교와 사람이 남습니다"
          title="어디서 자랄지가 어떤 투수가 될지를 바꿉니다."
        />
      </Sequence>
      <Sequence {...at(PREVIEW_BEATS.rebirth)}>
        <Beat
          length={PREVIEW_BEATS.rebirth}
          src={screen("03-karma")}
          eyebrow="실패하고, 기억하고, 돌아온다"
          title="지명받지 못하면 다음 선수가 시작됩니다."
        />
      </Sequence>
      <Sequence {...at(PREVIEW_BEATS.closing)}>
        <Closing length={PREVIEW_BEATS.closing} />
      </Sequence>
    </AbsoluteFill>
  );
};
