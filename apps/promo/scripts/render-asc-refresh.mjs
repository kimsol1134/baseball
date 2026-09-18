import path from 'node:path';
import fs from 'node:fs/promises';
import {bundle} from '@remotion/bundler';
import {openBrowser,selectComposition,renderStill,renderMedia} from '@remotion/renderer';

const app=process.cwd();
const output=path.resolve(app,'../../marketing/appstore/2026-09-refresh');
const serveUrl=await bundle({entryPoint:path.join(app,'src/asc-2026-09/index.tsx'),publicDir:path.join(app,'public/asc-2026-09'),outDir:'/tmp/baseball-asc-refresh-bundle'});
const browser=await openBrowser('chrome');
const locales=(process.env.ASC_LOCALES??'ko,en,ja').split(',');
const folders={ko:'ko-KR',en:'en-US',ja:'ja-JP'};
const sample=process.argv.includes('--sample');
const videosOnly=process.argv.includes('--videos');
const stillsOnly=process.argv.includes('--stills')||sample;
try {
 for(const locale of locales){
  const dir=path.join(output,folders[locale]);
  if(!videosOnly){
   for(const size of sample?['69']:['69','65']){
    const composition=await selectComposition({serveUrl,id:`ASCRefreshShots${size}-${locale}`,puppeteerInstance:browser});
    const dest=path.join(dir,size==='69'?'screenshots-6.9':'screenshots-6.5');await fs.mkdir(dest,{recursive:true});
    for(const frame of sample?[0,1,3,5]:[0,1,2,3,4,5,6,7]){
     await renderStill({composition,serveUrl,puppeteerInstance:browser,frame,output:path.join(dest,`${String(frame+1).padStart(2,'0')}.png`),imageFormat:'png'});
     console.log(`STILL ${locale} ${size} ${frame+1}/8`);
    }
   }
  }
  if(!stillsOnly){
   const composition=await selectComposition({serveUrl,id:`ASCRefreshPreview-${locale}`,puppeteerInstance:browser});
   const dest=path.join(dir,'preview');await fs.mkdir(dest,{recursive:true});let last=-1;
   await renderMedia({composition,serveUrl,puppeteerInstance:browser,outputLocation:path.join(dest,`app-preview-${locale}-886x1920.mp4`),codec:'h264',videoBitrate:'10M',pixelFormat:'yuv420p',audioCodec:'aac',audioBitrate:'256k',sampleRate:48000,concurrency:2,timeoutInMilliseconds:90000,onProgress:({progress})=>{const p=Math.floor(progress*10);if(p!==last){last=p;console.log(`VIDEO ${locale} ${p*10}%`);}}});
   await renderStill({composition,serveUrl,puppeteerInstance:browser,frame:45,output:path.join(dest,'poster.png'),imageFormat:'png'});
  }
 }
}finally{await browser.close({silent:true});}
