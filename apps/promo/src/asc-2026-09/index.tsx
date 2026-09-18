import React from 'react';
import {Composition,registerRoot} from 'remotion';
import {StoreShots,StorePreview,previewFrames} from './Creative';
import type {Locale} from './copy';
const Root:React.FC=()=> <>{(['ko','en','ja'] as Locale[]).flatMap(locale=>[
 <Composition key={`69-${locale}`} id={`ASCRefreshShots69-${locale}`} component={StoreShots} defaultProps={{locale}} width={1320} height={2868} fps={1} durationInFrames={8}/>,
 <Composition key={`65-${locale}`} id={`ASCRefreshShots65-${locale}`} component={StoreShots} defaultProps={{locale}} width={1284} height={2778} fps={1} durationInFrames={8}/>,
 <Composition key={`video-${locale}`} id={`ASCRefreshPreview-${locale}`} component={StorePreview} defaultProps={{locale}} width={886} height={1920} fps={30} durationInFrames={previewFrames}/>,
 ])}</>;
registerRoot(Root);
