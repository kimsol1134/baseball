import React from 'react';
import {AbsoluteFill,Img,OffthreadVideo,Sequence,interpolate,staticFile,useCurrentFrame,useVideoConfig} from 'remotion';
import {Audio} from '@remotion/media';
import {copy,brands,scenes,type Locale} from './copy';

const fonts:Record<Locale,string> = {
 ko:'"Apple SD Gothic Neo", sans-serif',
 en:'"Helvetica Neue", Arial, sans-serif',
 ja:'"Hiragino Sans", "Hiragino Kaku Gothic ProN", sans-serif',
};
const lime='#BBF274',cream='#F2EBDD',ink='#0B1A14',gold='#E9BC6C';
const Grid:React.FC<{light?:boolean}>=({light})=><AbsoluteFill style={{opacity:light?0.09:0.13,backgroundImage:`linear-gradient(${light?ink:cream} 1px, transparent 1px),linear-gradient(90deg,${light?ink:cream} 1px,transparent 1px)`,backgroundSize:'120px 120px',maskImage:'linear-gradient(transparent 6%,black 72%)'}}/>;
const Diamond:React.FC<{light?:boolean}>=({light})=><div style={{position:'absolute',width:960,height:960,left:560,top:1900,transform:'rotate(45deg)',border:`2px solid ${light?ink:lime}`,borderRadius:90,opacity:0.13}}/>;

export const StoreShots:React.FC<{locale:Locale}>=({locale})=>{
 const f=useCurrentFrame(),{width,height}=useVideoConfig();
 const index=Math.min(7,Math.floor(f)),c=copy[locale][index],light=[1,3,6].includes(index);
 const accent=index===6?gold:lime;
 const color=light?ink:cream;
 return <AbsoluteFill style={{background:light?cream:ink,fontFamily:fonts[locale],overflow:'hidden'}}>
  <div style={{position:'absolute',width:1320,height:2868,transform:`scale(${width/1320},${height/2868})`,transformOrigin:'top left'}}>
   <AbsoluteFill style={{background:light?'radial-gradient(ellipse at 90% 80%,#DDCAA7,transparent 65%)':'radial-gradient(ellipse at 75% 74%,#294B2C,transparent 64%)'}}/>
   <Grid light={light}/><Diamond light={light}/>
   <div style={{position:'absolute',left:92,right:92,top:102,color}}>
    <div style={{display:'flex',alignItems:'center',gap:18,fontSize:28,fontWeight:700,letterSpacing:locale==='en'?'0.08em':'0.01em',color:light?'#365541':accent}}>
     <span style={{width:34,height:5,background:light?'#365541':accent}}/>{c.tag}
    </div>
    <h1 style={{fontSize:locale==='en'?112:locale==='ja'?108:124,fontWeight:800,lineHeight:1.13,letterSpacing:locale==='en'?'-0.055em':'-0.055em',margin:'34px 0 24px',wordBreak:'keep-all'}}>
     {c.title[0]}<br/><span style={{color:light?'#366E36':accent}}>{c.title[1]}</span>
    </h1>
    <p style={{fontSize:locale==='en'?32:34,letterSpacing:'-0.025em',fontWeight:500,margin:0,opacity:0.78,lineHeight:1.5}}>{c.detail}</p>
   </div>
   <div style={{position:'absolute',left:82,top:565,width:1156,height:2160,borderRadius:52,background:'#080F0B',overflow:'hidden',boxShadow:light?'0 50px 90px #34423255':'0 35px 100px #0009',border:`2px solid ${light?'#14302033':'#A4C49633'}`}}>
    <Img src={staticFile(`${locale}/${scenes[index]}.png`)} style={{width:1100,position:'absolute',top:-122,left:28}}/>
   </div>
   <div style={{position:'absolute',left:94,right:94,top:2781,display:'flex',justifyContent:'space-between',alignItems:'center',color,fontSize:24,fontWeight:700,letterSpacing:locale==='en'?'0.1em':'0.02em'}}>
    <span>{brands[locale]}</span><span style={{opacity:0.45,fontSize:22,fontVariantNumeric:'tabular-nums'}}>{String(index+1).padStart(2,'0')} / 08</span>
   </div>
  </div>
 </AbsoluteFill>;
};

export const previewLengths=[135,105,90,105,105,90,105,105];
export const previewFrames=previewLengths.reduce((a,b)=>a+b,0);
const Clip:React.FC<{locale:Locale;index:number;duration:number}>=({locale,index,duration})=>{
 const f=useCurrentFrame();const c=copy[locale][index];
 const enter=interpolate(f,[0,9],[0,1],{extrapolateLeft:'clamp',extrapolateRight:'clamp'});
 const scale=interpolate(f,[0,duration],[1,1.015],{extrapolateRight:'clamp'});
 return <AbsoluteFill style={{background:ink,fontFamily:fonts[locale],overflow:'hidden'}}>
  <OffthreadVideo src={staticFile(`${locale}/${scenes[index]}.mp4`)} muted style={{width:'100%',height:'100%',objectFit:'cover',transform:`scale(${scale})`}}/>
  <div style={{position:'absolute',left:0,right:0,top:0,height:380,background:'linear-gradient(#0B1A14 0%,#0B1A14F5 48%,#0B1A1400 100%)'}}/>
  <div style={{position:'absolute',left:48,right:48,top:62,opacity:enter,transform:`translateY(${(1-enter)*18}px)`,color:cream}}>
   <div style={{display:'flex',gap:12,alignItems:'center',color:lime,fontSize:20,fontWeight:700,letterSpacing:'0.035em',marginBottom:17}}>
    <span style={{width:22,height:3,background:lime}}/>{c.tag}
   </div>
   <div style={{fontSize:locale==='en'?52:53,fontWeight:800,lineHeight:1.23,letterSpacing:'-0.045em',maxWidth:780,wordBreak:'keep-all'}}>{c.video}</div>
  </div>
  {index===7?<div style={{position:'absolute',left:0,right:0,bottom:0,padding:'140px 48px 60px',color:cream,background:'linear-gradient(transparent,#0B1A14 65%)',fontSize:locale==='ja'?31:35,fontWeight:800}}>{brands[locale]}</div>:null}
 </AbsoluteFill>;
};

export const StorePreview:React.FC<{locale:Locale}>=({locale})=>{
 const frame=useCurrentFrame();let cursor=0;
 return <AbsoluteFill style={{background:ink}}>
  {previewLengths.map((duration,index)=>{const from=cursor;cursor+=duration;return <Sequence key={index} from={from} durationInFrames={duration}><Clip locale={locale} index={index} duration={duration}/></Sequence>;})}
  <Audio src={staticFile('score.wav')} volume={(f)=>0.67*Math.min(1,f/12,Math.max(0,(previewFrames-f)/42))}/>
  <div style={{position:'absolute',top:0,left:0,height:5,width:`${frame/previewFrames*100}%`,background:lime}}/>
 </AbsoluteFill>;
};
