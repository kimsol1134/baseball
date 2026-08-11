import React from "react";
import {
  AbsoluteFill,
  Img,
  OffthreadVideo,
  Sequence,
  interpolate,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import {Audio} from "@remotion/media";
import {fontStack, palette} from "../theme";

const capture = (name: string) => staticFile(`asc/${name}.png`);
const drama = (name: string) => staticFile(`drama/${name}.mp4`);
const sfx = (name: string) => staticFile(`sfx/${name}.wav`);

const SOURCE = {width: 1320, height: 2868};

type StoreShot = {
  asset: string;
  eyebrow: string;
  line1: string;
  line2: string;
  accent: "lime" | "amber" | "rust";
  objectPosition?: string;
};

/**
 * 검색 결과에서 먼저 보이는 1~3장이 한 편의 광고가 되도록 순서를 고정한다.
 * 4~7장은 독특한 루프가 실제 시스템임을 증명하고, 마지막 장에서 감정적 보상을 준다.
 */
export const ASC_SHOTS: StoreShot[] = [
  {
    asset: "pitch-strike",
    eyebrow: "3년을 키운 투수의 승부처",
    line1: "마지막 한 구를",
    line2: "직접 던진다",
    accent: "lime",
    objectPosition: "50% 8%",
  },
  {
    asset: "draft-failure",
    eyebrow: "결과까지 당신의 몫",
    line1: "못하면",
    line2: "이름은 불리지 않는다",
    accent: "rust",
    objectPosition: "50% 0%",
  },
  {
    asset: "rebirth",
    eyebrow: "하지만 실패도 남는다",
    line1: "그래도 끝이 아니다",
    line2: "또, 환생함",
    accent: "lime",
    objectPosition: "50% 0%",
  },
  {
    asset: "legacy-choice",
    eyebrow: "직접 키운 기록으로 만들어지는 유산",
    line1: "전 생의 한 가지를",
    line2: "이번 생에 남긴다",
    accent: "amber",
    objectPosition: "50% 27%",
  },
  {
    asset: "pitch-decision",
    eyebrow: "매 타석 달라지는 심리전",
    line1: "타자도",
    line2: "당신의 공을 읽는다",
    accent: "lime",
    objectPosition: "50% 5%",
  },
  {
    asset: "next-life",
    eyebrow: "지난 선수의 편지와 대표 유산",
    line1: "전 생의 실패가",
    line2: "이번 생의 시작이 된다",
    accent: "amber",
    objectPosition: "50% 4%",
  },
  {
    asset: "draft-success",
    eyebrow: "마지막에는 이름이 남는다",
    line1: "이번 생엔",
    line2: "이름이 불릴까",
    accent: "lime",
    objectPosition: "50% 0%",
  },
];

const accentColor = (accent: StoreShot["accent"]) => {
  if (accent === "amber") return palette.amber;
  if (accent === "rust") return palette.rust;
  return palette.lime;
};

const Grain: React.FC<{opacity?: number}> = ({opacity = 0.12}) => {
  const frame = useCurrentFrame();
  const shift = (frame % 5) * 17;
  return (
    <AbsoluteFill
      style={{
        pointerEvents: "none",
        opacity,
        mixBlendMode: "soft-light",
        backgroundImage:
          "radial-gradient(circle at 18% 22%, rgba(255,255,255,.22) 0 1px, transparent 1.5px), radial-gradient(circle at 74% 68%, rgba(255,255,255,.18) 0 1px, transparent 1.5px)",
        backgroundSize: "19px 23px, 29px 31px",
        backgroundPosition: `${shift}px ${shift / 2}px, ${-shift / 3}px ${shift}px`,
      }}
    />
  );
};

const StoreBackground: React.FC = () => (
  <AbsoluteFill style={{background: palette.ink}}>
    <AbsoluteFill
      style={{
        background:
          "radial-gradient(82% 38% at 50% 12%, rgba(183,243,107,.12) 0%, rgba(20,42,30,.38) 40%, rgba(7,12,10,0) 76%)",
      }}
    />
    <AbsoluteFill
      style={{
        background:
          "linear-gradient(115deg, rgba(232,178,76,.035) 0%, transparent 38%, rgba(183,243,107,.025) 72%, transparent 100%)",
      }}
    />
  </AbsoluteFill>
);

/** 6.7형과 6.5형에 같은 소스·카피를 쓰되 각 규격 안에서 비례 배치한다. */
export const ASCScreenshotsKR: React.FC = () => {
  const frame = useCurrentFrame();
  const {width, height} = useVideoConfig();
  const index = Math.min(ASC_SHOTS.length - 1, Math.max(0, Math.floor(frame)));
  const shot = ASC_SHOTS[index];
  const sx = width / 1320;
  const sy = height / 2868;
  const top = 650 * sy;
  const side = 58 * sx;
  const cardWidth = width - side * 2;
  const cardHeight = (SOURCE.height / SOURCE.width) * cardWidth;
  const color = accentColor(shot.accent);

  return (
    <AbsoluteFill style={{overflow: "hidden", background: palette.ink}}>
      <StoreBackground />

      <div
        style={{
          position: "absolute",
          left: 76 * sx,
          right: 76 * sx,
          top: 108 * sy,
          textAlign: "center",
          fontFamily: fontStack,
        }}
      >
        <div
          style={{
            color,
            fontSize: 32 * sx,
            fontWeight: 800,
            letterSpacing: "0.08em",
            marginBottom: 22 * sy,
            wordBreak: "keep-all",
          }}
        >
          {shot.eyebrow}
        </div>
        <h2
          style={{
            margin: 0,
            color: palette.bone,
            fontSize: 102 * sx,
            fontWeight: 900,
            lineHeight: 1.14,
            letterSpacing: "-0.052em",
            wordBreak: "keep-all",
          }}
        >
          {shot.line1}
          <br />
          <span style={{color}}>{shot.line2}</span>
        </h2>
      </div>

      <div
        style={{
          position: "absolute",
          left: side,
          top,
          width: cardWidth,
          height: cardHeight,
          overflow: "hidden",
          borderRadius: 54 * sx,
          border: `${Math.max(2, 2 * sx)}px solid rgba(241,244,238,.72)`,
          boxShadow: `0 ${32 * sy}px ${90 * sy}px rgba(0,0,0,.62)`,
          background: palette.surface,
        }}
      >
        <Img
          src={capture(shot.asset)}
          style={{
            width: "100%",
            height: "100%",
            objectFit: "cover",
            objectPosition: shot.objectPosition ?? "50% 0%",
          }}
        />
        <AbsoluteFill
          style={{
            background:
              "linear-gradient(180deg, rgba(7,12,10,.08) 0%, transparent 12%, transparent 72%, rgba(7,12,10,.34) 100%)",
          }}
        />
      </div>
      <Grain opacity={0.08} />
    </AbsoluteFill>
  );
};

const PREVIEW = {width: 886, height: 1920};

const fadeOpacity = (frame: number, duration: number, fade = 6) =>
  Math.min(
    interpolate(frame, [0, fade], [0, 1], {extrapolateRight: "clamp"}),
    interpolate(frame, [duration - fade, duration], [1, 0], {extrapolateLeft: "clamp"}),
  );

const MovingCapture: React.FC<{
  asset: string;
  duration: number;
  fromScale?: number;
  toScale?: number;
  position?: string;
  dim?: number;
}> = ({asset, duration, fromScale = 1, toScale = 1.045, position = "50% 12%", dim = 0}) => {
  const frame = useCurrentFrame();
  const scale = interpolate(frame, [0, duration], [fromScale, toScale], {
    extrapolateRight: "clamp",
  });
  return (
    <AbsoluteFill style={{overflow: "hidden", background: palette.ink}}>
      <Img
        src={capture(asset)}
        style={{
          width: PREVIEW.width,
          height: PREVIEW.height,
          objectFit: "cover",
          objectPosition: position,
          transform: `scale(${scale})`,
        }}
      />
      {dim > 0 ? <AbsoluteFill style={{background: `rgba(7,12,10,${dim})`}} /> : null}
    </AbsoluteFill>
  );
};

const CopyOverlay: React.FC<{
  eyebrow?: string;
  line1: string;
  line2?: string;
  accent?: "lime" | "amber" | "rust";
  align?: "top" | "center" | "bottom";
  compact?: boolean;
}> = ({eyebrow, line1, line2, accent = "lime", align = "top", compact = false}) => {
  const frame = useCurrentFrame();
  const rise = interpolate(frame, [0, 10], [28, 0], {extrapolateRight: "clamp"});
  const opacity = interpolate(frame, [0, 8], [0, 1], {extrapolateRight: "clamp"});
  const color = accentColor(accent);
  const justifyContent = align === "center" ? "center" : align === "bottom" ? "flex-end" : "flex-start";
  return (
    <AbsoluteFill style={{justifyContent, fontFamily: fontStack}}>
      <div
        style={{
          padding: align === "bottom" ? "260px 54px 150px" : align === "center" ? "0 54px" : "108px 54px 220px",
          textAlign: align === "center" ? "center" : "left",
          opacity,
          transform: `translateY(${rise}px)`,
          background:
            align === "top"
              ? "linear-gradient(180deg, rgba(7,12,10,.98) 0%, rgba(7,12,10,.86) 48%, rgba(7,12,10,0) 100%)"
              : align === "bottom"
                ? "linear-gradient(0deg, rgba(7,12,10,.98) 0%, rgba(7,12,10,.78) 48%, rgba(7,12,10,0) 100%)"
                : undefined,
        }}
      >
        {eyebrow ? (
          <div
            style={{
              marginBottom: 14,
              color,
              fontSize: 24,
              fontWeight: 800,
              letterSpacing: "0.12em",
            }}
          >
            {eyebrow}
          </div>
        ) : null}
        <div
          style={{
            color: palette.bone,
            fontSize: compact ? 60 : 72,
            lineHeight: 1.14,
            fontWeight: 900,
            letterSpacing: "-0.052em",
            wordBreak: "keep-all",
          }}
        >
          {line1}
          {line2 ? (
            <>
              <br />
              <span style={{color}}>{line2}</span>
            </>
          ) : null}
        </div>
      </div>
    </AbsoluteFill>
  );
};

const CapturedScene: React.FC<{
  duration: number;
  asset: string;
  eyebrow?: string;
  line1: string;
  line2?: string;
  accent?: "lime" | "amber" | "rust";
  position?: string;
  dim?: number;
  align?: "top" | "center" | "bottom";
}> = ({duration, asset, eyebrow, line1, line2, accent, position, dim, align}) => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill style={{opacity: fadeOpacity(frame, duration)}}>
      <MovingCapture asset={asset} duration={duration} position={position} dim={dim} />
      <CopyOverlay eyebrow={eyebrow} line1={line1} line2={line2} accent={accent} align={align} />
      <Grain />
    </AbsoluteFill>
  );
};

