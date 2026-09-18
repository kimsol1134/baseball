const sharp=require('../../../node_modules/sharp');
const path=require('path');
const dir=__dirname;
(async()=>{const names=['01-pitch','02-growth','03-rebirth'];for(const name of names) await sharp(path.join(dir,name+'.svg')).png().toFile(path.join(dir,name+'.png')); const imgs=await Promise.all(names.map(async (n,i)=>({input:await sharp(path.join(dir,n+'.png')).resize(360,450).toBuffer(),left:i*360,top:0}))); await sharp({create:{width:1080,height:450,channels:3,background:'#10271e'}}).composite(imgs).jpeg({quality:92}).toFile(path.join(dir,'preview.jpg'));})();
