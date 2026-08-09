import type { CSSProperties, ReactNode } from "react";
import { AbsoluteFill, CanvasImage, staticFile } from "remotion";

export const COLORS = {
  ink: "#070a09",
  panel: "rgba(7, 11, 10, 0.88)",
  paper: "#eef0df",
  muted: "#a5ac9d",
  dim: "#71796e",
  acid: "#c8f24a",
  red: "#ff685c",
  blue: "#79c9cf",
  line: "rgba(225, 234, 207, 0.24)",
} as const;

export const Capture: React.FC<{
  src: string;
  name: string;
  style?: CSSProperties;
}> = ({ src, name, style }) => {
  return (
    <CanvasImage
      name={name}
      src={staticFile(src)}
      width={1920}
      height={1080}
      style={{
        position: "absolute",
        inset: 0,
        width: 1920,
        height: 1080,
        objectFit: "cover",
        ...style,
      }}
    />
  );
};

export const DarkVeil: React.FC<{ opacity?: number }> = ({ opacity = 0.4 }) => (
  <AbsoluteFill
    style={{
      backgroundColor: `rgba(3, 6, 5, ${opacity})`,
      backgroundImage:
        "linear-gradient(90deg, rgba(3,6,5,0.94) 0%, rgba(3,6,5,0.28) 62%, rgba(3,6,5,0.62) 100%)",
    }}
  />
);

export const FrameGrid: React.FC = () => (
  <AbsoluteFill
    style={{
      opacity: 0.12,
      backgroundImage:
        "linear-gradient(rgba(238,240,223,0.08) 1px, transparent 1px), linear-gradient(90deg, rgba(238,240,223,0.08) 1px, transparent 1px)",
      backgroundSize: "80px 80px",
      maskImage: "linear-gradient(90deg, black, transparent 72%)",
    }}
  />
);

export const SafeFrame: React.FC<{ children: ReactNode }> = ({ children }) => (
  <AbsoluteFill
    style={{
      padding: "100px 100px",
      color: COLORS.paper,
      fontFamily: '"Apple SD Gothic Neo", "Noto Sans KR", sans-serif',
    }}
  >
    {children}
  </AbsoluteFill>
);

export const MonoLabel: React.FC<{ children: ReactNode; tone?: "acid" | "muted" | "red" }> = ({
  children,
  tone = "acid",
}) => (
  <div
    style={{
      color: tone === "acid" ? COLORS.acid : tone === "red" ? COLORS.red : COLORS.muted,
      fontFamily: 'ui-monospace, "SFMono-Regular", Menlo, monospace',
      fontSize: 24,
      fontWeight: 900,
      letterSpacing: "0.14em",
      textTransform: "uppercase",
    }}
  >
    {children}
  </div>
);

export const AccentRule: React.FC<{ width?: number; tone?: "acid" | "red" | "blue" }> = ({
  width = 150,
  tone = "acid",
}) => (
  <div
    style={{
      width,
      height: 5,
      marginTop: 24,
      backgroundColor: tone === "acid" ? COLORS.acid : tone === "red" ? COLORS.red : COLORS.blue,
    }}
  />
);

export const BottomProof: React.FC<{ left: string; right: string }> = ({ left, right }) => (
  <div
    style={{
      position: "absolute",
      right: 100,
      bottom: 76,
      left: 100,
      display: "flex",
      alignItems: "center",
      justifyContent: "space-between",
      paddingTop: 20,
      borderTop: `1px solid ${COLORS.line}`,
      color: COLORS.muted,
      fontFamily: 'ui-monospace, "SFMono-Regular", Menlo, monospace',
      fontSize: 20,
      fontWeight: 800,
      letterSpacing: "0.08em",
    }}
  >
    <span>{left}</span>
    <strong style={{ color: COLORS.acid }}>{right}</strong>
  </div>
);
