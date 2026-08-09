import React from "react";
import { TransitionSeries, linearTiming } from "@remotion/transitions";
import { fade } from "@remotion/transitions/fade";
import { OpeningScene } from "./OpeningScene";
import { CareerScene } from "./CareerScene";
import { TrainingScene } from "./TrainingScene";
import { PitchScene } from "./PitchScene";
import { RebirthScene } from "./RebirthScene";
import { ClosingScene } from "./ClosingScene";

export const WebContestTrailer: React.FC = () => (
  <TransitionSeries>
    <TransitionSeries.Sequence durationInFrames={105} name="실제 웹 게임 오프닝"><OpeningScene /></TransitionSeries.Sequence>
    <TransitionSeries.Transition presentation={fade()} timing={linearTiming({ durationInFrames: 12 })} />
    <TransitionSeries.Sequence durationInFrames={165} name="3관문 커리어"><CareerScene /></TransitionSeries.Sequence>
    <TransitionSeries.Transition presentation={fade()} timing={linearTiming({ durationInFrames: 12 })} />
    <TransitionSeries.Sequence durationInFrames={180} name="15회 육성"><TrainingScene /></TransitionSeries.Sequence>
    <TransitionSeries.Transition presentation={fade()} timing={linearTiming({ durationInFrames: 12 })} />
    <TransitionSeries.Sequence durationInFrames={180} name="읽고 고르고 놓는 투구"><PitchScene /></TransitionSeries.Sequence>
    <TransitionSeries.Transition presentation={fade()} timing={linearTiming({ durationInFrames: 12 })} />
    <TransitionSeries.Sequence durationInFrames={165} name="기억과 야구혼 환생"><RebirthScene /></TransitionSeries.Sequence>
    <TransitionSeries.Transition presentation={fade()} timing={linearTiming({ durationInFrames: 12 })} />
    <TransitionSeries.Sequence durationInFrames={165} name="플레이 초대"><ClosingScene /></TransitionSeries.Sequence>
  </TransitionSeries>
);

