import React from 'react';
import {interpolate,useCurrentFrame} from 'remotion';
import {copy} from './copy';
import {Props,Shell,Title,palette,Fine} from './shared';
export const Hook:React.FC<Props>=({lang})=>{const f=useCurrentFrame();return <Shell lang={lang}><Title lang={lang} lines={copy[lang].hook} size={lang==='ko'?82:78}/>
 <div style={{position:'absolute',top:370,width:844,height:300,perspective:900}}>{[0,1,2].map((n)=><div key={n} style={{position:'absolute',top:n*25,left:n*22,width:770,height:240,background:n===2?palette.cream:'#2C4C3B',border:'2px solid #B6CA98',borderRadius:22,rotate:`${(n-1)*4}deg`,translate:`${interpolate(f,[0,22],[120+n*90,0],{extrapolateRight:'clamp'})}px 0`,boxShadow:'0 12px 30px #0005',padding:35,boxSizing:'border-box',color:palette.bg}}>{n===2?<><div style={{fontSize:29,marginBottom:24,color:'#587048'}}>APP STORE · FEEDBACK</div><div style={{fontSize:52,fontWeight:700}}>48</div><div style={{position:'absolute',left:140,top:122,fontSize:30}}>{lang==='ko'?'개의 글 리뷰':lang==='en'?'written reviews':'件の文章レビュー'}</div></>:null}</div>)}</div>
 <div style={{position:'absolute',top:752,width:interpolate(f,[25,55],[0,844],{extrapolateLeft:'clamp',extrapolateRight:'clamp'}),height:9,background:palette.lime}}/>
 <Fine>{lang==='ko'?'ASC API 조회 · 2026.09.10':lang==='en'?'ASC API · Sep 10, 2026':'ASC API取得 · 2026.09.10'}</Fine></Shell>};
