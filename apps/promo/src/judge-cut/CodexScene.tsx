import React from "react";
import { AbsoluteFill, Audio, Easing, Img, Interactive, interpolate, Sequence, staticFile, useCurrentFrame } from "remotion";
import { fontStack } from "../theme";

const PROOFS = [
  ["59", "자동 테스트"],
  ["15 + 3", "훈련·경기 서버 재생"],
  ["2 VIEWPORTS", "데스크톱·모바일 E2E"],
  ["0", "실존 구단 직접 표기"],
] as const;

export const CodexScene: React.FC = () => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill style={{ overflow: "hidden", backgroundColor: "#050807" }}>
      <Img src={staticFile("web/desktop-pitch.jpg")} style={{ width: "100%", height: "100%", objectFit: "cover", opacity: 0.18, scale: 1.04 }} />
      <AbsoluteFill style={{ background: "linear-gradient(90deg, rgba(5,8,7,0.98), rgba(5,8,7,0.80) 64%, rgba(5,8,7,0.54))" }} />
      <div style={{ position: "absolute", left: 92, right: 92, top: 92 }}>
        <p style={{ margin: 0, color: "#C8F24A", fontFamily: fontStack, fontSize: 25, fontWeight: 900, letterSpacing: "0.14em" }}>CODEX COLLABORATION</p>
        <h2 style={{ margin: "18px 0 0", color: "#EEF0DF", fontFamily: fontStack, fontSize: 86, fontWeight: 950, letterSpacing: "-0.055em", lineHeight: 1.06 }}>
          아이디어에서 <span style={{ color: "#C8F24A" }}>검증 가능한 게임</span>까지.
        </h2>
      </div>
      <Interactive.Div
        name="Codex 구현 파이프라인"
        style={{
          position: "absolute",
          left: 92,
          right: 92,
          top: 330,
          display: "grid",
          gridTemplateColumns: "repeat(5, 1fr)",
          gap: 12,
          opacity: interpolate(frame, [12, 32], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.bezier(0.16, 1, 0.3, 1) }),
          translate: interpolate(frame, [12, 32], ["0px 22px", "0px 0px"], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
        }}
      >
        {["GAME LOOP", "PURE ENGINES", "WEB UI", "SERVER REPLAY", "REMOTION"].map((item, index) => (
          <div key={item} style={{ padding: "24px 20px", border: "1px solid rgba(200,242,74,0.32)", backgroundColor: "rgba(5,8,7,0.86)" }}>
            <small style={{ color: "#E9AC4A", fontFamily: fontStack, fontSize: 18, fontWeight: 900 }}>0{index + 1}</small>
            <strong style={{ display: "block", marginTop: 14, color: "#EEF0DF", fontFamily: fontStack, fontSize: 26 }}>{item}</strong>
          </div>
        ))}
      </Interactive.Div>
      <Interactive.Div
        name="검증 수치"
        style={{
          position: "absolute",
          left: 92,
          right: 92,
          bottom: 92,
          display: "grid",
          gridTemplateColumns: "repeat(4, 1fr)",
          gap: 12,
          opacity: interpolate(frame, [32, 52], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
        }}
      >
        {PROOFS.map(([value, label]) => (
          <div key={label} style={{ minHeight: 190, padding: "26px 24px", border: "1px solid rgba(238,240,223,0.18)", backgroundColor: "rgba(255,255,255,0.035)" }}>
            <strong style={{ display: "block", color: "#C8F24A", fontFamily: fontStack, fontSize: 54, fontWeight: 950 }}>{value}</strong>
            <span style={{ display: "block", marginTop: 14, color: "#A8B1A4", fontFamily: fontStack, fontSize: 26, fontWeight: 750 }}>{label}</span>
          </div>
        ))}
      </Interactive.Div>
      <Sequence from={14} durationInFrames={70} layout="none"><Audio src={staticFile("sfx/glove-catch.wav")} volume={0.42} /></Sequence>
    </AbsoluteFill>
  );
};
