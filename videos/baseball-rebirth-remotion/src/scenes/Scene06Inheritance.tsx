import { Audio } from "@remotion/media";
import { AbsoluteFill, Easing, Interactive, interpolate, staticFile, useCurrentFrame } from "remotion";
import { Capture, COLORS, MonoLabel, SafeFrame } from "./shared";

const KEEP = ["누적 능력치", "선택한 기억", "숙련한 유산"] as const;
const REBUILD = ["5일 훈련 순서", "스카우트 공약", "피치 디자인"] as const;

export const Scene06Inheritance: React.FC = () => {
  const frame = useCurrentFrame();
  const planPhase = interpolate(frame, [78, 96], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const branchPhase = interpolate(frame, [150, 168], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });

  return (
    <AbsoluteFill style={{ backgroundColor: COLORS.ink }}>
      <Capture name="Inherited growth in a new life" src="game/13-growth-inherited.png" style={{ opacity: 1 - planPhase, filter: "brightness(0.6)" }} />
      <Capture name="A new power blueprint" src="game/14-next-blueprint.png" style={{ opacity: planPhase * (1 - branchPhase), filter: "brightness(0.58)" }} />
      <Capture name="A new power pitch lab branch" src="game/15-power-pitch-lab.png" style={{ opacity: branchPhase, filter: "brightness(0.59)" }} />
      <AbsoluteFill style={{ backgroundImage: "linear-gradient(90deg, rgba(3,6,5,0.97) 0 49%, rgba(3,6,5,0.42) 69%, rgba(3,6,5,0.14) 100%)" }} />

      <SafeFrame>
        <Interactive.Div
          name="Inheritance headline"
          style={{
            width: 850,
            opacity: interpolate(frame, [8, 28], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.bezier(0.16, 1, 0.3, 1) }),
          }}
        >
          <MonoLabel>NEW LIFE · SAME PLAYER · NEW BUILD</MonoLabel>
          <div style={{ marginTop: 22, fontSize: 78, fontWeight: 950, lineHeight: 1.04, letterSpacing: "-0.06em" }}>
            성장과 기억은 남고,
            <br /><span style={{ color: COLORS.acid }}>이번 주는 다시 설계한다.</span>
          </div>
        </Interactive.Div>

        <div style={{ position: "absolute", top: 400, left: 100, display: "grid", gridTemplateColumns: "360px 360px", gap: 16 }}>
          <Interactive.Div
            name="Persistent growth list"
            style={{
              padding: "22px 24px",
              borderTop: `5px solid ${COLORS.acid}`,
              backgroundColor: "rgba(7,11,10,0.9)",
              opacity: interpolate(frame, [34, 54], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
            }}
          >
            <span style={{ color: COLORS.acid, fontFamily: 'ui-monospace, "SFMono-Regular", Menlo, monospace', fontSize: 20, fontWeight: 950 }}>KEEP</span>
            {KEEP.map((item) => <strong key={item} style={{ display: "block", marginTop: 10, color: COLORS.paper, fontSize: 26 }}>✓ {item}</strong>)}
          </Interactive.Div>
          <Interactive.Div
            name="Weekly rebuild list"
            style={{
              padding: "22px 24px",
              borderTop: `5px solid ${COLORS.blue}`,
              backgroundColor: "rgba(7,11,10,0.9)",
              opacity: interpolate(frame, [54, 74], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
            }}
          >
            <span style={{ color: COLORS.blue, fontFamily: 'ui-monospace, "SFMono-Regular", Menlo, monospace', fontSize: 20, fontWeight: 950 }}>REBUILD</span>
            {REBUILD.map((item) => <strong key={item} style={{ display: "block", marginTop: 10, color: COLORS.paper, fontSize: 26 }}>↻ {item}</strong>)}
          </Interactive.Div>
        </div>

        <Interactive.Div
          name="Different pitcher identity"
          style={{
            position: "absolute",
            right: 100,
            bottom: 88,
            padding: "18px 24px",
            border: `2px solid ${COLORS.acid}`,
            backgroundColor: "rgba(7,11,10,0.92)",
            color: COLORS.paper,
            fontSize: 28,
            fontWeight: 900,
            opacity: interpolate(frame, [170, 194], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.bezier(0.16, 1, 0.3, 1) }),
          }}
        >
          코너 장인 <b style={{ color: COLORS.acid }}>→</b> 압도형 에이스 <b style={{ color: COLORS.blue }}>→</b> 두 가지 새 설계
        </Interactive.Div>
      </SafeFrame>
      <Audio src={staticFile("audio/chime.mp3")} from={18} volume={0.2} />
      <Audio src={staticFile("audio/whoosh-short.mp3")} from={82} volume={0.28} />
      <Audio src={staticFile("audio/click-soft.mp3")} from={112} volume={0.24} />
      <Audio src={staticFile("audio/whoosh-cinematic.mp3")} from={154} volume={0.17} />
      <Audio src={staticFile("audio/ping.mp3")} from={190} volume={0.22} />
    </AbsoluteFill>
  );
};
