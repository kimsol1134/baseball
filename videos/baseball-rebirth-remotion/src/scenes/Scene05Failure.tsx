import { Audio } from "@remotion/media";
import { AbsoluteFill, Easing, Interactive, interpolate, staticFile, useCurrentFrame } from "remotion";
import { Capture, COLORS, MonoLabel, SafeFrame } from "./shared";

export const Scene05Failure: React.FC = () => {
  const frame = useCurrentFrame();
  const hitPhase = interpolate(frame, [52, 68], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const memoryPhase = interpolate(frame, [118, 136], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });

  return (
    <AbsoluteFill style={{ backgroundColor: COLORS.ink }}>
      <Capture name="Completed build enters the match" src="game/10-growth-in-match.png" style={{ opacity: 1 - hitPhase, filter: "brightness(0.58)" }} />
      <Capture name="Readable pitch ends the life" src="game/11-first-life-hit.png" style={{ opacity: hitPhase * (1 - memoryPhase), filter: "brightness(0.58)" }} />
      <Capture name="Failure becomes a memory choice" src="game/12-memory-choice.png" style={{ opacity: memoryPhase, filter: "brightness(0.6)" }} />
      <AbsoluteFill style={{ backgroundImage: "linear-gradient(90deg, rgba(3,6,5,0.96) 0 48%, rgba(3,6,5,0.38) 68%, rgba(3,6,5,0.16) 100%)" }} />

      <SafeFrame>
        <Interactive.Div
          name="Failure warning"
          style={{
            width: 820,
            opacity: interpolate(frame, [8, 26, 104, 126], [0, 1, 1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.bezier(0.16, 1, 0.3, 1) }),
          }}
        >
          <MonoLabel tone="red">BUILD COMPLETE ≠ AUTOMATIC WIN</MonoLabel>
          <div style={{ marginTop: 22, fontSize: 84, fontWeight: 950, lineHeight: 1.03, letterSpacing: "-0.06em" }}>
            잘 키운 투수도,
            <br /><span style={{ color: COLORS.red }}>잘못 읽히면 끝난다.</span>
          </div>
          <p style={{ margin: "26px 0 0", color: COLORS.muted, fontSize: 32, fontWeight: 760 }}>시그니처는 힘을 주지만, 선택 대신 승리해 주지는 않는다.</p>
        </Interactive.Div>

        <Interactive.Div
          name="Failure inheritance message"
          style={{
            position: "absolute",
            top: 112,
            left: 100,
            width: 900,
            opacity: interpolate(frame, [138, 160], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.bezier(0.16, 1, 0.3, 1) }),
          }}
        >
          <MonoLabel>ROGUELITE MEMORY</MonoLabel>
          <div style={{ marginTop: 22, fontSize: 82, fontWeight: 950, lineHeight: 1.03, letterSpacing: "-0.06em" }}>
            실패도 삭제되지 않는다.
            <br /><span style={{ color: COLORS.acid }}>다음 육성의 정보가 된다.</span>
          </div>
          <div style={{ display: "inline-flex", marginTop: 30, alignItems: "center", gap: 16, padding: "15px 20px", border: `1px solid ${COLORS.line}`, backgroundColor: "rgba(7,11,10,0.88)", color: COLORS.paper, fontSize: 28, fontWeight: 900 }}>
            포수의 노트 <b style={{ color: COLORS.acid }}>→</b> 다음 삶에 정확한 카운터 사인 공개
          </div>
        </Interactive.Div>
      </SafeFrame>
      <Audio src={staticFile("audio/whoosh-short.mp3")} volume={0.24} />
      <Audio src={staticFile("audio/error.mp3")} from={62} volume={0.32} />
      <Audio src={staticFile("audio/impact-bass-2.mp3")} from={68} volume={0.3} />
      <Audio src={staticFile("audio/notification.mp3")} from={142} volume={0.22} />
    </AbsoluteFill>
  );
};