const DramaScene: React.FC<{
  duration: number;
  clip: string;
  line1: string;
  line2: string;
  accent: "lime" | "amber" | "rust";
  startFrom?: number;
  zoom?: number;
}> = ({duration, clip, line1, line2, accent, startFrom = 0, zoom = 1.32}) => {
  const frame = useCurrentFrame();
  const push = interpolate(frame, [0, duration], [zoom, zoom + 0.08], {extrapolateRight: "clamp"});
  return (
    <AbsoluteFill style={{opacity: fadeOpacity(frame, duration), background: palette.ink, overflow: "hidden"}}>
      <OffthreadVideo
        src={drama(clip)}
        startFrom={startFrom}
        muted
        style={{
          width: PREVIEW.width,
          height: PREVIEW.height,
          objectFit: "cover",
          transform: `scale(${push})`,
          transformOrigin: "50% 43%",
        }}
      />
      <AbsoluteFill style={{background: "linear-gradient(180deg, rgba(7,12,10,.9), transparent 44%, rgba(7,12,10,.3))"}} />
      <CopyOverlay line1={line1} line2={line2} accent={accent} />
      <Grain />
    </AbsoluteFill>
  );
};

const QuestionScene: React.FC<{duration: number}> = ({duration}) => {
  const frame = useCurrentFrame();
  const scale = interpolate(frame, [0, duration], [0.92, 1.04], {extrapolateRight: "clamp"});
  const opacity = interpolate(frame, [0, 8, duration - 6, duration], [0, 1, 1, 0]);
  return (
    <AbsoluteFill style={{background: palette.ink, alignItems: "center", justifyContent: "center"}}>
      <div
        style={{
          fontFamily: fontStack,
          fontSize: 126,
          color: palette.bone,
          fontWeight: 900,
          letterSpacing: "-0.06em",
          transform: `scale(${scale})`,
          opacity,
        }}
      >
        끝?
      </div>
      <Grain opacity={0.18} />
    </AbsoluteFill>
  );
};

