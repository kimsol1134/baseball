from pathlib import Path
from PIL import Image
p=Path(__file__).resolve().parent
exec((p.parent/'2026-09-14-review-captures/build.py').read_text().split('for name,H')[0])
out=p
# Crop the second supplied screenshot above its clipped body; retain the full review title and attribution.
im=Image.open(p/'sources/revolution-original.png');im.crop((0,0,im.width,174)).save(p/'sources/revolution-title.png')
s='<svg xmlns="http://www.w3.org/2000/svg" width="1080" height="1350"><rect width="1080" height="1350" fill="#10271e"/>'
s+=text('야구 못하면 또 환생함',64,92,32,'#f3efdf')
s+=text('직접 해본 유저들의',60,221,68,'#f3efdf')
s+=text('한마디.',60,330,94,'#bdf56a')
s+='<rect x="48" y="412" width="984" height="380" rx="26" fill="white"/>'
s+=picture(p/'sources/simple-original.png',90,445,690,339)
s+='<rect x="48" y="832" width="984" height="250" rx="26" fill="white"/>'
s+=picture(p/'sources/revolution-title.png',72,847,936,209)
s+=text('직접 던지는 투수 성장 RPG',64,1170,32,'#bdf56a')
s+=text('한국 App Store 리뷰 제목 발췌 · 원본 캡처',64,1241,24,'#c2ccbf')
s+=text('원문에는 버그 제보와 콘텐츠 개선 요청도 포함되어 있습니다.',64,1291,20,'#c2ccbf')
s+='</svg>'
(p/'review-highlights.svg').write_text(s)
