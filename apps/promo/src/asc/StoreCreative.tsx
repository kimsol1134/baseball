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
import {fontStack, japaneseFontStack, palette} from "../theme";
import {JapaneseAppScreen, type JapaneseScreenAsset} from "./JapaneseAppScreens";

const capture = (name: string) => staticFile(`asc/${name}.png`);
const drama = (name: string) => staticFile(`drama/${name}.mp4`);
const sfx = (name: string) => staticFile(`sfx/${name}.wav`);

const SOURCE = {width: 1320, height: 2868};

type StoreShot = {
  asset: JapaneseScreenAsset;
  eyebrow: string;
  line1: string;
  line2: string;
  accent: "lime" | "amber" | "rust";
  objectPosition?: string;
  objectScale?: number;
  transformOrigin?: string;
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

/**
 * 일본 검색 결과의 첫 세 장은 `직접 투구 → 지명 실패 → 계승 재도전`으로 이어진다.
 * 뒤쪽은 심리전과 유산 선택을 증명하고, 마지막 장에서 유료 앱의 가치 저항을 낮춘다.
 */
export const ASC_SHOTS_JP: StoreShot[] = [
  {
    asset: "pitch-strike",
    eyebrow: "一球ずつ、自分で勝負する",
    line1: "読む。選ぶ。",
    line2: "投げ切る。",
    accent: "lime",
    objectPosition: "50% 8%",
  },
  {
    asset: "draft-failure",
    eyebrow: "高校3年間の結末は、保証されない",
    line1: "指名されなければ",
    line2: "名前は残らない。",
    accent: "rust",
    objectPosition: "50% 0%",
  },
  {
    asset: "rebirth",
    eyebrow: "それでも、育てた時間は消えない",
    line1: "失敗を継いで",
    line2: "また始める。",
    accent: "lime",
    objectPosition: "50% 0%",
  },
  {
    asset: "next-life",
    eyebrow: "前の投手の手紙と、受け継いだ記憶",
    line1: "前の人生が",
    line2: "次の武器になる。",
    accent: "amber",
    objectPosition: "50% 4%",
  },
  {
    asset: "pitch-decision",
    eyebrow: "打者も、あなたの配球を読む",
    line1: "同じ一球は",
    line2: "二度と通じない。",
    accent: "lime",
    objectPosition: "50% 5%",
  },
  {
    asset: "legacy-choice",
    eyebrow: "育てた記録から、ひとつを選ぶ",
    line1: "何を残すかも",
    line2: "あなたが決める。",
    accent: "amber",
    objectPosition: "50% 27%",
  },
  {
    asset: "draft-success",
    eyebrow: "買い切り・追加課金なし",
    line1: "高校から引退まで",
    line2: "一人の野球人生。",
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

const ASCScreenshots: React.FC<{
  shots: StoreShot[];
  fontFamily: string;
  localizedJapanese?: boolean;
}> = ({shots, fontFamily, localizedJapanese = false}) => {
  const frame = useCurrentFrame();
  const {width, height} = useVideoConfig();
  const index = Math.min(shots.length - 1, Math.max(0, Math.floor(frame)));
  const shot = shots[index];
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
          fontFamily,
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
        {localizedJapanese ? (
          <div
            style={{
              position: "absolute",
              inset: 0,
              transform: `scale(${shot.objectScale ?? 1})`,
              transformOrigin: shot.transformOrigin ?? "50% 50%",
            }}
          >
            <JapaneseAppScreen asset={shot.asset} />
          </div>
        ) : (
          <Img
            src={capture(shot.asset)}
            style={{
              width: "100%",
              height: "100%",
              objectFit: "cover",
              objectPosition: shot.objectPosition ?? "50% 0%",
              transform: `scale(${shot.objectScale ?? 1})`,
              transformOrigin: shot.transformOrigin ?? "50% 50%",
            }}
          />
        )}
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

/** 6.9형과 6.5형에 같은 소스·카피를 쓰되 각 규격 안에서 비례 배치한다. */
export const ASCScreenshotsKR: React.FC = () => (
  <ASCScreenshots shots={ASC_SHOTS} fontFamily={fontStack} />
);

export const ASCScreenshotsJP: React.FC = () => (
  <ASCScreenshots shots={ASC_SHOTS_JP} fontFamily={japaneseFontStack} localizedJapanese />
);

const PREVIEW = {width: 886, height: 1920};

const fadeOpacity = (frame: number, duration: number, fade = 6) =>
  Math.min(
    interpolate(frame, [0, fade], [0, 1], {extrapolateRight: "clamp"}),
    interpolate(frame, [duration - fade, duration], [1, 0], {extrapolateLeft: "clamp"}),
  );

const MovingCapture: React.FC<{
  asset: JapaneseScreenAsset;
  duration: number;
  fromScale?: number;
  toScale?: number;
  position?: string;
  dim?: number;
  localizedJapanese?: boolean;
}> = ({
  asset,
  duration,
  fromScale = 1,
  toScale = 1.045,
  position = "50% 12%",
  dim = 0,
  localizedJapanese = false,
}) => {
  const frame = useCurrentFrame();
  const scale = interpolate(frame, [0, duration], [fromScale, toScale], {
    extrapolateRight: "clamp",
  });
  return (
    <AbsoluteFill style={{overflow: "hidden", background: palette.ink}}>
      {localizedJapanese ? (
        <div
          style={{
            position: "absolute",
            inset: 0,
            transform: `scale(${scale})`,
            transformOrigin: position,
          }}
        >
          <JapaneseAppScreen asset={asset} />
        </div>
      ) : (
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
      )}
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
  fontFamily?: string;
}> = ({
  eyebrow,
  line1,
  line2,
  accent = "lime",
  align = "top",
  compact = false,
  fontFamily = fontStack,
}) => {
  const frame = useCurrentFrame();
  const rise = interpolate(frame, [0, 10], [28, 0], {extrapolateRight: "clamp"});
  const opacity = interpolate(frame, [0, 8], [0, 1], {extrapolateRight: "clamp"});
  const color = accentColor(accent);
  const justifyContent = align === "center" ? "center" : align === "bottom" ? "flex-end" : "flex-start";
  return (
    <AbsoluteFill style={{justifyContent, fontFamily}}>
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
  asset: JapaneseScreenAsset;
  eyebrow?: string;
  line1: string;
  line2?: string;
  accent?: "lime" | "amber" | "rust";
  position?: string;
  dim?: number;
  align?: "top" | "center" | "bottom";
  fontFamily?: string;
  localizedJapanese?: boolean;
}> = ({
  duration,
  asset,
  eyebrow,
  line1,
  line2,
  accent,
  position,
  dim,
  align,
  fontFamily,
  localizedJapanese,
}) => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill style={{opacity: fadeOpacity(frame, duration)}}>
      <MovingCapture
        asset={asset}
        duration={duration}
        position={position}
        dim={dim}
        localizedJapanese={localizedJapanese}
      />
      <CopyOverlay
        eyebrow={eyebrow}
        line1={line1}
        line2={line2}
        accent={accent}
        align={align}
        fontFamily={fontFamily}
      />
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
  fontFamily?: string;
}> = ({duration, clip, line1, line2, accent, startFrom = 0, zoom = 1.32, fontFamily}) => {
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
      <CopyOverlay line1={line1} line2={line2} accent={accent} fontFamily={fontFamily} />
      <Grain />
    </AbsoluteFill>
  );
};

const QuestionScene: React.FC<{duration: number; copy: string; fontFamily: string}> = ({
  duration,
  copy,
  fontFamily,
}) => {
  const frame = useCurrentFrame();
  const scale = interpolate(frame, [0, duration], [0.92, 1.04], {extrapolateRight: "clamp"});
  const opacity = interpolate(frame, [0, 8, duration - 6, duration], [0, 1, 1, 0]);
  return (
    <AbsoluteFill style={{background: palette.ink, alignItems: "center", justifyContent: "center"}}>
      <div
        style={{
          fontFamily,
          fontSize: 126,
          color: palette.bone,
          fontWeight: 900,
          letterSpacing: "-0.06em",
          transform: `scale(${scale})`,
          opacity,
        }}
      >
        {copy}
      </div>
      <Grain opacity={0.18} />
    </AbsoluteFill>
  );
};

const ClosingScene: React.FC<{
  duration: number;
  line1: string;
  line2: string;
  footer: string;
  fontFamily: string;
}> = ({duration, line1, line2, footer, fontFamily}) => {
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
      <CopyOverlay line1={line1} line2={line2} align="center" fontFamily={fontFamily} />
      <div
        style={{
          position: "absolute",
          bottom: 280,
          fontFamily,
          color: palette.muted,
          fontSize: 30,
          fontWeight: 700,
          letterSpacing: "-0.015em",
        }}
      >
        {footer}
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

type PreviewCopy = {
  lastPitch: {eyebrow: string; line1: string; line2: string};
  choice: {eyebrow: string; line1: string; line2: string};
  collapse: {line1: string; line2: string};
  undrafted: {eyebrow: string; line1: string; line2: string};
  question: string;
  legacy: {eyebrow: string; line1: string; line2: string};
  rebirth: {eyebrow: string; line1: string; line2: string};
  nextLife: {eyebrow: string; line1: string; line2: string};
  payoff: {line1: string; line2: string};
  called: {eyebrow: string; line1: string; line2: string};
  closing: {line1: string; line2: string; footer: string};
};

const PREVIEW_COPY_KR: PreviewCopy = {
  lastPitch: {eyebrow: "3년을 키웠다", line1: "마지막", line2: "한 구."},
  choice: {eyebrow: "구종 · 코스 · 타이밍", line1: "전부", line2: "내가 정한다."},
  collapse: {line1: "한 구로", line2: "3년이 무너졌다."},
  undrafted: {eyebrow: "전 라운드 종료", line1: "이름은", line2: "불리지 않았다."},
  question: "끝?",
  legacy: {eyebrow: "아니. 하나를 남기고", line1: "다시", line2: "시작한다."},
  rebirth: {eyebrow: "다시 태어납니다", line1: "2번째", line2: "선수."},
  nextLife: {eyebrow: "전 생의 실패가", line1: "이번 생의", line2: "시작이 된다."},
  payoff: {line1: "다시,", line2: "마지막 한 구."},
  called: {eyebrow: "지명", line1: "이번 생엔", line2: "이름이 불렸다."},
  closing: {line1: "야구 못하면", line2: "또 환생함", footer: "이번 생엔, 이름이 불릴까."},
};

const PREVIEW_COPY_JP: PreviewCopy = {
  lastPitch: {eyebrow: "高校3年、育てた", line1: "最後の", line2: "一球。"},
  choice: {eyebrow: "球種・コース・タイミング", line1: "すべて", line2: "自分で決める。"},
  collapse: {line1: "その一球で", line2: "3年間が崩れた。"},
  undrafted: {eyebrow: "ドラフト終了", line1: "名前は", line2: "呼ばれなかった。"},
  question: "終わり？",
  legacy: {eyebrow: "いや、ひとつを残して", line1: "もう一度", line2: "始める。"},
  rebirth: {eyebrow: "記憶を受け継ぐ", line1: "2人目の", line2: "投手。"},
  nextLife: {eyebrow: "前の人生の失敗が", line1: "次の人生の", line2: "武器になる。"},
  payoff: {line1: "もう一度、", line2: "最後の一球。"},
  called: {eyebrow: "ドラフト指名", line1: "今度は", line2: "名前が呼ばれた。"},
  closing: {
    line1: "野球がダメなら",
    line2: "また転生。",
    footer: "買い切り・追加課金なし",
  },
};

const ASCPreview: React.FC<{
  copy: PreviewCopy;
  fontFamily: string;
  motionFirst?: boolean;
  localizedJapanese?: boolean;
}> = ({copy, fontFamily, motionFirst = false, localizedJapanese = false}) => {
  let cursor = 0;
  const at = (durationInFrames: number) => {
    const from = cursor;
    cursor += durationInFrames;
    return {from, durationInFrames};
  };

  return (
    <AbsoluteFill style={{background: palette.ink}}>
      <Sequence {...at(ASC_PREVIEW_BEATS.lastPitch)}>
        {motionFirst ? (
          <>
            <DramaScene
              duration={ASC_PREVIEW_BEATS.lastPitch}
              clip="called-strike"
              {...copy.lastPitch}
              accent="lime"
              startFrom={8}
              zoom={1.24}
              fontFamily={fontFamily}
            />
            <Sequence from={18} durationInFrames={ASC_PREVIEW_BEATS.lastPitch - 18}>
              <Audio src={sfx("umpire-strike")} volume={0.86} />
            </Sequence>
          </>
        ) : (
          <CapturedScene
            duration={ASC_PREVIEW_BEATS.lastPitch}
            asset="pitch-decision"
            {...copy.lastPitch}
            position="50% 7%"
            dim={0.12}
            fontFamily={fontFamily}
            localizedJapanese={localizedJapanese}
          />
        )}
      </Sequence>
      <Sequence {...at(ASC_PREVIEW_BEATS.choice)}>
        <CapturedScene
          duration={ASC_PREVIEW_BEATS.choice}
          asset="release-gesture"
          {...copy.choice}
          position="50% 5%"
          dim={0.08}
          accent="amber"
          fontFamily={fontFamily}
          localizedJapanese={localizedJapanese}
        />
      </Sequence>
      <Sequence {...at(ASC_PREVIEW_BEATS.collapse)}>
        <DramaScene
          duration={ASC_PREVIEW_BEATS.collapse}
          clip="home-run"
          {...copy.collapse}
          accent="rust"
          startFrom={10}
          zoom={1.08}
          fontFamily={fontFamily}
        />
        <Sequence from={25} durationInFrames={ASC_PREVIEW_BEATS.collapse - 25}>
          <Audio src={sfx("bat-contact-hard")} volume={0.82} />
        </Sequence>
      </Sequence>
      <Sequence {...at(ASC_PREVIEW_BEATS.undrafted)}>
        <CapturedScene
          duration={ASC_PREVIEW_BEATS.undrafted}
          asset="draft-failure"
          {...copy.undrafted}
          accent="rust"
          position="50% 0%"
          dim={0.06}
          align="bottom"
          fontFamily={fontFamily}
          localizedJapanese={localizedJapanese}
        />
      </Sequence>
      <Sequence {...at(ASC_PREVIEW_BEATS.question)}>
        <QuestionScene duration={ASC_PREVIEW_BEATS.question} copy={copy.question} fontFamily={fontFamily} />
      </Sequence>
      <Sequence {...at(ASC_PREVIEW_BEATS.legacy)}>
        <CapturedScene
          duration={ASC_PREVIEW_BEATS.legacy}
          asset="legacy-choice"
          {...copy.legacy}
          accent="amber"
          position="50% 27%"
          dim={0.03}
          fontFamily={fontFamily}
          localizedJapanese={localizedJapanese}
        />
      </Sequence>
      <Sequence {...at(ASC_PREVIEW_BEATS.rebirth)}>
        <CapturedScene
          duration={ASC_PREVIEW_BEATS.rebirth}
          asset="rebirth"
          {...copy.rebirth}
          position="50% 0%"
          dim={0.04}
          align="bottom"
          fontFamily={fontFamily}
          localizedJapanese={localizedJapanese}
        />
      </Sequence>
      <Sequence {...at(ASC_PREVIEW_BEATS.nextLife)}>
        <CapturedScene
          duration={ASC_PREVIEW_BEATS.nextLife}
          asset="next-life"
          {...copy.nextLife}
          accent="amber"
          position="50% 5%"
          dim={0.08}
          fontFamily={fontFamily}
          localizedJapanese={localizedJapanese}
        />
      </Sequence>
      <Sequence {...at(ASC_PREVIEW_BEATS.payoff)}>
        <DramaScene
          duration={ASC_PREVIEW_BEATS.payoff}
          clip="swinging-strike"
          {...copy.payoff}
          accent="lime"
          startFrom={10}
          zoom={1.28}
          fontFamily={fontFamily}
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
          {...copy.called}
          position="50% 0%"
          dim={0.04}
          align="bottom"
          fontFamily={fontFamily}
          localizedJapanese={localizedJapanese}
        />
      </Sequence>
      <Sequence {...at(ASC_PREVIEW_BEATS.closing)}>
        <ClosingScene duration={ASC_PREVIEW_BEATS.closing} {...copy.closing} fontFamily={fontFamily} />
      </Sequence>
    </AbsoluteFill>
  );
};

/** 27.6초. 무음 자동재생만으로도 실패 → 계승 → 재도전이 완결된다. */
export const ASCPreviewKR: React.FC = () => (
  <ASCPreview copy={PREVIEW_COPY_KR} fontFamily={fontStack} />
);

/** 일본어판은 같은 실제 플레이 컷을 쓰되 유료 구매의 이유가 마지막 프레임에 남는다. */
export const ASCPreviewJP: React.FC = () => (
  <ASCPreview
    copy={PREVIEW_COPY_JP}
    fontFamily={japaneseFontStack}
    motionFirst
    localizedJapanese
  />
);
