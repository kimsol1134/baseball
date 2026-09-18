import React from 'react';
import {AbsoluteFill,CanvasImage,staticFile,useVideoConfig} from 'remotion';
import {Locale,brand} from './copy';
import {colors,font} from './visual';
export const Feature:React.FC<{locale:Locale}>=({locale})=>{
 const {width,height}=useVideoConfig();const s=width/1024;const y=(height-500*s)/2;
 return <AbsoluteFill style={{background:colors.forest,overflow:'hidden'}}>
  <CanvasImage src={staticFile('power-art.png')} style={{width,height,objectFit:'cover',position:'absolute'}}/>
  <AbsoluteFill style={{background:'linear-gradient(90deg, #143B2BF5 0%, #153A28E0 39%, #153A2820 70%)'}}/>
  <div style={{position:'absolute',width:1024,height:500,left:0,top:y,scale:s,transformOrigin:'0 0',fontFamily:font(locale),color:colors.cream}}>
   <div style={{position:'absolute',left:104,top:60,fontSize:22,letterSpacing:2,color:colors.lime}}>{locale==='ko'?'직접 던지는 투수 성장 RPG':locale==='en'?'A BASEBALL CAREER RPG':'自分で投げる投手育成RPG'}</div>
   {locale==='ko'?<CanvasImage src={staticFile('logo.png')} style={{position:'absolute',left:62,top:-20,width:440,height:440}}/>:
    <div style={{position:'absolute',left:104,top:128,fontWeight:700,fontSize:locale==='en'?67:51,lineHeight:1.18,letterSpacing:-2}}>{locale==='en'?<>MOUND<br/><span style={{color:colors.lime}}>REBORN</span></>:<>野球がダメなら<br/><span style={{fontSize:68,color:colors.lime}}>また転生</span></>}</div>}
   <div style={{position:'absolute',left:104,bottom:58,fontSize:locale==='en'?22:25,color:colors.cream,lineHeight:1.5}}>{locale==='ko'?<>한 구는 손끝으로.<br/>인생은 내 선택으로.</>:locale==='en'?<>Your pitch. Your choices.<br/>Your baseball life.</>:<>一球は指先で。<br/>人生は選択で。</>}</div>
  </div>
 </AbsoluteFill>
};
