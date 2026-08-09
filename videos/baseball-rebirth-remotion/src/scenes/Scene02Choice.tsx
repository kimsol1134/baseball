import { Audio } from "@remotion/media";
import { AbsoluteFill, Easing, Interactive, interpolate, staticFile, useCurrentFrame } from "remotion";
import { BottomProof, Capture, COLORS, MonoLabel, SafeFrame } from "./shared";

const RULES = [
  { key: "REPEAT", title: "같은 훈련 2회", detail: "핵심 능력 +2 · 숙련 LV.2" },
  { key: "CONNECT", title: "서로 다른 훈련", detail: "새 연계와 복합 능력 상승" },
  { key: "BRANCH", title: "3일차 피치 설계", detail: "경기 발동 조건 하나를 잠금" },
] as const;

export const Scene02Choice: React.FC = () => {
  const frame = useCurrentFrame();
  const selectedPhase = interpolate(frame, [126, 150], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.bezier(0.16, 1, 0.3, 1),
  });

  return (
    <AbsoluteFill style={{ backgroundColor: COLORS.ink }}>
      <Capture
        name="Three scout blueprints"
        src="game/02-training-start.png"
        style={{
          opacity: 1 - selectedPhase,
          scale: interpolate(frame, [0, 125], [1.04, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            easing: Easing.bezier(0.16, 1, 0.3, 1),
            output: "perceptual-scale",
          }),
          filter: "brightness(0.66)",
        }}
      />
      <Capture
        name="Locked weekly blueprint"
        src="game/03-blueprint-selected.png"
        style={{ opacity: selectedPhase, filter: "brightness(0.64)" }}
      />
      <AbsoluteFill style={{ backgroundImage: "linear-gradient(180deg, rgba(3,6,5,0.96) 0%, rgba(3,6,5,0.72) 33%, rgba(3,6,5,0.12) 66%, rgba(3,6,5,0.6) 100%)" }} />

      <SafeFrame>
        <Interactive.Div
          name="Blueprint message"
          style={{
            opacity: interpolate(frame, [8, 28, 116, 138], [0, 1, 1, 0], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
              easing: Easing.bezier(0.16, 1, 0.3, 1),
            }),
          }}
        >
          <MonoLabel>01 · CHOOSE A PITCHER IDENTITY</MonoLabel>
          <div style={{ marginTop: 20, color: COLORS.paper, fontSize: 82, fontWeight: 950, lineHeight: 1.04, letterSpacing: "-0.06em" }}>
            먼저, 어떤 투수로
            <br /><span style={{ color: COLORS.acid }}>키울지 공약한다.</span>
          </div>
          <p style={{ margin: "24px 0 0", color: COLORS.muted, fontSize: 32, fontWeight: 760 }}>압도형 · 코너 · 수싸움 — 목표 능력과 필요한 연계가 모두 달라진다.</p>
        </Interactive.Div>

        <Interactive.Div
          name="Five-choice system message"
          style={{
            position: "absolute",
            top: 92,
            left: 100,
            opacity: interpolate(frame, [148, 172], [0, 1], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
              easing: Easing.bezier(0.16, 1, 0.3, 1),
            }),
          }}
        >
          <MonoLabel>02 · DESIGN THE WHOLE WEEK</MonoLabel>
          <div style={{ marginTop: 20, color: COLORS.paper, fontSize: 76, fontWeight: 950, lineHeight: 1.05, letterSpacing: "-0.06em" }}>
            공약은 하나.
            <br /><span style={{ color: COLORS.blue }}>만드는 방식은 여러 갈래.</span>
          </div>
        </Interactive.Div>

        <div style={{ position: "absolute", right: 100, bottom: 150, left: 100, display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 18 }}>
          {RULES.map((rule, index) => {
            const start = 54 + index * 18;
            const selectedStart = 178 + index * 24;
            return (
              <Interactive.Div
                key={rule.key}
                name={`${rule.key} development rule`}
                style={{
                  minHeight: 150,
                  padding: "24px 26px",
                  borderTop: `5px solid ${index === 2 ? COLORS.blue : COLORS.acid}`,
                  borderRight: `1px solid ${COLORS.line}`,
                  borderBottom: `1px solid ${COLORS.line}`,
                  borderLeft: `1px solid ${COLORS.line}`,
                  backgroundColor: "rgba(7,11,10,0.88)",
                  opacity: interpolate(frame, [start, start + 18], [0, 1], {
                    extrapolateLeft: "clamp",
                    extrapolateRight: "clamp",
                    easing: Easing.bezier(0.16, 1, 0.3, 1),
                  }),
                  translate: interpolate(frame, [selectedStart, selectedStart + 20], ["0px 10px", "0px 0px"], {
                    extrapolateLeft: "clamp",
                    extrapolateRight: "clamp",
                    easing: Easing.bezier(0.16, 1, 0.3, 1),
                  }),
                }}
              >
                <span style={{ color: index === 2 ? COLORS.blue : COLORS.acid, fontFamily: 'ui-monospace, "SFMono-Regular", Menlo, monospace', fontSize: 21, fontWeight: 950, letterSpacing: "0.12em" }}>{rule.key}</span>
                <strong style={{ display: "block", marginTop: 12, color: COLORS.paper, fontSize: 31, fontWeight: 950 }}>{rule.title}</strong>
                <p style={{ margin: "10px 0 0", color: COLORS.muted, fontSize: 24, fontWeight: 720 }}>{rule.detail}</p>
              </Interactive.Div>
            );
          })}
        </div>
        <BottomProof left="3 BLUEPRINTS × 2 PITCH DESIGNS" right="5 CHOICES · 6 SYNERGIES" />
      </SafeFrame>
      <Audio src={staticFile("audio/click-soft.mp3")} from={44} volume={0.25} />
      <Audio src={staticFile("audio/click-soft.mp3")} from={64} volume={0.25} />
      <Audio src={staticFile("audio/click-soft.mp3")} from={84} volume={0.25} />
      <Audio src={staticFile("audio/whoosh-short.mp3")} from={132} volume={0.3} />
      <Audio src={staticFile("audio/ping.mp3")} from={208} volume={0.22} />
    </AbsoluteFill>
  );
};
