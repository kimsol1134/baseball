import React from "react";
import { Composition } from "remotion";
import { AppPreview, PREVIEW_FRAMES } from "./AppPreview";
import { SHOTS, Screenshots } from "./Screenshots";
import { BEATS, HeroLoop, Trailer } from "./Trailer";
import { WebContestTrailer } from "./web-trailer/WebContestTrailer";
import { OpeningScene } from "./web-trailer/OpeningScene";
import { CareerScene } from "./web-trailer/CareerScene";
import { TrainingScene } from "./web-trailer/TrainingScene";
import { PitchScene } from "./web-trailer/PitchScene";
import { RebirthScene } from "./web-trailer/RebirthScene";
import { ClosingScene } from "./web-trailer/ClosingScene";
import { Folder } from "remotion";
import { CodexScene } from "./judge-cut/CodexScene";
import { FastRouteCaptureScene } from "./judge-cut/FastRouteCaptureScene";
import { HiveScene } from "./judge-cut/HiveScene";
import { JUDGE_CUT_FRAMES, WebContestJudgeCut } from "./judge-cut/WebContestJudgeCut";
import { RebirthCaptureScene } from "./judge-cut/RebirthCaptureScene";
import { PayoffHookScene } from "./judge-cut/PayoffHookScene";
import { JudgePoster } from "./judge-cut/JudgePoster";
import {
  ASC_PREVIEW_FRAMES,
  ASC_SHOTS,
  ASC_SHOTS_EN,
  ASC_SHOTS_JP,
  ASCPreviewEN,
  ASCPreviewJP,
  ASCPreviewKR,
  ASCScreenshotsEN,
  ASCScreenshotsJP,
  ASCScreenshotsKR,
} from "./asc/StoreCreative";

const TRAILER_FRAMES = Object.values(BEATS).reduce((sum, length) => sum + length, 0);

export const RemotionRoot: React.FC = () => (
  <>
    <Folder name="App-Store-2026-08">
      <Composition
        id="ASCPreviewKR"
        component={ASCPreviewKR}
        durationInFrames={ASC_PREVIEW_FRAMES}
        fps={30}
        width={886}
        height={1920}
      />
      <Composition
        id="ASCScreenshots67KR"
        component={ASCScreenshotsKR}
        durationInFrames={ASC_SHOTS.length}
        fps={1}
        width={1320}
        height={2868}
      />
      <Composition
        id="ASCScreenshots65KR"
        component={ASCScreenshotsKR}
        durationInFrames={ASC_SHOTS.length}
        fps={1}
        width={1284}
        height={2778}
      />
      <Composition
        id="ASCPreviewJP"
        component={ASCPreviewJP}
        durationInFrames={ASC_PREVIEW_FRAMES}
        fps={30}
        width={886}
        height={1920}
      />
      <Composition
        id="ASCScreenshots69JP"
        component={ASCScreenshotsJP}
        durationInFrames={ASC_SHOTS_JP.length}
        fps={1}
        width={1320}
        height={2868}
      />
      <Composition
        id="ASCScreenshots65JP"
        component={ASCScreenshotsJP}
        durationInFrames={ASC_SHOTS_JP.length}
        fps={1}
        width={1284}
        height={2778}
      />
      <Composition
        id="ASCPreviewEN"
        component={ASCPreviewEN}
        durationInFrames={ASC_PREVIEW_FRAMES}
        fps={30}
        width={886}
        height={1920}
      />
      <Composition
        id="ASCScreenshots69EN"
        component={ASCScreenshotsEN}
        durationInFrames={ASC_SHOTS_EN.length}
        fps={1}
        width={1320}
        height={2868}
      />
      <Composition
        id="ASCScreenshots65EN"
        component={ASCScreenshotsEN}
        durationInFrames={ASC_SHOTS_EN.length}
        fps={1}
        width={1284}
        height={2778}
      />
    </Folder>
    <Folder name="Web-Contest-Trailer-Scenes">
      <Composition id="WebOpeningScene" component={OpeningScene} durationInFrames={105} fps={30} width={1920} height={1080} />
      <Composition id="WebCareerScene" component={CareerScene} durationInFrames={165} fps={30} width={1920} height={1080} />
      <Composition id="WebTrainingScene" component={TrainingScene} durationInFrames={180} fps={30} width={1920} height={1080} />
      <Composition id="WebPitchScene" component={PitchScene} durationInFrames={180} fps={30} width={1920} height={1080} />
      <Composition id="WebRebirthScene" component={RebirthScene} durationInFrames={165} fps={30} width={1920} height={1080} />
      <Composition id="WebClosingScene" component={ClosingScene} durationInFrames={165} fps={30} width={1920} height={1080} />
    </Folder>
    <Composition
      id="WebContestTrailer"
      component={WebContestTrailer}
      durationInFrames={900}
      fps={30}
      width={1920}
      height={1080}
    />
    <Folder name="Web-Contest-Judge-Cut-Scenes">
      <Composition id="JudgePayoffHook" component={PayoffHookScene} durationInFrames={150} fps={30} width={1920} height={1080} />
      <Composition id="JudgeFastRouteCapture" component={FastRouteCaptureScene} durationInFrames={330} fps={30} width={1920} height={1080} />
      <Composition id="JudgeRebirthCapture" component={RebirthCaptureScene} durationInFrames={210} fps={30} width={1920} height={1080} />
      <Composition id="JudgeCodexScene" component={CodexScene} durationInFrames={240} fps={30} width={1920} height={1080} />
      <Composition id="JudgeHiveScene" component={HiveScene} durationInFrames={120} fps={30} width={1920} height={1080} />
      <Composition id="JudgePoster" component={JudgePoster} durationInFrames={1} fps={30} width={1920} height={1080} />
    </Folder>
    <Composition
      id="WebContestJudgeCut"
      component={WebContestJudgeCut}
      durationInFrames={JUDGE_CUT_FRAMES}
      fps={30}
      width={1920}
      height={1080}
    />
    {/* 본편. 30fps라 Trailer의 프레임 상수가 그대로 초로 읽힌다. */}
    <Composition
      id="Trailer"
      component={Trailer}
      durationInFrames={TRAILER_FRAMES}
      fps={30}
      width={1920}
      height={1080}
    />
    {/* App Store Connect 앱 미리보기. 886×1920·30fps·15~30초는 Apple이 정한 규격이라
        임의로 바꾸면 업로드에서 거절된다. */}
    <Composition
      id="AppPreview"
      component={AppPreview}
      durationInFrames={PREVIEW_FRAMES}
      fps={30}
      width={886}
      height={1920}
    />
    {/* App Store 스크린샷. 프레임 하나가 한 장이라 --frame=0..4로 뽑는다.
        6.5" 규격(1242×2688)이며, ASC가 요구하는 크기가 바뀌면 여기부터 고친다. */}
    <Composition
      id="Screenshots"
      component={Screenshots}
      durationInFrames={SHOTS.length}
      fps={1}
      width={1242}
      height={2688}
    />
    {/* 랜딩 히어로용 무음 반복. 승부 장면은 60fps로 렌더했으므로 여기서도 60으로 돌린다. */}
    <Composition
      id="HeroLoop"
      component={HeroLoop}
      durationInFrames={120}
      fps={60}
      width={1600}
      height={900}
    />
  </>
);
