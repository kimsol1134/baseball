import React from 'react';
import {copy} from './copy';
import {Props,Shell,Title,Fine,Crop,Sub} from './shared';
export const Response:React.FC<Props>=({lang})=><Shell lang={lang} stamp={copy[lang].update}><Title lang={lang} lines={copy[lang].reply}/><Crop lang={lang} asset="conversation" sourceY={650} h={480}/><Sub>{copy[lang].replySub}</Sub><Fine>{copy[lang].ui}</Fine></Shell>;
