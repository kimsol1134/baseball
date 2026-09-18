from pathlib import Path
from PIL import Image,ImageDraw
import subprocess,json,hashlib,zipfile,html
root=Path(__file__).resolve().parents[3];r=root/'marketing/social/2026-09-review-led'
names={'SocialStory-ko':'리뷰가 바꾼 야구 인생 · 한국어 30초','SocialStory-en':'Reviews changed the game · English 30s','SocialStory-ja':'レビューが変えた野球人生 · 日本語30秒','SocialStory-Feed-ko':'리뷰 본편 · Meta 피드 4:5','SocialProof-ko':'평점으로 시작하는 15초','SocialPlay-ko':'직접 투구로 시작하는 15초'}
subs={
'ko':['리뷰를 읽고, 게임을 바꿨습니다.','한국 App Store 4.5점 · 182개의 평가','“프로 데뷔한 순간부터 할게 아예 없음” — 실제 리뷰 일부','프로가 되어도, 내 선택은 계속. 시즌 결정과 선택 효과 안내 추가.','고르기 전에, 효과부터 확인.','키우기만? 직접 던져야지.','끝난 커리어도 다음 투수의 힘으로.','이번엔 어떤 투수로 살래? 야구 못하면 또 환생함. 내 투수 키우기.'],
'en':['You left feedback. We built on it.','4.5 / 5 · 182 ratings · Korean App Store','“Not enough to do after going pro.” — Review excerpt, translated','Go pro. Keep making choices. Season decisions and clearer effects.','See the effects. Make your choice.','Don’t just train. Throw the pitch.','One career ends. Your legacy stays.','Your next baseball life? Mound Reborn. Build your pitcher.'],
'ja':['レビューを読んで、ゲームを変えた。','韓国App Store · 4.5点 · 182件の評価','「プロ入りした後、やることがない。」レビュー抜粋・翻訳','プロになっても、選択は続く。シーズンの決断と効果の説明を追加。','効果を見て、自分で選ぶ。','育てるだけ？自分で投げよう。','終わった人生も、次の投手の力に。','次は、どんな投手になる？野球がダメならまた転生。']}
def timecode(sec):
 ms=round(sec*1000);return f'{ms//3600000:02}:{ms//60000%60:02}:{ms//1000%60:02},{ms%1000:03}'
