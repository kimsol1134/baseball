import path from 'node:path';
import fs from 'node:fs/promises';
import {bundle} from '@remotion/bundler';
import {openBrowser,selectComposition,renderStill,renderMedia} from '@remotion/renderer';
const cwd=process.cwd();
const dest=path.resolve(cwd,'../../marketing/google-play/2026-09-production');
const serveUrl=await bundle({entryPoint:path.join(cwd,'src/play-2026-09/index.tsx'),publicDir:path.join(cwd,'public/play-2026-09'),outDir:path.join(cwd,'.play-store-bundle')});
const browser=await openBrowser('chrome');
const langs=process.env.PLAY_LOCALES?.split(',')??['ko','en','ja'];
const folders={ko:'ko-KR',en:'en-US',ja:'ja-JP'};
const onlyStills=process.argv.includes('--stills');const preview=process.argv.includes('--preview');const onlyVideos=process.argv.includes('--videos');
try {
 for(const locale of langs){
  const dir=path.join(dest,folders[locale]);await fs.mkdir(path.join(dir,'screenshots'),{recursive:true});
  if(!onlyVideos){
   const shots=await selectComposition({serveUrl,id:`PlayShots-${locale}`,puppeteerInstance:browser});
   for(const frame of preview?[0,2,4]:[0,1,2,3,4,5,6,7]){
    await renderStill({composition:shots,serveUrl,puppeteerInstance:browser,frame,output:path.join(dir,'screenshots',`${String(frame+1).padStart(2,'0')}.png`),imageFormat:'png'});
    console.log(`Screenshot ${locale} ${frame+1}/8`);
   }
   for(const [id,name] of [['Feature','feature-graphic.png'],['Thumbnail','youtube-thumbnail.png']]){
    const composition=await selectComposition({serveUrl,id:`Play${id}-${locale}`,puppeteerInstance:browser});
    await renderStill({composition,serveUrl,puppeteerInstance:browser,output:path.join(dir,name),imageFormat:'png'});
   }
  }
  if(!onlyStills&&!preview){
   for(const layout of ['Portrait','Landscape']){
    const composition=await selectComposition({serveUrl,id:`PlayTrailer-${layout}-${locale}`,puppeteerInstance:browser});let last=-1;
    await renderMedia({composition,serveUrl,puppeteerInstance:browser,outputLocation:path.join(dir,`trailer-${layout.toLowerCase()}-mix.mp4`),codec:'h264',crf:18,pixelFormat:'yuv420p',audioCodec:'aac',audioBitrate:'192k',concurrency:2,timeoutInMilliseconds:90000,onProgress:({progress})=>{const p=Math.floor(progress*10);if(p!==last){last=p;console.log(`${locale} ${layout} ${p*10}%`);}}});
   }
  }
 }
}finally{await browser.close({silent:true});}
