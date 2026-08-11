import React from "react";
import { AbsoluteFill, Audio, Easing, Img, Interactive, interpolate, Sequence, staticFile, useCurrentFrame } from "remotion";
import { fontStack } from "../theme";

export const HiveScene: React.FC = () => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill style={{ overflow: "hidden", backgroundColor: "#050807" }}>
      <Img src={staticFile("web/desktop-career.jpg")} style={{ width: "100%", height: "100%", objectFit: "cover", opacity: 0.16, scale: 1.08 }} />
      <AbsoluteFill style={{ background: "linear-gradient(0deg, rgba(5,8,7,0.99), rgba(5,8,7,0.76))" }} />
      <div style={{ position: "absolute", left: 92, right: 92, top: 90 }}>
        <p style={{ margin: 0, color: "#79C9CF", fontFamily: fontStack, fontSize: 25, fontWeight: 900, letterSpacing: "0.14em" }}>RELEASE POTENTIAL · HONEST BOUNDARY</p>
        <h2 style={{ margin: "18px 0 0", color: "#EEF0DF", fontFamily: fontStack, fontSize: 80, fontWeight: 950, letterSpacing: "-0.055em", lineHeight: 1.03 }}>
          지금 작동하는 것과<br /><span style={{ color: "#C8F24A" }}>출시 후 연결할 것.</span>
        </h2>
      </div>
      <Interactive.Div name="현재 구현과 Hive 출시 계획" style={{ position: "absolute", left: 92, right: 92, bottom: 108, display: "grid", gridTemplateColumns: "1fr 1fr", gap: 18, opacity: interpolate(frame, [8, 24], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.bezier(0.16, 1, 0.3, 1) }) }}>
        <div style={{ minHeight: 350, padding: "34px", border: "2px solid rgba(200,242,74,0.6)", backgroundColor: "rgba(5,8,7,0.92)" }}>
          <small style={{ color: "#C8F24A", fontFamily: fontStack, fontSize: 21, fontWeight: 900 }}>CURRENT PUBLIC BUILD</small>
          <strong style={{ display: "block", marginTop: 22, color: "#EEF0DF", fontFamily: fontStack, fontSize: 42 }}>서버 재검증 + D1 익명 보드</strong>
          <p style={{ margin: "20px 0 0", color: "#A8B1A4", fontFamily: fontStack, fontSize: 31, fontWeight: 800, lineHeight: 1.35 }}>15회 훈련 + 3관문 투구 전체 재계산</p>
        </div>
        <div style={{ minHeight: 350, padding: "34px", border: "1px solid rgba(121,201,207,0.44)", backgroundColor: "rgba(5,8,7,0.88)" }}>
          <small style={{ color: "#79C9CF", fontFamily: fontStack, fontSize: 21, fontWeight: 900 }}>POST-LAUNCH HIVE INTEGRATION PLAN</small>
          <strong style={{ display: "block", marginTop: 22, color: "#EEF0DF", fontFamily: fontStack, fontSize: 42 }}>인증 · 클라우드 계보 · LiveOps</strong>
          <p style={{ margin: "20px 0 0", color: "#A8B1A4", fontFamily: fontStack, fontSize: 31, fontWeight: 800, lineHeight: 1.35 }}>인증 · 계보 · 시즌 운영을 모바일·PC에 연결</p>
        </div>
      </Interactive.Div>
      <Sequence from={6} durationInFrames={50} layout="none"><Audio src={staticFile("sfx/umpire-strike.wav")} volume={0.34} /></Sequence>
    </AbsoluteFill>
  );
};
