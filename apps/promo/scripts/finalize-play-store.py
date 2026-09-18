from pathlib import Path
from PIL import Image
import subprocess,json,hashlib,zipfile,html
r=Path(__file__).resolve().parents[3]/'marketing/google-play/2026-09-production'
copies=json.loads((r/'listing-copy.json').read_text())
manifest=[]
for loc,copy in copies.items():
 d=r/loc
 for p in list((d/'screenshots').glob('*.png'))+[d/'feature-graphic.png',d/'youtube-thumbnail.png']:
  im=Image.open(p).convert('RGB');im.save(p)
 for layout in ['portrait','landscape']:
  src=d/f'trailer-{layout}-mix.mp4';dst=d/f'trailer-{layout}.mp4'
  subprocess.run(['ffmpeg','-y','-v','error','-i',str(src),'-c:v','copy','-af','loudnorm=I=-16:TP=-1:LRA=9','-c:a','aac','-b:a','192k','-ar','48000','-t','30','-movflags','+faststart',str(dst)],check=True)
  probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(dst)]))
  video=next(s for s in probe['streams'] if s['codec_type']=='video')
  assert video['codec_name']=='h264' and video['nb_frames']=='900' and video['r_frame_rate']=='30/1'
  assert (video['width'],video['height'])==((1080,1920) if layout=='portrait' else (1920,1080))
  assert abs(float(probe['format']['duration'])-30)<.1
  (r/'sources'/f'{loc}-{layout}-probe.json').write_text(json.dumps(probe,indent=2))
  frames=[]
  for i,t in enumerate([1,7,11,15,18,22,26,29]):
   p=r/'sources'/f'{loc}-{layout}-frame-{i}.jpg'
   subprocess.run(['ffmpeg','-y','-v','error','-ss',str(t),'-i',str(dst),'-frames:v','1',str(p)],check=True)
   im=Image.open(p);im.thumbnail((384,384));frames.append(im.copy());p.unlink()
  sheet=Image.new('RGB',(1536,800),'#eee9df')
  for i,im in enumerate(frames):sheet.paste(im,((i%4)*384,(i//4)*400))
  sheet.save(d/f'video-contact-{layout}.jpg',quality=90)
 (d/'screenshot-alt-text.json').write_text(json.dumps(json.loads((r/'screenshot-alt-text.json').read_text())[loc],ensure_ascii=False,indent=2))
 (d/'store-listing.txt').write_text(copy['title']+'\n\n'+copy['shortDescription']+'\n\n'+copy['fullDescription'])
 for p in sorted(d.rglob('*')):
  if not p.is_file() or '-mix.' in p.name:continue
  entry={'file':str(p.relative_to(r)),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
  if p.suffix=='.png':
   im=Image.open(p);entry.update(width=im.width,height=im.height,mode=im.mode)
   assert im.mode=='RGB'
   assert p.stat().st_size < (15 if p.name=='feature-graphic.png' else 8)*1024*1024
  manifest.append(entry)
 with zipfile.ZipFile(r/f'play-store-{loc}.zip','w',zipfile.ZIP_DEFLATED) as z:
  for p in sorted(d.rglob('*')):
   if p.is_file() and '-mix.' not in p.name and 'contact' not in p.name:z.write(p,p.relative_to(r))
  for shared in ['CREDITS.md','README.md']:z.write(r/shared,shared)
(r/'upload-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
page='''<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Play Store · 3 languages</title><style>body{background:#10231b;color:#f5efdf;font:17px system-ui;margin:40px auto;max-width:1400px;padding:0 24px}h1{font-size:42px}section{margin:60px 0}p{line-height:1.7;max-width:900px}a{color:#c2f575}.shots{display:grid;grid-template-columns:repeat(4,1fr);gap:16px}.shots img{width:100%}.videos{display:flex;gap:24px;align-items:start}video{max-width:65%;max-height:620px;background:#000}details{padding:20px;border:1px solid #426b4e;white-space:pre-wrap}nav{display:flex;gap:30px}@media(max-width:700px){.shots{grid-template-columns:repeat(2,1fr)}.videos{display:block}video{max-width:100%}}</style><h1>한 구는 손끝으로, 인생은 내 선택으로</h1><p>실제 Android 게임 화면 · Remotion 30초 영상 · 한국어 / English / 日本語</p><nav>'''
for loc in copies:page+=f'<a href="#{loc}">{loc}</a>'
page+='</nav>'
for loc,c in copies.items():
 page+=f'<section id="{loc}"><h2>{html.escape(c["title"])}</h2><p>{html.escape(c["shortDescription"])}</p><p><a href="play-store-{loc}.zip">{loc} ZIP</a> · <a href="{loc}/feature-graphic.png">Feature graphic</a> · <a href="{loc}/store-listing.txt">Store copy</a></p><div class="videos">'
 for layout in ['portrait','landscape']:page+=f'<video controls preload="metadata" src="{loc}/trailer-{layout}.mp4"></video>'
 page+='</div><div class="shots">'
 for n in range(1,9):page+=f'<a href="{loc}/screenshots/{n:02}.png"><img loading="lazy" alt="{loc} screenshot {n}" src="{loc}/screenshots/{n:02}.png"></a>'
 page+=f'</div><details><summary>Full description</summary>{html.escape(c["fullDescription"])}</details></section>'
(r/'review.html').write_text(page)
print(json.dumps({'verified_files':len(manifest),'root':str(r)}))
