import "./index.css";
import { Composition, Folder } from "remotion";
import { DevelopmentDemo } from "./Composition";
import { Scene01Hook } from "./scenes/Scene01Hook";
import { Scene02Choice } from "./scenes/Scene02Choice";
import { Scene03Tradeoff } from "./scenes/Scene03Tradeoff";
import { Scene04MatchImpact } from "./scenes/Scene04MatchImpact";
import { Scene05Failure } from "./scenes/Scene05Failure";
import { Scene06Inheritance } from "./scenes/Scene06Inheritance";
import { Scene07Victory } from "./scenes/Scene07Victory";
import { Scene08Draft } from "./scenes/Scene08Draft";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="BaseballRebirthDevelopmentDemo"
        component={DevelopmentDemo}
        durationInFrames={2550}
        fps={30}
        width={1920}
        height={1080}
      />
      <Folder name="DevelopmentDemo-Scenes">
        <Composition id="Scene-01-Hook" component={Scene01Hook} durationInFrames={180} fps={30} width={1920} height={1080} />
        <Composition id="Scene-02-Blueprint-Rules" component={Scene02Choice} durationInFrames={300} fps={30} width={1920} height={1080} />
        <Composition id="Scene-03-Connect-Days" component={Scene03Tradeoff} durationInFrames={420} fps={30} width={1920} height={1080} />
        <Composition id="Scene-04-Complete-Build" component={Scene04MatchImpact} durationInFrames={360} fps={30} width={1920} height={1080} />
        <Composition id="Scene-05-Failure-Memory" component={Scene05Failure} durationInFrames={210} fps={30} width={1920} height={1080} />
        <Composition id="Scene-06-Inheritance-Rebuild" component={Scene06Inheritance} durationInFrames={240} fps={30} width={1920} height={1080} />
        <Composition id="Scene-07-Second-Build" component={Scene07Victory} durationInFrames={430} fps={30} width={1920} height={1080} />
        <Composition id="Scene-08-Legacy-CTA" component={Scene08Draft} durationInFrames={480} fps={30} width={1920} height={1080} />
      </Folder>
    </>
  );
};
