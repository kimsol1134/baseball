import React from 'react';
import {copy} from './copy';
import {Props,Shell,Title,Fine,Crop} from './shared';
export const Pitch:React.FC<Props>=({lang})=><Shell lang={lang}><Title lang={lang} lines={copy[lang].pitch}/><Crop lang={lang} asset="pitch" live sourceY={1200} width={760} top={280} h={595} zoom={false}/><Fine>{copy[lang].ui} · {copy[lang].pitchSub}</Fine></Shell>;
