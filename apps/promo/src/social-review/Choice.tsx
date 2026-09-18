import React from 'react';
import {copy} from './copy';
import {Props,Shell,Title,Fine,Crop,Sub} from './shared';
export const Choice:React.FC<Props>=({lang})=><Shell lang={lang}><Title lang={lang} lines={copy[lang].choice}/><Crop lang={lang} asset="conversation" sourceY={1080} h={480}/><Sub>{copy[lang].choiceSub}</Sub><Fine>{copy[lang].ui}</Fine></Shell>;
