import React from 'react';
import {CanvasImage,staticFile,interpolate,useCurrentFrame} from 'remotion';
import {copy} from './copy';
import {Props,Shell,Title,palette,Fine} from './shared';
export const Close:React.FC<Props>=({lang})=>{const f=useCurrentFrame();return <Shell lang={lang}><Title lang={lang} lines={copy[lang].end} size={lang==='ko'?84:80}/>
 {lang==='ko'?<CanvasImage src={staticFile('logo.png')} style={{position:'absolute',top:175,left:142,width:560,height:560}}/>:<div data-key-text style={{position:'absolute',top:350,width:844,fontSize:lang==='en'?86:60,fontWeight:700,textAlign:'center',lineHeight:1.4}}>{copy[lang].brand}</div>}
 <div data-key-text style={{position:'absolute',top:700,left:0,width:844,background:palette.lime,color:palette.bg,borderRadius:15,padding:'30px 0',fontSize:46,fontWeight:700,textAlign:'center',scale:interpolate(f,[0,12],[.97,1],{extrapolateRight:'clamp'})}}>{copy[lang].cta} ↗</div>
 <Fine>{copy[lang].genre}</Fine></Shell>};
