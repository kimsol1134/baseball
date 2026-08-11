import React from "react";
import { AbsoluteFill, Audio, Easing, Img, Interactive, interpolate, Sequence, staticFile, useCurrentFrame } from "remotion";
import { fontStack } from "../theme";

const CRITIQUES = [
  ["처음 온 플레이어", "실패 뒤 다시 할 이유가 없다", "기억·야구혼·환생 계보"],
  ["게임 디자이너", "육성과 투구가 따로 논다", "15회 선택이 릴리스·공의 질 변화"],
  ["상대 타자", "같은 구종 반복이 정답이다", "타자 적응과 수싸움"],
] as const;

export const CodexScene: React.FC = () => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill style={{ overflow: "hidden", backgroundColor: "#050807" }}>
      <Img src={staticFile("web/desktop-pitch.jpg")} style={{ width: "100%", height: "100%", objectFit: "cover", opacity: 0.14, scale: 1.08 }} />
      <AbsoluteFill style={{ background: "linear-gradient(90deg, rgba(5,8,7,0.99), rgba(5,8,7,0.82) 68%, rgba(5,8,7,0.62))" }} />
      <div style={{ position: "absolute", left: 92, right: 92, top: 68 }}>
        <p style={{ margin: 0, color: "#C8F24A", fontFamily: fontStack, fontSize: 23, fontWeight: 900, letterSpacing: "0.14em" }}>CODEX AS A ROLE-SWITCHING CO-CREATOR</p>
        <h2 style={{ margin: "15px 0 0", color: "#EEF0DF", fontFamily: fontStack, fontSize: 72, fontWeight: 950, letterSpacing: "-0.055em", lineHeight: 1.03 }}>
          같은 빌드를 세 관점으로 공격하고,<br /><span style={{ color: "#C8F24A" }}>비판을 게임의 규칙으로 바꿨다.</span>
        </h2>
      </div>
      <Interactive.Div
        name="Codex 비판과 실제 변경"
        style={{
          position: "absolute",
          left: 92,
          right: 92,
          top: 292,
          display: "grid",
          gridTemplateColumns: "repeat(3, 1fr)",
          gap: 14,
        }}
      >
        {CRITIQUES.map(([role, critique, change], index) => {
          const start = 10 + index * 10;
          return (
            <div key={role} style={{ minHeight: 420, padding: "28px 26px", border: "1px solid rgba(238,240,223,0.18)", backgroundColor: "rgba(5,8,7,0.91)", opacity: interpolate(frame, [start, start + 18], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.bezier(0.16, 1, 0.3, 1) }), translate: interpolate(frame, [start, start + 18], ["0px 28px", "0px 0px"], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }) }}>
              <small style={{ color: "#79C9CF", fontFamily: fontStack, fontSize: 18, fontWeight: 900, letterSpacing: "0.09em" }}>ROLE 0{index + 1} · {role}</small>
              <strong style={{ display: "block", minHeight: 112, marginTop: 24, color: "#EEF0DF", fontFamily: fontStack, fontSize: 32, lineHeight: 1.35 }}>“{critique}”</strong>
              <div style={{ width: 44, height: 4, margin: "22px 0", backgroundColor: "#C8F24A" }} />
              <span style={{ color: "#E9AC4A", fontFamily: fontStack, fontSize: 17, fontWeight: 900 }}>CHANGED IN THE BUILD</span>
              <p style={{ margin: "13px 0 0", color: "#C8F24A", fontFamily: fontStack, fontSize: 29, fontWeight: 900, lineHeight: 1.35 }}>{change}</p>
            </div>
          );
        })}
      </Interactive.Div>
      <div style={{ position: "absolute", left: 92, right: 92, bottom: 64, display: "flex", justifyContent: "space-between", padding: "18px 22px", border: "1px solid rgba(200,242,74,0.4)", backgroundColor: "rgba(200,242,74,0.08)", color: "#EEF0DF", fontFamily: fontStack }}>
        <strong style={{ fontSize: 27 }}>60개 자동 검증 + 데스크톱·모바일 실플레이</strong>
        <span style={{ color: "#A8B1A4", fontSize: 23, fontWeight: 750 }}>말로 토론 → 즉시 구현 → 직접 플레이 → 다시 비판</span>
      </div>
      <Sequence from={8} durationInFrames={60} layout="none"><Audio src={staticFile("sfx/glove-catch.wav")} volume={0.4} /></Sequence>
      <Sequence from={44} durationInFrames={60} layout="none"><Audio src={staticFile("sfx/umpire-strike.wav")} volume={0.26} /></Sequence>
    </AbsoluteFill>
  );
};
