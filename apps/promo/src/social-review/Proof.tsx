import React from 'react';
import {copy} from './copy';
import {Props,Shell,palette,Fine} from './shared';
export const Proof:React.FC<Props>=({lang})=><Shell lang={lang} stamp={copy[lang].proof}>
 <div data-key-text style={{position:'absolute',top:70,fontSize:290,fontWeight:700,lineHeight:1,letterSpacing:-20}}>4.5<span style={{fontSize:55,letterSpacing:0,color:palette.muted}}>/ 5</span></div>
 <svg width="630" height="100" style={{position:'absolute',top:395,left:0}} viewBox="0 0 630 100"><defs><clipPath id="half"><rect width="555" height="100"/></clipPath></defs>{[false,true].map((filled)=><g key={String(filled)} fill={filled?palette.gold:'#344F3E'} clipPath={filled?'url(#half)':undefined}>{[0,1,2,3,4].map(i=><path key={i} transform={`translate(${i*126},0)`} d="M50 0 L63 34 L100 37 L72 61 L81 98 L50 78 L19 98 L28 61 L0 37 L37 34 Z"/>)}</g>)}</svg>
 <div data-key-text style={{position:'absolute',top:560,fontSize:lang==='ko'?70:74,fontWeight:700,letterSpacing:-3}}>{copy[lang].ratings}</div>
 <div style={{position:'absolute',top:710,width:844,height:2,background:'#60834C'}}/>
 <Fine>{copy[lang].date}</Fine></Shell>;
