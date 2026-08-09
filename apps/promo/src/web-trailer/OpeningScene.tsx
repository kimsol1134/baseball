import React from "react";
import { Audio, Interactive, Sequence, staticFile, useCurrentFrame, Easing, interpolate } from "remotion";
import { SceneChrome } from "./SceneChrome";
import { fontStack } from "../theme";

export const OpeningScene: React.FC = () => {
  const frame = useCurrentFrame();
  return (
    <SceneChrome image="desktop-intro.jpg" shade="bottom">
      <Sequence from={4} durationInFrames={60} layout="none">
        <Audio src={staticFile("sfx/glove-catch.wav")} volume={0.65} />
      </Sequence>
      <Interactive.Div
        name="오프닝 증명 문구"
        style={{
          position: "absolute",
          left: 92,
          right: 92,
          bottom: 94,
          display: "flex",
          alignItems: "flex-end",
          justifyContent: "space-between",
          gap: 52,
          opacity: interpolate(frame, [8, 28], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
          translate: interpolate(frame, [8, 28], ["0px 30px", "0px 0px"], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
        }}
      >
        <div>
          <p style={{ margin: "0 0 11px", color: "#C8F24A", fontFamily: fontStack, fontSize: 25, fontWeight: 900, letterSpacing: "0.14em" }}>ACTUAL WEB GAMEPLAY</p>
          <h1 style={{ margin: 0, color: "#EEF0DF", fontFamily: fontStack, fontSize: 72, fontWeight: 950, letterSpacing: "-0.055em" }}>키운 만큼 마지막 한 구가 달라진다.</h1>
        </div>
        <strong style={{ color: "#050807", backgroundColor: "#C8F24A", padding: "17px 22px", fontFamily: fontStack, fontSize: 25, fontWeight: 950, whiteSpace: "nowrap" }}>투수 육성 로그라이트</strong>
      </Interactive.Div>
    </SceneChrome>
  );
};

