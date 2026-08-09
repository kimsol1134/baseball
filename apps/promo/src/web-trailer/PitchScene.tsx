import React from "react";
import { Audio, Easing, Interactive, interpolate, Sequence, staticFile, useCurrentFrame } from "remotion";
import { SceneChrome } from "./SceneChrome";
import { fontStack } from "../theme";

export const PitchScene: React.FC = () => {
  const frame = useCurrentFrame();
  return (
    <SceneChrome image="desktop-pitch.jpg" focus="center" shade="bottom">
      <Sequence from={22} durationInFrames={90} layout="none"><Audio src={staticFile("sfx/swing-miss.wav")} volume={0.68} /></Sequence>
      <Sequence from={54} durationInFrames={100} layout="none"><Audio src={staticFile("sfx/umpire-strikeout.wav")} volume={0.64} /></Sequence>
      <Interactive.Div
        name="투구 3단계"
        style={{
          position: "absolute",
          left: 92,
          right: 92,
          bottom: 82,
          display: "grid",
          gridTemplateColumns: "repeat(3, 1fr)",
          gap: 12,
          opacity: interpolate(frame, [12, 30], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
        }}
      >
        {[
          ["01", "읽고", "타자의 노림"],
          ["02", "고르고", "구종과 코스"],
          ["03", "놓는다", "릴리스 타이밍"],
        ].map(([number, verb, detail]) => (
          <div key={number} style={{ display: "grid", gridTemplateColumns: "64px 1fr", alignItems: "center", gap: 16, padding: "19px 22px", border: "1px solid rgba(200,242,74,0.40)", backgroundColor: "rgba(5,8,7,0.90)" }}>
            <b style={{ color: "#C8F24A", fontFamily: fontStack, fontSize: 28 }}>{number}</b>
            <div><strong style={{ display: "block", color: "#EEF0DF", fontFamily: fontStack, fontSize: 38 }}>{verb}</strong><small style={{ color: "#A8B1A4", fontFamily: fontStack, fontSize: 21 }}>{detail}</small></div>
          </div>
        ))}
      </Interactive.Div>
    </SceneChrome>
  );
};