const ClosingScene: React.FC<{duration: number}> = ({duration}) => {
  const frame = useCurrentFrame();
  const glow = interpolate(frame, [0, duration], [0.35, 0.9], {extrapolateRight: "clamp"});
  return (
    <AbsoluteFill style={{background: palette.ink, alignItems: "center", justifyContent: "center", padding: "0 48px"}}>
      <AbsoluteFill
        style={{
          opacity: glow,
          background:
            "radial-gradient(70% 48% at 50% 42%, rgba(183,243,107,.18) 0%, rgba(20,42,30,.58) 38%, rgba(7,12,10,0) 78%)",
        }}
      />
      <CopyOverlay line1="야구 못하면" line2="또 환생함" align="center" />
      <div
        style={{
          position: "absolute",
          bottom: 280,
          fontFamily: fontStack,
          color: palette.muted,
          fontSize: 30,
          fontWeight: 700,
          letterSpacing: "-0.015em",
        }}
      >
        이번 생엔, 이름이 불릴까.
      </div>
      <Grain opacity={0.15} />
    </AbsoluteFill>
  );
};

export const ASC_PREVIEW_BEATS = {
  lastPitch: 66,
  choice: 72,
  collapse: 82,
  undrafted: 84,
  question: 36,
  legacy: 94,
  rebirth: 72,
  nextLife: 86,
  payoff: 84,
  called: 74,
  closing: 78,
} as const;

