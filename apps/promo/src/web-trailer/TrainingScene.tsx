import React from "react";
import { Audio, Easing, Img, Interactive, interpolate, Sequence, staticFile, useCurrentFrame } from "remotion";
import { Headline, Kicker, SceneChrome } from "./SceneChrome";
import { fontStack } from "../theme";

export const TrainingScene: React.FC = () => {
  const frame = useCurrentFrame();
  return (
    <SceneChrome image="desktop-training.jpg" focus="center" shade="even">
      <Sequence from={18} durationInFrames={60} layout="none">
        <Audio src={staticFile("sfx/glove-catch.wav")} volume={0.5} />
      </Sequence>
      <div style={{ position: "absolute", left: 92, top: 90, width: 790, display: "flex", flexDirection: "column", gap: 18 }}>
        <Kicker>15 TRAINING DECISIONS</Kicker>
        <Headline size={76}>훈련 순서가<br /><span style={{ color: "#C8F24A" }}>투수의 정체성</span>을 만든다.</Headline>
      </div>
      <Interactive.Div
        name="육성 증거 카드"
        style={{
          position: "absolute",
          right: 90,
          bottom: 84,
          width: 700,
          display: "grid",
          gridTemplateColumns: "repeat(3, 1fr)",
          gap: 10,
          padding: 18,
          border: "1px solid rgba(200,242,74,0.44)",
          backgroundColor: "rgba(5,8,7,0.88)",
          opacity: interpolate(frame, [28, 50], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
          translate: interpolate(frame, [28, 50], ["28px 0px", "0px 0px"], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
        }}
      >
        {["반복 숙련", "연계 해금", "피치 설계"].map((item, index) => (
          <div key={item} style={{ padding: "18px 16px", border: "1px solid rgba(255,255,255,0.12)" }}>
            <small style={{ color: "#E9AC4A", fontFamily: fontStack, fontSize: 18, fontWeight: 900 }}>0{index + 1}</small>
            <strong style={{ display: "block", marginTop: 10, color: "#EEF0DF", fontFamily: fontStack, fontSize: 28 }}>{item}</strong>
          </div>
        ))}
      </Interactive.Div>
      <Img
        name="모바일 육성 화면"
        src={staticFile("web/mobile-training.jpg")}
        style={{
          position: "absolute",
          right: 92,
          top: 80,
          width: 300,
          height: 650,
          objectFit: "cover",
          border: "2px solid rgba(200,242,74,0.55)",
          boxShadow: "0 30px 90px rgba(0,0,0,0.62)",
          opacity: interpolate(frame, [8, 28], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
          translate: interpolate(frame, [8, 28], ["44px 0px", "0px 0px"], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
        }}
      />
    </SceneChrome>
  );
};

