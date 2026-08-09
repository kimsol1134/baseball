import { TransitionSeries, linearTiming } from "@remotion/transitions";
import { fade } from "@remotion/transitions/fade";
import { Scene01Hook } from "./scenes/Scene01Hook";
import { Scene02Choice } from "./scenes/Scene02Choice";
import { Scene03Tradeoff } from "./scenes/Scene03Tradeoff";
import { Scene04MatchImpact } from "./scenes/Scene04MatchImpact";
import { Scene05Failure } from "./scenes/Scene05Failure";
import { Scene06Inheritance } from "./scenes/Scene06Inheritance";
import { Scene07Victory } from "./scenes/Scene07Victory";
import { Scene08Draft } from "./scenes/Scene08Draft";

export const DevelopmentDemo: React.FC = () => {
  return (
    <TransitionSeries name="Player development demo timeline">
      <TransitionSeries.Sequence name="01 Hook" durationInFrames={180}>
        <Scene01Hook />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={fade()} timing={linearTiming({ durationInFrames: 10 })} />
      <TransitionSeries.Sequence name="02 Blueprint and five-day rules" durationInFrames={300}>
        <Scene02Choice />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={fade()} timing={linearTiming({ durationInFrames: 10 })} />
      <TransitionSeries.Sequence name="03 Connect days one to three" durationInFrames={420}>
        <Scene03Tradeoff />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={fade()} timing={linearTiming({ durationInFrames: 10 })} />
      <TransitionSeries.Sequence name="04 Branch repeat and complete" durationInFrames={360}>
        <Scene04MatchImpact />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={fade()} timing={linearTiming({ durationInFrames: 10 })} />
      <TransitionSeries.Sequence name="05 Failure becomes memory" durationInFrames={210}>
        <Scene05Failure />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={fade()} timing={linearTiming({ durationInFrames: 10 })} />
      <TransitionSeries.Sequence name="06 Keep growth rebuild the week" durationInFrames={240}>
        <Scene06Inheritance />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={fade()} timing={linearTiming({ durationInFrames: 10 })} />
      <TransitionSeries.Sequence name="07 Second build and live trigger" durationInFrames={430}>
        <Scene07Victory />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={fade()} timing={linearTiming({ durationInFrames: 10 })} />
      <TransitionSeries.Sequence name="08 Legacy loop and CTA" durationInFrames={480}>
        <Scene08Draft />
      </TransitionSeries.Sequence>
    </TransitionSeries>
  );
};
