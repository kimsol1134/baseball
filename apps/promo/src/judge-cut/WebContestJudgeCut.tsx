import React from "react";
import { TransitionSeries, linearTiming } from "@remotion/transitions";
import { fade } from "@remotion/transitions/fade";
import { CareerScene } from "../web-trailer/CareerScene";
import { ClosingScene } from "../web-trailer/ClosingScene";
import { OpeningScene } from "../web-trailer/OpeningScene";
import { PitchScene } from "../web-trailer/PitchScene";
import { TrainingScene } from "../web-trailer/TrainingScene";
import { CodexScene } from "./CodexScene";
import { FastRouteCaptureScene } from "./FastRouteCaptureScene";
import { HiveScene } from "./HiveScene";
import { RebirthCaptureScene } from "./RebirthCaptureScene";

export const JUDGE_CUT_FRAMES = 2080;

export const WebContestJudgeCut: React.FC = () => (
  <TransitionSeries>
    <TransitionSeries.Sequence durationInFrames={150} name="훅"><OpeningScene /></TransitionSeries.Sequence>
    <TransitionSeries.Transition presentation={fade()} timing={linearTiming({ durationInFrames: 12 })} />
    <TransitionSeries.Sequence durationInFrames={358} name="실제 빠른 경로"><FastRouteCaptureScene /></TransitionSeries.Sequence>
    <TransitionSeries.Transition presentation={fade()} timing={linearTiming({ durationInFrames: 12 })} />
    <TransitionSeries.Sequence durationInFrames={240} name="세 관문 커리어"><CareerScene /></TransitionSeries.Sequence>
    <TransitionSeries.Transition presentation={fade()} timing={linearTiming({ durationInFrames: 12 })} />
    <TransitionSeries.Sequence durationInFrames={240} name="15회 육성"><TrainingScene /></TransitionSeries.Sequence>
    <TransitionSeries.Transition presentation={fade()} timing={linearTiming({ durationInFrames: 12 })} />
    <TransitionSeries.Sequence durationInFrames={210} name="투구 판단과 실행"><PitchScene /></TransitionSeries.Sequence>
    <TransitionSeries.Transition presentation={fade()} timing={linearTiming({ durationInFrames: 12 })} />
    <TransitionSeries.Sequence durationInFrames={228} name="실제 지명과 환생"><RebirthCaptureScene /></TransitionSeries.Sequence>
    <TransitionSeries.Transition presentation={fade()} timing={linearTiming({ durationInFrames: 12 })} />
    <TransitionSeries.Sequence durationInFrames={270} name="Codex 협업 증거"><CodexScene /></TransitionSeries.Sequence>
    <TransitionSeries.Transition presentation={fade()} timing={linearTiming({ durationInFrames: 12 })} />
    <TransitionSeries.Sequence durationInFrames={240} name="Hive 출시 확장"><HiveScene /></TransitionSeries.Sequence>
    <TransitionSeries.Transition presentation={fade()} timing={linearTiming({ durationInFrames: 12 })} />
    <TransitionSeries.Sequence durationInFrames={240} name="플레이 초대"><ClosingScene /></TransitionSeries.Sequence>
  </TransitionSeries>
);
