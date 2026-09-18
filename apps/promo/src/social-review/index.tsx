import React from 'react';
import {AbsoluteFill,Composition,Sequence,registerRoot,interpolate,staticFile} from 'remotion';
import {Audio} from '@remotion/media';
import {TransitionSeries} from '@remotion/transitions';
import {Lang} from './copy';import {fontsReady} from './shared';
import {Hook} from './Hook';import {Proof} from './Proof';import {Review} from './Review';import {Response} from './Response';import {Choice} from './Choice';import {Pitch} from './Pitch';import {Legacy} from './Legacy';import {Close} from './Close';
type Mode='story'|'proof'|'play';
export const Ad:React.FC<{lang:Lang;mode:Mode}>=({lang,mode})=>{
 const scenes=mode==='story'?[[Hook,90],[Proof,90],[Review,90],[Response,120],[Choice,90],[Pitch,180],[Legacy,90],[Close,150]] as const:mode==='proof'?[[Proof,75],[Pitch,180],[Legacy,75],[Close,120]] as const:[[Pitch,180],[Proof,75],[Choice,75],[Close,120]] as const;
 const duration=mode==='story'?900:450;
 return <AbsoluteFill><TransitionSeries>{scenes.map(([Scene,n],i)=><TransitionSeries.Sequence key={i} durationInFrames={n} name={Scene.name}><Scene lang={lang}/></TransitionSeries.Sequence>)}</TransitionSeries>
 <Audio src={staticFile('original-score.wav')} volume={f=>interpolate(f,[0,8,duration-30,duration],[.65,.75,.75,0],{extrapolateRight:'clamp'})}/>
 <Sequence from={(mode==='story'?480:mode==='proof'?75:0)+93} durationInFrames={25}><Audio src={staticFile('glove-catch.wav')} volume={.45}/></Sequence>
 </AbsoluteFill>
};
const Root=()=> <>{(['ko','en','ja'] as Lang[]).map(lang=><Composition key={lang} id={`SocialStory-${lang}`} component={Ad} defaultProps={{lang,mode:'story' as Mode}} durationInFrames={900} fps={30} width={1080} height={1920}/>)}
 <Composition id="SocialStory-Feed-ko" component={Ad} defaultProps={{lang:'ko' as Lang,mode:'story' as Mode}} durationInFrames={900} fps={30} width={1080} height={1350}/>
 <Composition id="SocialProof-ko" component={Ad} defaultProps={{lang:'ko' as Lang,mode:'proof' as Mode}} durationInFrames={450} fps={30} width={1080} height={1920}/>
 <Composition id="SocialPlay-ko" component={Ad} defaultProps={{lang:'ko' as Lang,mode:'play' as Mode}} durationInFrames={450} fps={30} width={1080} height={1920}/>
 </>;
fontsReady.then(()=>registerRoot(Root));
