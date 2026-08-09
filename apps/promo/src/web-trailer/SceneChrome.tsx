import React from "react";
import { AbsoluteFill, Easing, Img, Interactive, interpolate, staticFile, useCurrentFrame } from "remotion";
import { fontStack, palette } from "../theme";

export const SceneChrome: React.FC<{
  image: string;
  children: React.ReactNode;
  focus?: string;
  shade?: "left" | "bottom" | "even";
}> = ({ image, children, focus = "center", shade = "left" }) => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill style={{ overflow: "hidden", backgroundColor: palette.ink }}>
      <Img
        name="검증된 실제 게임 화면"
        src={staticFile(`web/${image}`)}
        style={{
          width: "100%",
          height: "100%",
          objectFit: "cover",
          objectPosition: focus,
          scale: interpolate(frame, [0, 180], [1.02, 1.08], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            easing: Easing.bezier(0.16, 1, 0.3, 1),
            output: "perceptual-scale",
          }),
        }}
      />
      <AbsoluteFill
        style={{
          background:
            shade === "left"
              ? "linear-gradient(90deg, rgba(5,8,7,0.96) 0%, rgba(5,8,7,0.72) 40%, rgba(5,8,7,0.12) 72%)"
              : shade === "bottom"
                ? "linear-gradient(0deg, rgba(5,8,7,0.96) 0%, rgba(5,8,7,0.38) 48%, rgba(5,8,7,0.08) 78%)"
                : "rgba(5,8,7,0.46)",
        }}
      />
      <AbsoluteFill style={{ background: "radial-gradient(circle at 72% 40%, rgba(200,242,74,0.10), transparent 34%)" }} />
      {children}
    </AbsoluteFill>
  );
};

export const Kicker: React.FC<{ children: React.ReactNode; name?: string }> = ({ children, name = "장면 라벨" }) => {
  const frame = useCurrentFrame();
  return (
    <Interactive.P
      name={name}
      style={{
        margin: 0,
        color: "#C8F24A",
        fontFamily: fontStack,
        fontSize: 25,
        fontWeight: 900,
        letterSpacing: "0.14em",
        opacity: interpolate(frame, [0, 14], [0, 1], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
          easing: Easing.bezier(0.16, 1, 0.3, 1),
        }),
        translate: interpolate(frame, [0, 18], ["0px 18px", "0px 0px"], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
          easing: Easing.bezier(0.16, 1, 0.3, 1),
        }),
      }}
    >
      {children}
    </Interactive.P>
  );
};

export const Headline: React.FC<{ children: React.ReactNode; name?: string; size?: number }> = ({ children, name = "핵심 문장", size = 86 }) => {
  const frame = useCurrentFrame();
  return (
    <Interactive.H2
      name={name}
      style={{
        margin: 0,
        color: "#EEF0DF",
        fontFamily: fontStack,
        fontSize: size,
        fontWeight: 950,
        letterSpacing: "-0.055em",
        lineHeight: 1.08,
        wordBreak: "keep-all",
        opacity: interpolate(frame, [6, 24], [0, 1], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
          easing: Easing.bezier(0.16, 1, 0.3, 1),
        }),
        translate: interpolate(frame, [6, 24], ["0px 32px", "0px 0px"], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
          easing: Easing.bezier(0.16, 1, 0.3, 1),
        }),
      }}
    >
      {children}
    </Interactive.H2>
  );
};

export const BodyCopy: React.FC<{ children: React.ReactNode; name?: string }> = ({ children, name = "설명" }) => {
  const frame = useCurrentFrame();
  return (
    <Interactive.P
      name={name}
      style={{
        margin: 0,
        color: "#A8B1A4",
        fontFamily: fontStack,
        fontSize: 40,
        fontWeight: 650,
        lineHeight: 1.5,
        wordBreak: "keep-all",
        opacity: interpolate(frame, [16, 34], [0, 1], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
          easing: Easing.bezier(0.16, 1, 0.3, 1),
        }),
        translate: interpolate(frame, [16, 34], ["0px 22px", "0px 0px"], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
          easing: Easing.bezier(0.16, 1, 0.3, 1),
        }),
      }}
    >
      {children}
    </Interactive.P>
  );
};

export const PillRow: React.FC<{ items: readonly string[] }> = ({ items }) => {
  const frame = useCurrentFrame();
  return (
    <Interactive.Div
      name="핵심 시스템"
      style={{
        display: "flex",
        flexWrap: "wrap",
        gap: 12,
        opacity: interpolate(frame, [25, 42], [0, 1], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
          easing: Easing.bezier(0.16, 1, 0.3, 1),
        }),
      }}
    >
      {items.map((item) => (
        <span
          key={item}
          style={{
            padding: "13px 18px",
            border: "1px solid rgba(200,242,74,0.42)",
            color: palette.bone,
            backgroundColor: "rgba(7,12,10,0.82)",
            fontFamily: fontStack,
            fontSize: 23,
            fontWeight: 800,
          }}
        >
          {item}
        </span>
      ))}
    </Interactive.Div>
  );
};
