import React from 'react';
import {AbsoluteFill, CanvasImage, interpolate, staticFile, useCurrentFrame} from 'remotion';
import {Video} from '@remotion/media';
import {shots,brand,promise,Locale} from './copy';
import {Field,AppFrame,Headline,colors,font} from './visual';
export type SceneProps={locale:Locale;landscape:boolean};
export const StoryScene:React.FC<SceneProps&{index:number;live?:boolean;closing?:boolean}>=({locale,landscape,index,live=false,closing=false})=>{
 const frame=useCurrentFrame();const shot=shots[index];const light=[1,4,7].includes(index)&&!closing;
 const appWidth=landscape?520:820;const factor=appWidth/1080;
 return <AbsoluteFill style={{overflow:'hidden'}}>
  <Field light={light}/>
  {!landscape&&!closing&&<Headline locale={locale} topic={shot.topic[locale]} lines={shot.lines[locale]} light={light} animate/>}
  {landscape&&<div style={{position:'absolute',left:86,top:72,width:1130,fontFamily:font(locale),color:light?colors.ink:colors.cream}}>
    <div style={{fontSize:28,letterSpacing:3,color:light?'#426344':colors.lime}}>{brand[locale]}</div>
    <div style={{height:5,width:90,background:colors.lime,marginTop:45}}/>
    <div style={{marginTop:100,fontWeight:700,fontSize:locale==='ja'?88:locale==='en'?100:110,lineHeight:1.2,letterSpacing:-4,
      opacity:interpolate(frame,[0,12],[0,1],{extrapolateRight:'clamp',extrapolateLeft:'clamp'}),translate:`0 ${interpolate(frame,[0,16],[30,0],{extrapolateRight:'clamp',extrapolateLeft:'clamp'})}px`}}>
      {(closing? (locale==='ko'?['야구 못하면','또 환생함']:locale==='en'?['Mound','Reborn']:['野球がダメなら','また転生']):shot.lines[locale]).map((line,i)=><div key={line} style={{whiteSpace:'nowrap',color:i===1&&!light?colors.lime:undefined}}>{line}</div>)}
    </div>
    <div style={{marginTop:54,fontSize:34,lineHeight:1.5,letterSpacing:-1,color:light?'#426344':'#BED5BC'}}>{closing?promise[locale]:shot.topic[locale]}</div>
    <div style={{display:'flex',gap:14,marginTop:104}}>{Array.from({length:8},(_,i)=><div key={i} style={{width:i===index?95:36,height:5,background:i===index?(light?colors.ink:colors.lime):(light?'#C5CBB4':'#547357')}}/>)}</div>
  </div>}
  {!landscape&&closing&&<div style={{position:'absolute',left:60,right:60,top:40,height:260,textAlign:'center',fontFamily:font(locale),color:colors.cream}}>
    {locale==='ko'?<CanvasImage src={staticFile('logo.png')} style={{position:'absolute',width:460,height:460,left:250,top:-120}}/>:<div style={{fontSize:locale==='en'?96:70,fontWeight:700,lineHeight:1.13,marginTop:32}}>{locale==='en'?<>Mound Reborn</>:<>野球がダメなら<br/>また転生</>}</div>}
    <div style={{position:'absolute',bottom:0,width:'100%',fontSize:locale==='en'?27:29,color:colors.lime}}>{promise[locale]}</div>
  </div>}
  <div style={{opacity:interpolate(frame,[0,9],[0,1],{extrapolateRight:'clamp',extrapolateLeft:'clamp'})}}>
   <AppFrame locale={locale} asset={shot.asset} width={appWidth} left={landscape?1320:130} top={landscape?72:332}
     scale={live?1:interpolate(frame,[0,130],[1,1.012],{extrapolateRight:'clamp'})}>
    {live?<Video src={staticFile(`captures/${locale}/pitch.mp4`)} muted style={{position:'absolute',top:-136*factor,left:0,width:appWidth,height:2160*factor}}/>:undefined}
   </AppFrame>
  </div>
 </AbsoluteFill>
};
