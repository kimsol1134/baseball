import React from "react";
import { AbsoluteFill, Audio, Easing, Img, Interactive, interpolate, Sequence, staticFile, useCurrentFrame } from "remotion";
import { BodyCopy, Headline, Kicker, PillRow } from "./SceneChrome";

const MOBILE_SHOTS = ["mobile-outcome.jpg", "mobile-career.jpg", "mobile-intro.jpg"] as const;

export const RebirthScene: React.FC = () => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill style={{ overflow: "hidden", backgroundColor: "#050807" }}>
      <Sequence from={12} durationInFrames={70} layout="none"><Audio src={staticFile("sfx/bat-contact-hard.wav")} volume={0.48} /></Sequence>
      <AbsoluteFill style={{ background: "radial-gradient(circle at 72% 46%, rgba(200,242,74,0.13), transparent 34%)" }} />
      <div style={{ position: "absolute", left: 92, top: 112, width: 760, display: "flex", flexDirection: "column", gap: 24 }}>
        <Kicker>REBIRTH ROGUELITE</Kicker>
        <Headline>실패는 끝이 아니라<br /><span style={{ color: "#C8F24A" }}>다음 선수의 시작</span>이다.</Headline>
        <BodyCopy>전생에서 기억 하나를 고르고, 야구혼을 써서 전혀 다른 원형의 신인을 다시 육성합니다.</BodyCopy>
        <PillRow items={["8명의 신인", "6종 기억", "야구혼 상점", "유산 3종"]} />
      </div>
      <Interactive.Div
        name="환생 모바일 화면"
        style={{
          position: "absolute",
          right: 82,
          top: 82,
          width: 890,
          height: 920,
          opacity: interpolate(frame, [8, 28], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.bezier(0.16, 1, 0.3, 1) }),
        }}
      >
        {MOBILE_SHOTS.map((shot, index) => (
          <Img
            key={shot}
            name={`환생 화면 ${index + 1}`}
            src={staticFile(`web/${shot}`)}
            style={{
              position: "absolute",
              right: 60 + index * 190,
              top: index === 1 ? 32 : 82,
              width: 340,
              height: 736,
              objectFit: "cover",
              border: "2px solid rgba(238,240,223,0.28)",
              boxShadow: "0 36px 100px rgba(0,0,0,0.66)",
              rotate: `${index === 0 ? 3 : index === 2 ? -3 : 0}deg`,
              translate: interpolate(frame, [8 + index * 6, 30 + index * 6], [`${50 + index * 20}px 0px`, "0px 0px"], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
            }}
          />
        ))}
      </Interactive.Div>
    </AbsoluteFill>
  );
};

