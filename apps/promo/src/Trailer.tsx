import React from "react";
import {
  AbsoluteFill,
  interpolate,
  Sequence,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { DramaClip, Eyebrow, Lead, PhoneScreen, Rise, StadiumGlow, Title } from "./parts";
import { fontStack, palette, type } from "./theme";

const screen = (name: string) => staticFile(`screens/${name}.png`);
const drama = (name: string) => staticFile(`drama/${name}.mp4`);

/// 장면 사이를 검게 끊는다. 크로스 디졸브는 어두운 화면끼리 겹치면 진흙이 된다.
const Cut: React.FC<{ children: React.ReactNode; length: number }> = ({ children, length }) => {
  const frame = useCurrentFrame();
  const fade = Math.min(
    interpolate(frame, [0, 8], [0, 1], { extrapolateRight: "clamp" }),
    interpolate(frame, [length - 8, length], [1, 0], { extrapolateLeft: "clamp" }),
  );
  return <AbsoluteFill style={{ opacity: fade }}>{children}</AbsoluteFill>;
};

/// 1. 제목
const Opening: React.FC<{ length: number }> = ({ length }) => {
  const frame = useCurrentFrame();
  const scale = interpolate(frame, [0, length], [1.04, 1.12]);
  return (
    <Cut length={length}>
      <AbsoluteFill style={{ background: palette.ink }}>
        <StadiumGlow y="42%" strength={0.9} />
        <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", transform: `scale(${scale})` }}>
          <Rise>
            <h1
              style={{
                margin: 0,
                fontFamily: fontStack,
                fontSize: type.display,
                fontWeight: 900,
                letterSpacing: "-0.045em",
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
          <Rise delay={18} style={{ marginTop: 34 }}>
            <p
              style={{
                margin: 0,
                fontFamily: fontStack,
                fontSize: type.lead,
                fontWeight: 600,
                color: palette.muted,
                textAlign: "center",
              }}
            >
              한 구가 인생을 바꾸는 투수 육성 게임
            </p>
          </Rise>
        </AbsoluteFill>
      </AbsoluteFill>
    </Cut>
  );
};

/// 좌우 2단. 왼쪽에 글, 오른쪽에 실제 화면. 영상 내내 이 배치를 지켜 시선이 튀지 않게 한다.
const Beat: React.FC<{
  length: number;
  eyebrow: string;
  title: React.ReactNode;
  lead: string;
  right: React.ReactNode;
  glowX?: string;
}> = ({ length, eyebrow, title, lead, right, glowX = "72%" }) => (
  <Cut length={length}>
    <AbsoluteFill style={{ background: palette.ink }}>
      <StadiumGlow x={glowX} y="46%" strength={0.55} />
      <AbsoluteFill
        style={{
          flexDirection: "row",
          alignItems: "center",
          justifyContent: "center",
          gap: 84,
          padding: "0 96px",
        }}
      >
        <div style={{ flex: "0 0 800px", display: "flex", flexDirection: "column", gap: 26 }}>
          <Rise>
            <Eyebrow>{eyebrow}</Eyebrow>
          </Rise>
          <Rise delay={7}>
            <Title>{title}</Title>
          </Rise>
          <Rise delay={16}>
            <Lead>{lead}</Lead>
          </Rise>
        </div>
        <Rise delay={11} style={{ display: "flex", gap: 40 }}>
          {right}
        </Rise>
      </AbsoluteFill>
    </AbsoluteFill>
  </Cut>
);

/// 3. 승부. 화면 전체를 승부 장면에 내주는 유일한 구간이다.
const TheMoment: React.FC<{ length: number }> = ({ length }) => {
  const frame = useCurrentFrame();
  // 두 구를 잇는다. 헛스윙으로 시작해 홈런으로 끝나야 "내가 던진 공이 결과를 바꾼다"가 읽힌다.
  const swingLength = 108;
  return (
    <Cut length={length}>
      <AbsoluteFill style={{ background: palette.ink }}>
        <StadiumGlow y="38%" strength={0.85} />
        <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", paddingTop: 90 }}>
          <div style={{ transform: `scale(${interpolate(frame, [0, length], [1.0, 1.06])})` }}>
            {/* 앞 0.4초는 공이 점만 하게 멀리 있어 아무 일도 일어나지 않는다. 건너뛴다. */}
            {frame < swingLength ? (
              <DramaClip src={drama("swinging-strike")} height={820} startFrom={24} zoom={1.3} focusY={0.14} />
            ) : (
              <DramaClip src={drama("home-run")} height={820} startFrom={24} zoom={1.1} focusY={0.5} />
            )}
          </div>
        </AbsoluteFill>

        {/* Sequence는 기본으로 AbsoluteFill을 씌운다. 그대로 두면 자막이 화면 위로 올라가
            승부 장면을 가린다. layout="none"으로 바깥 정렬을 그대로 쓴다. */}
        <AbsoluteFill style={{ justifyContent: "flex-start", alignItems: "center", padding: "70px 96px 0" }}>
          <Sequence from={10} durationInFrames={swingLength - 10} layout="none">
            <Rise style={{ textAlign: "center" }}>
              <Title size={60}>같은 공도, 던지는 사람이 다릅니다.</Title>
            </Rise>
          </Sequence>
          <Sequence from={swingLength + 12} layout="none">
            <Rise style={{ textAlign: "center" }}>
              <Title size={60}>
                한 구가 <span style={{ color: palette.rust }}>커리어를 끝내기도</span> 합니다.
              </Title>
            </Rise>
          </Sequence>
        </AbsoluteFill>
      </AbsoluteFill>
    </Cut>
  );
};

/// 6. 마무리. 가격과 "그 뒤로 낼 것이 없다"가 이 게임의 판매 논거다.
const Closing: React.FC<{ length: number }> = ({ length }) => (
  <Cut length={length}>
    <AbsoluteFill style={{ background: palette.ink }}>
      <StadiumGlow y="40%" strength={0.95} />
      <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", gap: 30 }}>
        <Rise>
          <h2
            style={{
              margin: 0,
              fontFamily: fontStack,
              fontSize: 92,
              fontWeight: 900,
              letterSpacing: "-0.045em",
              color: palette.bone,
              textAlign: "center",
              lineHeight: 1.14,
            }}
          >
            이번 생엔,
            <br />
            <span style={{ color: palette.lime }}>이름이 불릴까.</span>
          </h2>
        </Rise>
        <Rise delay={14} style={{ marginTop: 18 }}>
          <div
            style={{
              display: "flex",
              gap: 18,
              fontFamily: fontStack,
              fontSize: type.body,
              fontWeight: 700,
              color: palette.muted,
            }}
          >
            {["iPhone · iOS 17+", "₩3,300 한 번", "광고 없음", "앱 내 구입 없음"].map((item, index, all) => (
              <span key={item} style={{ display: "flex", alignItems: "center", gap: 18 }}>
                {item}
                {/* 마지막 항목 뒤에는 점을 찍지 않는다. */}
                {index < all.length - 1 ? (
                  <i
                    style={{
                      width: 5,
                      height: 5,
                      borderRadius: "50%",
                      background: palette.hairline,
                      display: "inline-block",
                    }}
                  />
                ) : null}
              </span>
            ))}
          </div>
        </Rise>
        <Rise delay={24} style={{ marginTop: 26 }}>
          <div
            style={{
              fontFamily: fontStack,
              fontSize: 34,
              fontWeight: 800,
              color: palette.ink,
              background: palette.lime,
              padding: "22px 46px",
              borderRadius: 999,
            }}
          >
            App Store에서 받기
          </div>
        </Rise>
      </AbsoluteFill>
    </AbsoluteFill>
  </Cut>
);

/// 장면 길이(프레임, 30fps). 합이 Root의 durationInFrames와 같아야 한다.
export const BEATS = {
  opening: 86,
  choose: 140,
  moment: 212,
  grow: 140,
  rebirth: 126,
  closing: 116,
} as const;

export const Trailer: React.FC = () => {
  const { fps } = useVideoConfig();
  let cursor = 0;
  const at = (length: number) => {
    const from = cursor;
    cursor += length;
    return { from, durationInFrames: length };
  };

  return (
    <AbsoluteFill style={{ background: palette.ink }}>
      <Sequence {...at(BEATS.opening)}>
        <Opening length={BEATS.opening} />
      </Sequence>

      <Sequence {...at(BEATS.choose)}>
        <Beat
          length={BEATS.choose}
          eyebrow="승부처만 직접 던집니다"
          title={
            <>
              모든 공을 던지지 않습니다.
              <br />
              바꿀 수 있는 순간만.
            </>
          }
          lead="포수의 사인을 읽고 구종과 코스를 고릅니다. 평범한 경기는 빠르게 흐릅니다."
          right={<PhoneScreen src={screen("04-decision")} height={950} drift={1} />}
        />
      </Sequence>

      <Sequence {...at(BEATS.moment)}>
        <TheMoment length={BEATS.moment} />
      </Sequence>

      <Sequence {...at(BEATS.grow)}>
        <Beat
          length={BEATS.grow}
          eyebrow="증명할 시간은 3년"
          title={
            <>
              매주를 관리하고,
              <br />
              결정적 순간을 바꿉니다.
            </>
          }
          lead="훈련에는 항상 대가가 있습니다. 피로와 약점을 함께 안고 갑니다."
          right={
            <>
              <PhoneScreen src={screen("08-training")} height={880} drift={1} />
              <PhoneScreen src={screen("07-school")} height={800} />
            </>
          }
          glowX="66%"
        />
      </Sequence>

      <Sequence {...at(BEATS.rebirth)}>
        <Beat
          length={BEATS.rebirth}
          eyebrow="실패하고, 기억하고, 돌아온다"
          title={
            <>
              지명받지 못하면,
              <br />
              다음 선수가 시작됩니다.
            </>
          }
          lead="이번 삶의 기억을 골라 다음 생으로 가져갑니다. 성공을 보장하지는 않습니다."
          right={<PhoneScreen src={screen("03-karma")} height={950} drift={1} />}
        />
      </Sequence>

      <Sequence {...at(BEATS.closing)}>
        <Closing length={BEATS.closing} />
      </Sequence>

      {/* fps는 Root에서 30으로 고정한다. 값이 바뀌면 위 프레임 수가 전부 어긋난다. */}
      {fps !== 30 ? null : null}
    </AbsoluteFill>
  );
};

/// 랜딩 히어로에 무음 자동재생으로 걸 짧은 반복. 승부 장면만 남긴다.
export const HeroLoop: React.FC = () => (
  <AbsoluteFill style={{ background: palette.ink }}>
    <StadiumGlow y="40%" strength={0.85} />
    <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", flexDirection: "row", gap: 56 }}>
      <DramaClip src={drama("swinging-strike")} height={820} zoom={1.3} focusY={0.14} />
      <DramaClip src={drama("home-run")} height={820} zoom={1.1} focusY={0.5} />
    </AbsoluteFill>
  </AbsoluteFill>
);
