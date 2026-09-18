from pathlib import Path
import json
p=Path(__file__).resolve().parent
# Reuse the established vector lettering helper without executing prior layouts.
exec((p/'build.py').read_text().split('for name,H')[0])
review=next(r for r in json.loads((p/'sources/reviews-current.json').read_text())['reviews'] if r['reviewerNickname']=='겜동진132')
quote='제일 좋은 점은 회차가 쌓이면 쌓일수록 그만큼 스탯이 쌓이면서 더 쉬워지는 점이 좋은거 같습니다.'
assert quote in review['body']
(p/'selected-review.json').write_text(json.dumps({'review':review,'quote':quote,'presentation':'원문 인용 카드, App Store UI 캡처 아님'},ensure_ascii=False,indent=2))
for name,H in [('growth-review-feed',1350),('growth-review-story',1920)]:
 story=H==1920; sy=100 if story else 70
 s=f'<svg xmlns="http://www.w3.org/2000/svg" width="1080" height="{H}"><rect width="1080" height="{H}" fill="#10271e"/>'
 s+=text('야구 못하면 또 환생함',64,sy,28,'#f4efdf')
 s+=text('회차가 쌓일수록,',64,sy+120,74,'#f4efdf')
 s+=text('내 투수는 더 강하게.',64,sy+218,74,'#bdf56a')
 y=sy+280
 s+=f'<rect x="64" y="{y}" width="952" height="386" rx="26" fill="#f3efdf"/>'
 s+=text('별점 5 / 5  ·  “재밌다”',98,y+59,28,'#365335')
 lines=['“제일 좋은 점은 회차가 쌓이면 쌓일수록','그만큼 스탯이 쌓이면서 더 쉬워지는 점이','좋은거 같습니다.”']
 for i,line in enumerate(lines):s+=text(line,98,y+139+i*59,36,'#10271e')
 s+=text('겜동진132 · 한국 App Store · 2026.09.01',98,y+321,23,'#526451')
 s+=text('실제 리뷰 본문 일부 인용',98,y+358,20,'#526451')
 b=y+439
 s+=text('이번 생의 성장이',64,b+55,39,'#f3efdf')
 s+=text('다음 도전의 힘으로!',64,b+111,39,'#bdf56a')
 s+=text('내 손으로 던지고,',64,b+203,28,'#f3efdf')
 s+=text('나만의 에이스를 키우세요.',64,b+248,28,'#f3efdf')
 ph=780 if story else 440; pw=390 if story else 220
 s+=picture(root/'apps/promo/public/play-2026-09/captures/ko/legacy.png',1020-pw,b,pw,ph)
 footer=H-130
 s+=text('안드로이드에서도 즐겨보세요!',64,footer,32,'#bdf56a')
 s+=text('리뷰: iOS 이용자 · 게임 화면: Android',64,footer+49,21,'#c2ccbf')
 s+='</svg>'
 (p/f'{name}.svg').write_text(s)
