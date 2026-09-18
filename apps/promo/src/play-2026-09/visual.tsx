import React from 'react';
import {AbsoluteFill, CanvasImage, staticFile, interpolate, useCurrentFrame, useVideoConfig} from 'remotion';
import {loadFont} from '@remotion/fonts';
import type {Locale} from './copy';

export const fontsReady = Promise.all([
 loadFont({family:'Gmarket',url:staticFile('fonts/GmarketSansBold.woff'),format:'woff',weight:'700'}),
 loadFont({family:'Gmarket',url:staticFile('fonts/GmarketSansMedium.woff'),format:'woff',weight:'500'}),
]);
export const font=(locale:Locale)=>locale==='ja'?'"Hiragino Sans", "Hiragino Kaku Gothic ProN", sans-serif':'Gmarket, sans-serif';
export const colors={ink:'#10231B',forest:'#214B35',lime:'#C2F575',cream:'#F5EFDF',line:'#8AAE76',gold:'#D7B16A'};
export const file=(locale:Locale,name:string)=>staticFile(`captures/${locale}/${name}.png`);

export const Field:React.FC<{light?:boolean}>=({light=false})=>{
 const {width,height}=useVideoConfig();
 return <AbsoluteFill style={{background:light?colors.cream:colors.forest,overflow:'hidden'}}>
   <svg width={width} height={height} style={{position:'absolute',inset:0}}>
    <defs><pattern id={light?"grain-paper":"grain-field"} width="13" height="13" patternUnits="userSpaceOnUse"><circle cx="1" cy="1" r=".7" fill={light?'#715D33':'#F1EFD8'} opacity=".10"/></pattern></defs>
    <rect width="100%" height="100%" fill={light?"url(#grain-paper)":"url(#grain-field)"}/>
    <path d={`M ${width*.04} ${height*.80} L ${width*.48} ${height*.46} L ${width*.99} ${height*.80}`} stroke={light?'#C4C4A3':'#426B4E'} strokeWidth="2" fill="none"/>
    <circle cx={width*.97} cy={height*.32} r={width*.33} fill="none" stroke={light?'#DDD7BE':'#395F44'} strokeWidth="2"/>
    <path d={`M ${width*.97-width*.27} ${height*.10} Q ${width*.67} ${height*.40} ${width*1.13} ${height*.61}`} fill="none" stroke={light?'#BEA475':'#6C8852'} strokeWidth="2" strokeDasharray="5 17"/>
   </svg>
 </AbsoluteFill>
};

// Uniform scale, only Android status/navigation chrome omitted. No fabricated UI or device bezel.
export const AppFrame:React.FC<{locale:Locale;asset:string;width:number;left:number;top:number;scale?:number;children?:React.ReactNode}>=({locale,asset,width,left,top,scale=1,children})=>{
 const factor=width/1080;
 return <div style={{position:'absolute',left,top,width,height:1952*factor,overflow:'hidden',borderRadius:14,boxShadow:'0 22px 65px #071B1A33',scale,border:'1px solid #80957B55',background:'#070C0A'}}>
  {children??<CanvasImage src={file(locale,asset)} style={{position:'absolute',left:0,top:-136*factor,width,height:2160*factor}}/>}
 </div>
};

export const Headline:React.FC<{locale:Locale;topic:string;lines:readonly string[];light?:boolean;animate?:boolean}>=({locale,topic,lines,light=false,animate=false})=>{
 const frame=useCurrentFrame();
 return <div data-headline style={{position:'absolute',left:84,right:84,top:60,fontFamily:font(locale),color:light?colors.ink:colors.cream,
  opacity:animate?interpolate(frame,[0,10],[0,1],{extrapolateLeft:'clamp',extrapolateRight:'clamp'}):1,
  translate:animate?`0 ${interpolate(frame,[0,14],[20,0],{extrapolateLeft:'clamp',extrapolateRight:'clamp'})}px`:'0 0'}}>
  <div style={{fontSize:25,fontWeight:500,letterSpacing:locale==='en'?2:1,color:light?'#486342':colors.lime,marginBottom:18}}>{topic}</div>
  <div style={{fontSize:locale==='ja'?72:locale==='en'?76:84,fontWeight:700,lineHeight:1.16,letterSpacing:locale==='ja'?-3:-3.5}}>{lines.map((line,i)=><div key={line} style={{whiteSpace:'nowrap',color:i===1&&!light?colors.lime:undefined}}>{line}</div>)}</div>
 </div>
};
