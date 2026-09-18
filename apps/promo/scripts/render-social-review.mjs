import path from 'node:path';import fs from 'node:fs/promises';
import {bundle} from '@remotion/bundler';import {openBrowser,selectComposition,renderStill,renderMedia} from '@remotion/renderer';
const cwd=process.cwd(),dest=path.resolve(cwd,'../../marketing/social/2026-09-review-led');
const serveUrl=await bundle({entryPoint:path.join(cwd,'src/social-review/index.tsx'),publicDir:path.join(cwd,'public/social-review'),outDir:path.join(cwd,'.social-review-bundle')});
const browser=await openBrowser('chrome');
const ids=process.env.SOCIAL_IDS?.split(',')??['SocialStory-ko','SocialStory-en','SocialStory-ja','SocialStory-Feed-ko','SocialProof-ko','SocialPlay-ko'];
try{for(const id of ids){const dir=path.join(dest,id);await fs.mkdir(dir,{recursive:true});const comp=await selectComposition({serveUrl,id,puppeteerInstance:browser});
 const frames=id.startsWith('SocialStory')?[30,120,210,315,420,530,695,810]:[30,110,280,390];
 for(const f of frames)await renderStill({composition:comp,serveUrl,puppeteerInstance:browser,frame:f,output:path.join(dir,`frame-${f}.jpg`),imageFormat:'jpeg'});
 await renderStill({composition:comp,serveUrl,puppeteerInstance:browser,frame:frames[0],output:path.join(dir,'cover.png'),imageFormat:'png'});
 console.log(`${id} stills done`);
 if(process.argv.includes('--preview'))continue;
 let last=-1;await renderMedia({composition:comp,serveUrl,puppeteerInstance:browser,outputLocation:path.join(dir,'mix.mp4'),codec:'h264',crf:18,pixelFormat:'yuv420p',audioCodec:'aac',concurrency:2,timeoutInMilliseconds:90000,onProgress:({progress})=>{let p=Math.floor(progress*5);if(p!==last){last=p;console.log(`${id} ${p*20}%`)}}});
}}finally{await browser.close({silent:true})}
