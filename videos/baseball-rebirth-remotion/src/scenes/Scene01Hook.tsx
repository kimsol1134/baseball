import { Audio } from "@remotion/media";
import { AbsoluteFill, Easing, Interactive, interpolate, staticFile, useCurrentFrame } from "remotion";
import { AccentRule, BottomProof, Capture, COLORS, DarkVeil, FrameGrid, MonoLabel, SafeFrame } from "./shared";

export const Scene01Hook: React.FC = () => {
  const frame = useCurrentFrame();

  return (
    <AbsoluteFill style={{ backgroundColor: COLORS.ink }}>
      <Capture
        name="Completed five-day development build"
        src="game/09-training-complete.png"
        style={{
          scale: interpolate(frame, [0, 165], [1.14, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            easing: Easing.bezier(0.16, 1, 0.3, 1),
            output: "perceptual-scale",
          }),
          filter: "saturate(0.78) brightness(0.6)",
        }}
      />
      <DarkVeil opacity={0.26} />
      <FrameGrid />
      <SafeFrame>
        <Interactive.Div
          name="Development-first kicker"
          style={{
            opacity: interpolate(frame, [6, 24], [0, 1], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
              easing: Easing.bezier(0.16, 1, 0.3, 1),
            }),
            translate: interpolate(frame, [6, 24], ["0px 18px", "0px 0px"], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
              easing: Easing.bezier(0.16, 1, 0.3, 1),
            }),
          }}
        >
          <MonoLabel>PLAYER DEVELOPMENT ROGUELITE · FIVE DAYS</MonoLabel>
        </Interactive.Div>

        <Interactive.Div
          name="Development-first headline"
          style={{
            width: 1120,
            marginTop: 30,
            color: COLORS.paper,
            fontSize: 94,
            fontWeight: 950,
            lineHeight: 1.01,
            letterSpacing: "-0.065em",
            opacity: interpolate(frame, [20, 50], [0, 1], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
              easing: Easing.bezier(0.16, 1, 0.3, 1),
            }),
            translate: interpolate(frame, [20, 50], ["0px 42px", "0px 0px"], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
              easing: Easing.bezier(0.16, 1, 0.3, 1),
            }),
          }}
        >
          마지막 3구보다,
          <br />
          <span style={{ color: COLORS.acid }}>그 전에 만든 5일.</span>
        </Interactive.Div>

        <Interactive.Div
          name="Five-day promise"
          style={{
            width: 930,
            marginTop: 30,
            opacity: interpolate(frame, [66, 92], [0, 1], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
              easing: Easing.bezier(0.16, 1, 0.3, 1),
            }),
          }}
        >
          <AccentRule width={230} />
          <p style={{ margin: "28px 0 0", color: COLORS.muted, fontSize: 36, fontWeight: 760, lineHeight: 1.38, letterSpacing: "-0.035em" }}>
            반복하고, 연결하고, 중간에 무기를 설계해
            <br />이번 주의 투수를 직접 완성한다.
          </p>
        </Interactive.Div>

        <Interactive.Div
          name="Five completed slots proof"
          style={{
            position: "absolute",
            top: 390,
            right: 90,
            display: "flex",
            gap: 10,
            opacity: interpolate(frame, [96, 118], [0, 1], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
              easing: Easing.bezier(0.16, 1, 0.3, 1),
            }),
          }}
        >
          {[1, 2, 3, 4, 5].map((day) => (
            <div key={day} style={{ width: 72, height: 72, display: "grid", placeItems: "center", border: `2px solid ${COLORS.acid}`, backgroundColor: "rgba(7,11,10,0.82)", color: COLORS.acid, fontFamily: 'ui-monospace, "SFMono-Regular", Menlo, monospace', fontSize: 25, fontWeight: 950 }}>
              D{day}
            </div>
          ))}
        </Interactive.Div>

        <BottomProof left="5 TRAINING DAYS · 1 MIDWEEK BRANCH" right="REPEAT · CONNECT · BRANCH" />
      </SafeFrame>
      <Audio src={staticFile("audio/riser.mp3")} volume={0.2} />
      <Audio src={staticFile("audio/whoosh-short.mp3")} from={92} volume={0.28} />
      <Audio src={staticFile("audio/chime.mp3")} from={116} volume={0.2} />
    </AbsoluteFill>
  );
};
