from pathlib import Path
from PIL import Image
p=Path(__file__).resolve().parent
exec((p.parent/'2026-09-14-review-captures/build.py').read_text().split('for name,H')[0])
out=p
s='<svg xmlns="http://www.w3.org/2000/svg" width="1080" height="1350"><rect width="1080" height="1350" fill="#eeeade"/>'
s+=text('야구 못하면 또 환생함',64,80,29,'#254632')
s+=text('직접 해본 분들은',64,176,64,'#10271e')+text('이렇게 남겨주셨습니다.',64,259,64,'#10271e')
s+=text('한국 App Store 이용자 리뷰 · 실제 화면 캡처',64,314,24,'#536253')
y=352
for name,bottom in [('growth',440),('batter',431),('fan',440)]:
 im=Image.open(p/'originals'/f'{name}.png').crop((890,335,1278,bottom))
 dest=p/'originals'/f'{name}-crop.png';im.save(dest)
 h=round(im.height*952/im.width)
 s+=f'<rect x="48" y="{y-16}" width="984" height="{h+32}" rx="20" fill="white"/>'
 s+=picture(dest,64,y,952,h)
 y+=h+45
s+=text('리뷰의 별점·제목·작성자·본문을 그대로 담았습니다.',64,1262,22,'#254632')
s+=text('App Store Connect 원본 캡처 · 2026.09.14 · iOS 이용자 리뷰',64,1310,19,'#657064')
s+='</svg>'
(p/'reviews-original-captures.svg').write_text(s)
