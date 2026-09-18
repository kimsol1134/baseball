import React from 'react';
import {AbsoluteFill,useCurrentFrame} from 'remotion';
import {shots,Locale} from './copy';
import {Field,AppFrame,Headline,colors,font} from './visual';
export const Screenshots:React.FC<{locale:Locale}>=({locale})=>{
 const index=Math.min(7,useCurrentFrame());const shot=shots[index];const light=[1,4,7].includes(index);
 return <AbsoluteFill style={{background:light?colors.cream:colors.forest}}>
  <Field light={light}/>
  <Headline locale={locale} topic={shot.topic[locale]} lines={shot.lines[locale]} light={light}/>
  <AppFrame locale={locale} asset={shot.asset} width={860} left={110} top={318}/>
  <div style={{position:'absolute',left:16,bottom:25,fontFamily:font(locale),fontSize:16,color:light?'#748163':'#8BAD74',writingMode:'vertical-rl',letterSpacing:3}}>{String(index+1).padStart(2,'0')} / 08</div>
 </AbsoluteFill>
};
