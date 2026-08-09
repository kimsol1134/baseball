import React from "react";
import { AbsoluteFill, Audio, Easing, Img, Interactive, interpolate, Sequence, staticFile, useCurrentFrame } from "remotion";
import { fontStack } from "../theme";

export const ClosingScene: React.FC = () => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill style={{ overflow: "hidden", backgroundColor: "#050807" }}>
      <Sequence from={8} durationInFrames={80} layout="none"><Audio src={staticFile("sfx/glove-catch.wav")} volume={0.7} /></Sequence>
      <AbsoluteFill style={{ background: "radial-gradient(circle at 73% 45%, rgba(121,201,207,0.16), transparent 38%)" }} />
      <div style={{ position: "absolute", right: 80, top: 84, width: 900, height: 900 }}>
        {[1, 2, 3, 4].map((portrait, index) => (
          <Img
            key={portrait}
            name={`신인 투수 ${portrait}`}
            src={staticFile(`portraits/player-${portrait}.jpg`)}
            style={{
              position: "absolute",
              left: index * 185,
              top: index % 2 === 0 ? 0 : 92,
              width: 330,
              height: 760,
              objectFit: "cover",
              objectPosition: "center 20%",
              border: "2px solid rgba(238,240,223,0.20)",
              boxShadow: "0 40px 110px rgba(0,0,0,0.72)",
              opacity: interpolate(frame, [6 + index * 5, 26 + index * 5], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
              translate: interpolate(frame, [6 + index * 5, 26 + index * 5], [`${35 + index * 8}px 0px`, "0px 0px"], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
            }}
          />
        ))}
      </div>
      <AbsoluteFill style={{ background: "linear-gradient(90deg, #050807 0%, rgba(5,8,7,0.95) 43%, rgba(5,8,7,0.05) 72%)" }} />
      <Interactive.Div
        name="최종 타이틀"
        style={{
          position: "absolute",
          left: 92,
          top: 150,
          width: 850,
          opacity: interpolate(frame, [8, 30], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.bezier(0.16, 1, 0.3, 1) }),
          translate: interpolate(frame, [8, 30], ["0px 34px", "0px 0px"], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.bezier(0.16, 1, 0.3, 1) }),
        }}
      >
        <p style={{ margin: 0, color: "#C8F24A", fontFamily: fontStack, fontSize: 25, fontWeight: 900, letterSpacing: "0.14em" }}>PLAY THE FULL CAREER</p>
        <h2 style={{ margin: "20px 0 22px", color: "#EEF0DF", fontFamily: fontStack, fontSize: 104, fontWeight: 950, letterSpacing: "-0.065em", lineHeight: 1.02 }}>야구 못하면<br /><span style={{ color: "#C8F24A" }}>또 환생함</span></h2>
        <p style={{ margin: 0, color: "#A8B1A4", fontFamily: fontStack, fontSize: 44, fontWeight: 700, lineHeight: 1.45 }}>세 관문을 통과하고,<br />당신만의 투수 계보를 남기세요.</p>
        <div style={{ display: "inline-flex", marginTop: 34, padding: "18px 24px", color: "#050807", backgroundColor: "#C8F24A", fontFamily: fontStack, fontSize: 34, fontWeight: 950 }}>지금 웹에서 무료 플레이</div>
        <p style={{ margin: "22px 0 0", color: "#EEF0DF", fontFamily: fontStack, fontSize: 30, fontWeight: 750, lineHeight: 1.25 }}>baseball-rebirth-last-pitch.<br />kimsol1134.chatgpt.site</p>
      </Interactive.Div>
    </AbsoluteFill>
  );
};
