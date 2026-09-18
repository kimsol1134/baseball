import React from 'react';
import {copy} from './copy';
import {Props,Shell,Title,Fine,Crop,Sub} from './shared';
export const Legacy:React.FC<Props>=({lang})=><Shell lang={lang}><Title lang={lang} lines={copy[lang].legacy} size={lang==='ko'?80:78}/><Crop lang={lang} asset="legacy" sourceY={980} h={480}/><Sub>{copy[lang].legacySub}</Sub><Fine>{copy[lang].ui}</Fine></Shell>;
