import React from "react";
import { AbsoluteFill, Audio, Easing, Interactive, interpolate, Sequence, staticFile, useCurrentFrame } from "remotion";
import { Video } from "@remotion/media";
import { fontStack } from "../theme";

const ProofClip: React.FC<{ src: string; trimBefore: number; label: string; scale?: number; origin?: string }> = ({ src, trimBefore, label, scale = 1.3, origin = "center 58%" }) => (
  <AbsoluteFill style={{ overflow: "hidden", backgroundColor: "#050807" }}>
    <Video src={staticFile(`web-capture/${src}`)} trimBefore={trimBefore} volume={0} style={{ width: "100%", height: "100%", objectFit: "cover", scale, transformOrigin: origin }} />
    <div style={{ position: "absolute", top: 44, left: 52, padding: "12px 16px", color: "#050807", backgroundColor: "#C8F24A", fontFamily: fontStack, fontSize: 22, fontWeight: 950 }}>{label}</div>
  </AbsoluteFill>
);

export const PayoffHookScene: React.FC = () => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill style={{ overflow: "hidden", backgroundColor: "#050807" }}>
      <Sequence from={0} durationInFrames={48}><ProofClip src="fast-route.webm" trimBefore={180} label="초록 릴리스" /></Sequence>
      <Sequence from={48} durationInFrames={38}><ProofClip src="fast-route.webm" trimBefore={218} label="빌드가 바꾼 결과" /></Sequence>
      <Sequence from={86} durationInFrames={32}><ProofClip src="rebirth.webm" trimBefore={28} label="세 관문 뒤 지명" scale={1.24} origin="center 46%" /></Sequence>
      <Sequence from={118} durationInFrames={32}><ProofClip src="rebirth.webm" trimBefore={150} label="LIFE 02 환생" scale={1.24} origin="center 54%" /></Sequence>
      <AbsoluteFill style={{ background: "linear-gradient(0deg, rgba(5,8,7,0.96), transparent 58%)" }} />
      <Interactive.Div name="첫 5초 역순 훅" style={{ position: "absolute", left: 76, right: 76, bottom: 62, opacity: interpolate(frame, [4, 16], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.bezier(0.16, 1, 0.3, 1) }) }}>
        <p style={{ margin: 0, color: "#C8F24A", fontFamily: fontStack, fontSize: 24, fontWeight: 900, letterSpacing: "0.13em" }}>ACTUAL PUBLIC BUILD · PAYOFF FIRST</p>
        <h1 style={{ margin: "12px 0 0", color: "#EEF0DF", fontFamily: fontStack, fontSize: 76, fontWeight: 950, lineHeight: 1.02, letterSpacing: "-0.06em" }}>이 결과를 <span style={{ color: "#C8F24A" }}>15번의 육성 선택</span>으로 만든다.</h1>
      </Interactive.Div>
      <Sequence from={2} durationInFrames={45} layout="none"><Audio src={staticFile("sfx/glove-catch.wav")} volume={0.66} /></Sequence>
      <Sequence from={48} durationInFrames={42} layout="none"><Audio src={staticFile("sfx/umpire-strikeout.wav")} volume={0.58} /></Sequence>
      <Sequence from={88} durationInFrames={38} layout="none"><Audio src={staticFile("sfx/bat-contact-hard.wav")} volume={0.46} /></Sequence>
      <Sequence from={120} durationInFrames={30} layout="none"><Audio src={staticFile("sfx/glove-catch.wav")} volume={0.5} /></Sequence>
    </AbsoluteFill>
  );
};
