import React from "react";
import { AbsoluteFill, Audio, Easing, Img, Interactive, interpolate, Sequence, staticFile, useCurrentFrame } from "remotion";
import { fontStack } from "../theme";

const STEPS = [
  ["NOW", "D1 공정 랭킹", "LIFE 01 서버 재생"],
  ["NEXT", "Hive 인증", "클라우드 계보·친구"],
  ["LIVE", "Analytics·LiveOps", "바람·타자·보상 순환"],
  ["CROSS", "모바일 ↔ PC", "동일 시드 크로스플레이"],
] as const;

export const HiveScene: React.FC = () => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill style={{ overflow: "hidden", backgroundColor: "#050807" }}>
      <Img src={staticFile("web/desktop-career.jpg")} style={{ width: "100%", height: "100%", objectFit: "cover", opacity: 0.20, scale: 1.05 }} />
      <AbsoluteFill style={{ background: "linear-gradient(0deg, rgba(5,8,7,0.99), rgba(5,8,7,0.70) 70%, rgba(5,8,7,0.50))" }} />
      <div style={{ position: "absolute", left: 92, right: 92, top: 92 }}>
        <p style={{ margin: 0, color: "#79C9CF", fontFamily: fontStack, fontSize: 25, fontWeight: 900, letterSpacing: "0.14em" }}>RELEASE POTENTIAL · HIVE PATH</p>
        <h2 style={{ margin: "18px 0 0", color: "#EEF0DF", fontFamily: fontStack, fontSize: 84, fontWeight: 950, letterSpacing: "-0.055em", lineHeight: 1.06 }}>
          이미 작동하는 검증 경계 위에<br /><span style={{ color: "#C8F24A" }}>글로벌 시즌</span>을 연결한다.
        </h2>
      </div>
      <Interactive.Div
        name="Hive 출시 단계"
        style={{
          position: "absolute",
          left: 92,
          right: 92,
          bottom: 160,
          display: "grid",
          gridTemplateColumns: "repeat(4, 1fr)",
          gap: 12,
          opacity: interpolate(frame, [18, 38], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.bezier(0.16, 1, 0.3, 1) }),
        }}
      >
        {STEPS.map(([phase, title, detail], index) => (
          <div key={phase} style={{ minHeight: 250, padding: "28px 24px", border: `1px solid ${index === 0 ? "rgba(200,242,74,0.56)" : "rgba(121,201,207,0.34)"}`, backgroundColor: "rgba(5,8,7,0.88)" }}>
            <small style={{ color: index === 0 ? "#C8F24A" : "#79C9CF", fontFamily: fontStack, fontSize: 20, fontWeight: 900, letterSpacing: "0.12em" }}>{phase}</small>
            <strong style={{ display: "block", marginTop: 20, color: "#EEF0DF", fontFamily: fontStack, fontSize: 34, lineHeight: 1.15 }}>{title}</strong>
            <p style={{ margin: "18px 0 0", color: "#A8B1A4", fontFamily: fontStack, fontSize: 24, fontWeight: 700, lineHeight: 1.4 }}>{detail}</p>
          </div>
        ))}
      </Interactive.Div>
      <p style={{ position: "absolute", left: 92, bottom: 92, margin: 0, color: "#7E8980", fontFamily: fontStack, fontSize: 23, fontWeight: 700 }}>
        현재 공개 빌드: 로그인 없는 D1 익명 보드 · Hive 연동은 출시 확장 단계
      </p>
      <Sequence from={12} durationInFrames={70} layout="none"><Audio src={staticFile("sfx/umpire-strike.wav")} volume={0.36} /></Sequence>
    </AbsoluteFill>
  );
};
