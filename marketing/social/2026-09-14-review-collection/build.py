from pathlib import Path
import json,base64
from datetime import datetime
from zoneinfo import ZoneInfo
p=Path(__file__).resolve().parent
src=p.parent/'2026-09-14-review-captures'
exec((src/'build.py').read_text().split('for name,H')[0])
out=p
reviews=json.loads((src/'sources/reviews-current.json').read_text())['reviews']
chosen=[next(r for r in reviews if r['reviewerNickname']==n) for n in ['겜동진132','성주야','greenflum']]
(p/'reviews.json').write_text(json.dumps(chosen,ensure_ascii=False,indent=2))
# Use the exact source title and body, wrapping only at spaces.
def wrap(s,size,width):
 def widthof(t):return sum(size*.3 if c==' ' else glyphs[cmap.get(ord(c),'.notdef')].width*size/upm for c in t)
 lines=[];line=''
 for w in s.split(' '):
  v=(line+' '+w).strip()
  if widthof(v)>width and line:lines.append(line);line=w
  else:line=v
 if line:lines.append(line)
 return lines
s='<svg xmlns="http://www.w3.org/2000/svg" width="1080" height="1350"><rect width="1080" height="1350" fill="#eeeade"/>'
s+=text('야구 못하면 또 환생함',64,78,29,'#254632')
s+=text('직접 해본 분들은',60,160,63,'#10271e')+text('이렇게 남겨주셨습니다.',60,237,63,'#10271e')
s+=text('한국 App Store 실제 이용자 리뷰 3선',64,290,24,'#536253')
y=326
for i,r in enumerate(chosen):
 title=wrap(r['title'],30,870); body=wrap(r['body'],26,870)
 h=113+len(title)*42+len(body)*40
 s+=f'<rect x="56" y="{y}" width="968" height="{h}" rx="22" fill="#ffffff"/>'
 date=datetime.fromisoformat(r['createdDate']).astimezone(ZoneInfo('Asia/Seoul')).strftime('%Y.%m.%d')
 s+=text('별점 5 / 5',86,y+45,23,'#ac731f')
 s+=text(r['reviewerNickname']+' · '+date,420,y+45,21,'#657064')
 yy=y+94
 for line in title:s+=text(line,86,yy,30,'#10271e');yy+=42
 yy+=3
 for line in body:s+=text(line,86,yy,26,'#3b483d');yy+=40
 y+=h+22
s+=text('칭찬도, 바라는 점도. 남겨주신 이야기를 담았습니다.',64,1265,23,'#254632')
s+=text('리뷰 제목·본문 전문 재배치 · 원문 확인 2026.09.14 · iOS 이용자 리뷰',64,1312,18,'#657064')
s+='</svg>'
assert y<1250,y
(p/'reviews-feed.svg').write_text(s)
print('cards end',y)
