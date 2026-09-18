import React from 'react';
import {copy} from './copy';
import {Props,Shell,Title,Fine,palette} from './shared';
export const Review:React.FC<Props>=({lang})=><Shell lang={lang} light stamp={lang==='ko'?'그중, 이런 아쉬움도 있었습니다.':lang==='en'?'THE FEEDBACK MATTERED.':'こんな声も、届いていました。'}>
 <div style={{position:'absolute',fontSize:280,top:20,color:'#CBD8AF',fontFamily:'Georgia'}}>“</div>
 <Title lang={lang} lines={copy[lang].review} light size={lang==='ko'?73:78} top={300}/>
 <div style={{position:'absolute',top:560,height:15,width:780,background:'#D5E889'}}/>
 <Fine light>{copy[lang].reviewNote}</Fine></Shell>;