manifest=[]
for id,title in names.items():
 d=r/id;duration=30 if id.startswith('SocialStory') else 15;src=d/'mix.mp4';dst=d/'ad.mp4'
 subprocess.run(['ffmpeg','-y','-v','error','-i',str(src),'-c:v','copy','-af','loudnorm=I=-16:TP=-1:LRA=9','-c:a','aac','-b:a','192k','-ar','48000','-t',str(duration),'-movflags','+faststart',str(dst)],check=True)
 probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(dst)]));v=next(s for s in probe['streams'] if s['codec_type']=='video');a=next(s for s in probe['streams'] if s['codec_type']=='audio')
 assert int(v['nb_frames'])==duration*30 and v['r_frame_rate']=='30/1' and v['codec_name']=='h264'
 assert (v['width'],v['height'])==(1080,1350 if 'Feed' in id else 1920)
 assert a['codec_name']=='aac' and a['sample_rate']=='48000' and abs(float(probe['format']['duration'])-duration)<.05
 (r/'evidence'/f'{id}-probe.json').write_text(json.dumps(probe,indent=2))
 lang=id.split('-')[-1];order=list(range(8)) if duration==30 else [1,5,6,7] if id=='SocialProof-ko' else [5,1,4,7];times=[0,3,6,9,13,16,22,25,30] if duration==30 else [0,2.5,8.5,11,15] if id=='SocialProof-ko' else [0,6,8.5,11,15]
 (d/'captions.srt').write_text('\n\n'.join(f'{i+1}\n{timecode(times[i])} --> {timecode(times[i+1])}\n{subs[lang][ix]}' for i,ix in enumerate(order))+'\n')
 sheet=Image.new('RGB',(1440,1280 if duration==30 else 640),'#17271c')
 for i,start in enumerate(times[:-1]):
  p=d/f'frame-{i:02}.jpg';subprocess.run(['ffmpeg','-y','-v','error','-ss',str(start+.8),'-i',str(dst),'-frames:v','1',str(p)],check=True)
  im=Image.open(p);im.thumbnail((350,620));sheet.paste(im,((i%4)*360,(i//4)*640));p.unlink()
 sheet.save(d/'contact-sheet.jpg',quality=92)
 im=Image.open(d/'cover.png').convert('RGB');im.save(d/'cover.png')
 safe=im.copy();draw=ImageDraw.Draw(safe);y=300 if v['height']==1920 else 110;draw.rectangle((86,y,930,y+930),outline='#ff55dd',width=5);safe.thumbnail((540,960));safe.save(d/'safe-zone-review.jpg')
 manifest.append({'id':id,'title':title,'path':str(dst.relative_to(r)),'width':v['width'],'height':v['height'],'duration':duration,'fps':30,'bytes':dst.stat().st_size,'sha256':hashlib.sha256(dst.read_bytes()).hexdigest()})
(r/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
page='''<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>리뷰가 바꾼 야구 인생 · Social Ads</title><style>body{font:17px system-ui;background:#0a2019;color:#fff6e2;max-width:1400px;margin:40px auto;padding:0 24px}h1{font-size:44px}p{line-height:1.7}a{color:#c6f65c}.grid{display:grid;grid-template-columns:repeat(3,1fr);gap:26px}video{width:100%;max-height:600px;background:#08150e}article{padding:18px;border:1px solid #3b5738;border-radius:16px}h2{font-size:20px}small{color:#a6bba3}@media(max-width:800px){.grid{grid-template-columns:1fr}}</style><h1>리뷰가 바꾼 야구 인생</h1><p>한국 App Store 4.5점 · 평가 182개 / 글 리뷰 48개 · 2026.09.10 확인<br>30초 스토리 × 3개 언어 + 15초 도입 비교 2편 + Meta 피드 4:5</p><p><a href="social-ads-ready.zip">업로드 패키지 ZIP</a> · <a href="AD_COPY.md">게시 문안</a> · <a href="claims.json">수치 근거</a> · <a href="REFERENCES.md">참고 사례</a></p><div class="grid">'''
for m in manifest:
 id=m['id'];page+=f'<article><h2>{html.escape(m["title"])}</h2><video controls preload="metadata" poster="{id}/cover.png" src="{id}/ad.mp4"></video><p><a href="{id}/ad.mp4">MP4</a> · <a href="{id}/captions.srt">SRT</a> · <a href="{id}/cover.png">커버</a> · <a href="{id}/contact-sheet.jpg">전체 장면</a></p><small>{m["width"]}×{m["height"]} · {m["duration"]}s · {m["bytes"]/1024/1024:.1f}MB</small></article>'
page+='</div><p>음악·효과음·화면 문구로 구성. 실제 Android 화면을 사용했으며, 평점은 한국 iOS App Store의 별도 수치입니다. SNS 게시·광고 집행은 하지 않았습니다.</p>'
(r/'review.html').write_text(page)
with zipfile.ZipFile(r/'social-ads-ready.zip','w',zipfile.ZIP_DEFLATED) as z:
 for id in names:
  for file in ['ad.mp4','cover.png','captions.srt']:z.write(r/id/file,f'{id}/{file}')
 for file in ['AD_COPY.md','README.md','CREDITS.md','claims.json','manifest.json']:z.write(r/file,file)
print(json.dumps({'videos':len(manifest),'totalSeconds':sum(v['duration'] for v in manifest),'zipMB':round((r/'social-ads-ready.zip').stat().st_size/1024/1024,1)}))
