import React from 'react';
import {AbsoluteFill,Sequence,interpolate,staticFile} from 'remotion';
import {Audio} from '@remotion/media';
import {TransitionSeries,linearTiming} from '@remotion/transitions';
import {fade} from '@remotion/transitions/fade';
import {Locale,sceneDurations} from './copy';
import {PitchScene} from './PitchScene';
import {RebirthScene} from './RebirthScene';
import {TrainingScene} from './TrainingScene';
import {ChoiceScene} from './ChoiceScene';
import {DraftScene} from './DraftScene';
import {ContractScene} from './ContractScene';
import {ProScene} from './ProScene';
import {ClosingScene} from './ClosingScene';
const scenes=[PitchScene,RebirthScene,TrainingScene,ChoiceScene,DraftScene,ContractScene,ProScene,ClosingScene];
export const Trailer:React.FC<{locale:Locale;landscape:boolean}>=({locale,landscape})=><AbsoluteFill style={{background:'#214B35'}}>
 <TransitionSeries>{scenes.flatMap((Scene,i)=>[
  i>0?<TransitionSeries.Transition key={`t${i}`} presentation={fade()} timing={linearTiming({durationInFrames:8})}/>:null,
  <TransitionSeries.Sequence key={`s${i}`} durationInFrames={sceneDurations[i]} name={Scene.name}><Scene locale={locale} landscape={landscape}/></TransitionSeries.Sequence>
 ])}</TransitionSeries>
 <Audio src={staticFile('original-score.wav')} volume={(f)=>interpolate(f,[0,24,846,900],[0,.48,.48,0],{extrapolateRight:'clamp'})}/>
 <Audio src={staticFile('crowd.wav')} volume={(f)=>interpolate(f,[0,20,155,180],[0,.055,.055,0],{extrapolateRight:'clamp'})}/>
 <Sequence from={93} durationInFrames={30}><Audio src={staticFile('glove-catch.wav')} volume={.45}/></Sequence>
</AbsoluteFill>;
