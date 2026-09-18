import React from 'react';
import {Composition,Folder,registerRoot} from 'remotion';
import {locales} from './copy';
import {Screenshots} from './Screenshots';
import {Trailer} from './Trailer';
import {Feature} from './Feature';
import {fontsReady} from './visual';
const Root:React.FC=()=><>{locales.map(locale=><Folder key={locale} name={locale}>
 <Composition id={`PlayShots-${locale}`} component={Screenshots} defaultProps={{locale}} durationInFrames={8} fps={1} width={1080} height={1920}/>
 <Composition id={`PlayTrailer-Portrait-${locale}`} component={Trailer} defaultProps={{locale,landscape:false}} durationInFrames={900} fps={30} width={1080} height={1920}/>
 <Composition id={`PlayTrailer-Landscape-${locale}`} component={Trailer} defaultProps={{locale,landscape:true}} durationInFrames={900} fps={30} width={1920} height={1080}/>
 <Composition id={`PlayFeature-${locale}`} component={Feature} defaultProps={{locale}} durationInFrames={1} fps={1} width={1024} height={500}/>
 <Composition id={`PlayThumbnail-${locale}`} component={Feature} defaultProps={{locale}} durationInFrames={1} fps={1} width={1280} height={720}/>
</Folder>)}</>;
fontsReady.then(() => registerRoot(Root));
