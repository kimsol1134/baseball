import React from "react";
import { Audio, AbsoluteFill, Easing, Interactive, interpolate, Sequence, staticFile, useCurrentFrame } from "remotion";
import { Video } from "@remotion/media";
import { fontStack } from "../theme";

export const CaptureFrame: React.FC<{
  video: string;
  kicker: string;
  title: string;
  detail: string;
  sound?: string;
  cropScale?: number;
  cropOrigin?: string;
}> = ({ video, kicker, title, detail, sound = "glove-catch.wav", cropScale = 1.25, cropOrigin = "center center" }) => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill style={{ overflow: "hidden", backgroundColor: "#050807" }}>
      <AbsoluteFill style={{ background: "radial-gradient(circle at 50% 42%, rgba(200,242,74,0.12), transparent 54%)" }} />
      <Interactive.Div
        name="실제 공개 빌드 녹화"
        style={{
          position: "absolute",
          left: 100,
          top: 90,
          width: 1720,
          height: 940,
          overflow: "hidden",
          border: "1px solid rgba(200,242,74,0.36)",
          boxShadow: "0 42px 120px rgba(0,0,0,0.72)",
          opacity: interpolate(frame, [0, 16], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
          scale: interpolate(frame, [0, 18], [0.985, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            easing: Easing.bezier(0.16, 1, 0.3, 1),
            output: "perceptual-scale",
          }),
        }}
      >
        <Video
          src={staticFile(`web-capture/${video}`)}
          volume={0}
          style={{ width: "100%", height: "100%", objectFit: "cover", scale: cropScale, transformOrigin: cropOrigin }}
        />
      </Interactive.Div>
      <Interactive.Div
        name="실제 플레이 라벨"
        style={{
          position: "absolute",
          left: 92,
          right: 92,
          top: 26,
          display: "flex",
          alignItems: "baseline",
          justifyContent: "space-between",
          gap: 40,
          opacity: interpolate(frame, [4, 20], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
        }}
      >
        <div style={{ display: "flex", alignItems: "baseline", gap: 22 }}>
          <strong style={{ color: "#C8F24A", fontFamily: fontStack, fontSize: 25, letterSpacing: "0.14em" }}>{kicker}</strong>
          <span style={{ color: "#EEF0DF", fontFamily: fontStack, fontSize: 38, fontWeight: 950 }}>{title}</span>
        </div>
        <span style={{ color: "#A8B1A4", fontFamily: fontStack, fontSize: 24, fontWeight: 750 }}>{detail}</span>
      </Interactive.Div>
      <Sequence from={10} durationInFrames={70} layout="none">
        <Audio src={staticFile(`sfx/${sound}`)} volume={0.48} />
      </Sequence>
    </AbsoluteFill>
  );
};