export const ASC_PREVIEW_FRAMES = Object.values(ASC_PREVIEW_BEATS).reduce((sum, value) => sum + value, 0);

/** 27.6초. 무음 자동재생만으로도 실패 → 계승 → 재도전이 완결된다. */
export const ASCPreviewKR: React.FC = () => {
  let cursor = 0;
  const at = (durationInFrames: number) => {
    const from = cursor;
    cursor += durationInFrames;
    return {from, durationInFrames};
  };

  return (
    <AbsoluteFill style={{background: palette.ink}}>
      <Sequence {...at(ASC_PREVIEW_BEATS.lastPitch)}>
        <CapturedScene
          duration={ASC_PREVIEW_BEATS.lastPitch}
          asset="pitch-decision"
          eyebrow="3년을 키웠다"
          line1="마지막"
          line2="한 구."
          position="50% 7%"
          dim={0.12}
        />
      </Sequence>
      <Sequence {...at(ASC_PREVIEW_BEATS.choice)}>
        <CapturedScene
          duration={ASC_PREVIEW_BEATS.choice}
          asset="release-gesture"
          eyebrow="구종 · 코스 · 타이밍"
          line1="전부"
          line2="내가 정한다."
          position="50% 5%"
          dim={0.08}
          accent="amber"
        />
      </Sequence>
      <Sequence {...at(ASC_PREVIEW_BEATS.collapse)}>
        <DramaScene
          duration={ASC_PREVIEW_BEATS.collapse}
          clip="home-run"
          line1="한 구로"
          line2="3년이 무너졌다."
          accent="rust"
          startFrom={10}
          zoom={1.08}
        />
        <Sequence from={25} durationInFrames={ASC_PREVIEW_BEATS.collapse - 25}>
          <Audio src={sfx("bat-contact-hard")} volume={0.82} />
        </Sequence>
      </Sequence>
      <Sequence {...at(ASC_PREVIEW_BEATS.undrafted)}>
        <CapturedScene
          duration={ASC_PREVIEW_BEATS.undrafted}
          asset="draft-failure"
          eyebrow="전 라운드 종료"
          line1="이름은"
          line2="불리지 않았다."
          accent="rust"
          position="50% 0%"
          dim={0.06}
          align="bottom"
        />
      </Sequence>
      <Sequence {...at(ASC_PREVIEW_BEATS.question)}>
        <QuestionScene duration={ASC_PREVIEW_BEATS.question} />
      </Sequence>
      <Sequence {...at(ASC_PREVIEW_BEATS.legacy)}>
        <CapturedScene
          duration={ASC_PREVIEW_BEATS.legacy}
          asset="legacy-choice"
          eyebrow="아니. 하나를 남기고"
          line1="다시"
          line2="시작한다."
          accent="amber"
          position="50% 27%"
          dim={0.03}
        />
      </Sequence>
      <Sequence {...at(ASC_PREVIEW_BEATS.rebirth)}>
        <CapturedScene
          duration={ASC_PREVIEW_BEATS.rebirth}
          asset="rebirth"
          eyebrow="다시 태어납니다"
          line1="2번째"
          line2="선수."
          position="50% 0%"
          dim={0.04}
          align="bottom"
        />
      </Sequence>
      <Sequence {...at(ASC_PREVIEW_BEATS.nextLife)}>
        <CapturedScene
          duration={ASC_PREVIEW_BEATS.nextLife}
          asset="next-life"
          eyebrow="전 생의 실패가"
          line1="이번 생의"
          line2="시작이 된다."
          accent="amber"
          position="50% 5%"
          dim={0.08}
        />
      </Sequence>
      <Sequence {...at(ASC_PREVIEW_BEATS.payoff)}>
        <DramaScene
          duration={ASC_PREVIEW_BEATS.payoff}
          clip="swinging-strike"
          line1="다시,"
          line2="마지막 한 구."
          accent="lime"
          startFrom={10}
          zoom={1.28}
        />
        <Sequence from={28} durationInFrames={ASC_PREVIEW_BEATS.payoff - 28}>
          <Audio src={sfx("swing-miss")} volume={0.9} />
        </Sequence>
        <Sequence from={48} durationInFrames={ASC_PREVIEW_BEATS.payoff - 48}>
          <Audio src={sfx("umpire-strikeout")} volume={0.9} />
        </Sequence>
      </Sequence>
      <Sequence {...at(ASC_PREVIEW_BEATS.called)}>
        <CapturedScene
          duration={ASC_PREVIEW_BEATS.called}
          asset="draft-success"
          eyebrow="지명"
          line1="이번 생엔"
          line2="이름이 불렸다."
          position="50% 0%"
          dim={0.04}
          align="bottom"
        />
      </Sequence>
      <Sequence {...at(ASC_PREVIEW_BEATS.closing)}>
        <ClosingScene duration={ASC_PREVIEW_BEATS.closing} />
      </Sequence>
    </AbsoluteFill>
  );
};
