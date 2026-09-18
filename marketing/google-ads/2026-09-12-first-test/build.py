from pathlib import Path
import subprocess,json
from PIL import Image,ImageDraw,ImageFont
from fontTools.ttLib import TTFont
p=Path(__file__).resolve().parent;r=p.parents[2]
s=r/'apps/promo/public/play-2026-09'; captures=s/'captures/ko'
f=TTFont(s/'fonts/GmarketSansBold.woff');f.flavor=None;f.save(p/'GmarketSansBold.ttf')
def run(a):subprocess.run(a,check=True)
def card(name,lines,asset=None):
 im=Image.new('RGB',(1080,1920),'#10271e');d=ImageDraw.Draw(im)
 def txt(t,y,size,c='#f4efdf'):
  font=ImageFont.truetype(str(p/'GmarketSansBold.ttf'),size); widths=[size*.3 if c==' ' else font.getlength(c) for c in t]
  assert sum(widths)<=960,(t,sum(widths))
  x=(1080-sum(widths))/2
  for ch,w in zip(t,widths):
   if ch!=' ':d.text((x,y),ch,font=font,fill=c)
   x+=w
 txt('야구 못하면 또 환생함',70,35)
 for i,l in enumerate(lines):txt(l,155+i*85,65,'#bdf56a' if i==1 else '#f4efdf')
 if asset:
  shot=Image.open(captures/(asset+'.png')).convert('RGB').crop((0,136,1080,2026)).resize((780,1365))
  im.paste(shot,(150,340))
 txt('Android · 4,400원 한 번 구매',1745,39,'#bdf56a')
 txt('광고 · 인앱 구매 없음',1810,31)
 im.save(p/(name+'.png'))
card('hook-a',['답답해서 내가 던진다!','타이밍은 내 손으로.'])
card('hook-b',['4,400원 한 번이면 끝.','광고도 추가 결제도 없이.'])
card('training',['내가 바라던 에이스,','내 손으로 키워보세요.'],'training')
card('rebirth',['이번 생이 끝나도','다시 마운드로!'],'legacy')
card('cta',['직접 던지는 투수 RPG','안드로이드에서 만나보세요!'],'pitch')
base=['ffmpeg','-hide_banner','-loglevel','error','-y']
for v in ['a','b']:
 run(base+['-loop','1','-i',str(p/f'hook-{v}.png'),'-i',str(captures/'pitch.mp4'),'-filter_complex','[1:v]crop=1080:1890:0:136,scale=780:1365[v];[0:v][v]overlay=150:340:shortest=1,format=yuv420p[o]','-map','[o]','-t','4.7','-r','30','-c:v','libx264','-preset','fast','-crf','20','-an',str(p/f'clip-{v}.mp4')])
for n,t in [('training','3.7'),('rebirth','4'),('cta','5.6')]:
 run(base+['-loop','1','-i',str(p/(n+'.png')),'-t',t,'-r','30','-c:v','libx264','-preset','fast','-crf','20','-pix_fmt','yuv420p','-an',str(p/(n+'.mp4'))])
for v in ['a','b']:
 (p/f'concat-{v}.txt').write_text('\n'.join("file '"+str(p/x)+"'" for x in [f'clip-{v}.mp4','training.mp4','rebirth.mp4','cta.mp4']))
 run(base+['-f','concat','-safe','0','-i',str(p/f'concat-{v}.txt'),'-i',str(s/'original-score.wav'),'-map','0:v','-map','1:a','-c:v','copy','-af','volume=0.35,afade=t=in:d=0.2,afade=t=out:st=16.8:d=1.2','-c:a','aac','-b:a','160k','-t','18','-movflags','+faststart',str(p/f'ad-{v}.mp4')])
run(base+['-i',str(p/'ad-a.mp4'),'-vf','fps=1/3,scale=270:-1,tile=6x1','-frames:v','1',str(p/'preview.jpg')])
