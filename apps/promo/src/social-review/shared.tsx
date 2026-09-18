import React from 'react';
import {AbsoluteFill,CanvasImage,interpolate,staticFile,useCurrentFrame,useVideoConfig} from 'remotion';
import {Video} from '@remotion/media';
import {loadFont} from '@remotion/fonts';
import {copy,Lang} from './copy';
export const fontsReady=Promise.all([loadFont({family:'Gmarket',url:staticFile('fonts/GmarketSansBold.woff'),format:'woff',weight:'700'}),loadFont({family:'Gmarket',url:staticFile('fonts/GmarketSansMedium.woff'),format:'woff',weight:'500'})]);
export const palette={bg:'#0A2019',cream:'#FFF6E2',lime:'#C6F65C',muted:'#A6BBA3',gold:'#F6C76E'};
export type Props={lang:Lang};
export const face=(lang:Lang)=>lang==='ja'?'"Hiragino Sans", sans-serif':'Gmarket, sans-serif';
export const Shell:React.FC<Props&{children:React.ReactNode;light?:boolean;stamp?:string}>=({lang,children,light=false,stamp})=>{
 const {height}=useVideoConfig();const f=useCurrentFrame();
 return <AbsoluteFill style={{background:light?palette.cream:palette.bg,color:light?palette.bg:palette.cream,fontFamily:face(lang),overflow:'hidden'}}>
  {!light&&<CanvasImage src={staticFile('power-art.png')} style={{position:'absolute',width:1800,height:1800,left:-340,top:height*.32,opacity:.17,scale:interpolate(f,[0,180],[1,1.06],{extrapolateRight:'clamp'})}}/>}
  <svg width="1080" height={height} style={{position:'absolute',inset:0,opacity:light?.13:.16}}><path d={`M-100 ${height*.8} L540 ${height*.42} L1180 ${height*.8}`} stroke={light?palette.bg:palette.lime} strokeWidth="3" fill="none"/><circle cx="930" cy="130" r="490" stroke={light?palette.bg:palette.lime} strokeWidth="2" fill="none" strokeDasharray="4 20"/></svg>
  <div style={{position:'absolute',left:86,top:height>1500?300:110,width:844,height:930}} data-safe-stage>
   <div style={{fontSize:25,fontWeight:500,letterSpacing:2,color:light?'#3D6048':palette.lime,marginBottom:32}}>{stamp??copy[lang].genre}</div>
   {children}
  </div>
 </AbsoluteFill>
};
export const Title:React.FC<Props&{lines:readonly string[];size?:number;light?:boolean;top?:number}>=({lang,lines,size,light=false,top=62})=>{
 const f=useCurrentFrame();return <div data-key-text style={{position:'absolute',left:0,top,width:844,fontSize:size??(lang==='en'?84:lang==='ja'?78:88),fontWeight:700,lineHeight:1.16,letterSpacing:-4}}>{lines.map((s,i)=><div key={s} style={{whiteSpace:'nowrap',color:i===1&&!light?palette.lime:undefined,translate:`0 ${interpolate(f,[i*3,12+i*3],[22,0],{extrapolateLeft:'clamp',extrapolateRight:'clamp'})}px`,opacity:interpolate(f,[i*3,6+i*3],[.1,1],{extrapolateLeft:'clamp',extrapolateRight:'clamp'})}}>{s}</div>)}</div>
};
export const Fine:React.FC<{children:React.ReactNode;light?:boolean}>=({children,light})=><div data-key-text style={{position:'absolute',top:894,left:0,right:0,fontSize:24,lineHeight:1.3,color:light?'#385844':palette.muted}}>{children}</div>;
export const Crop:React.FC<Props&{asset:string;top?:number;sourceY?:number;h?:number;live?:boolean;zoom?:boolean;width?:number}>=({lang,asset,top=314,sourceY=470,h=510,live=false,zoom=true,width=844})=>{
 const f=useCurrentFrame();const factor=width/1080;
 const style:React.CSSProperties={position:'absolute',left:0,top:-sourceY*factor,width,height:2160*factor};
 return <div style={{position:'absolute',left:(844-width)/2,top,width,height:h,overflow:'hidden',border:'2px solid #83A46F',borderRadius:24,boxShadow:'0 26px 60px #0005',scale:zoom?interpolate(f,[0,130],[.985,1],{extrapolateRight:'clamp'}):1,background:'#0D1612'}}>
 {live?<Video src={staticFile(`captures/${lang}/pitch.mp4`)} muted style={style}/>:<CanvasImage src={staticFile(`captures/${lang}/${asset}.png`)} style={style}/>}
 </div>
};
export const Sub:React.FC<{children:React.ReactNode;top?:number;light?:boolean}>=({children,top=820,light=false})=><div data-key-text style={{position:'absolute',top,left:0,right:0,fontSize:34,fontWeight:500,lineHeight:1.35,color:light?'#244F37':palette.cream}}>{children}</div>;
