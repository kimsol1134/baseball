const sharp=require('../../../node_modules/sharp');const path=require('path');
(async()=>{for(const name of ['review-feed','review-story'])await sharp(path.join(__dirname,name+'.svg')).flatten({background:'#10271e'}).png().toFile(path.join(__dirname,name+'.png'));await sharp(path.join(__dirname,'review-feed.png')).resize(648,810).jpeg({quality:95}).toFile(path.join(__dirname,'preview.jpg'));})();
