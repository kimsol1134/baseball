#!/usr/bin/env python3
"""Validate upload dimensions/codecs and build contact sheets from the final assets."""
import hashlib
import json
import pathlib
import subprocess
import sys
from PIL import Image, ImageDraw

repo=pathlib.Path(__file__).resolve().parents[3]
root=repo/'marketing/appstore/2026-09-refresh'
evidence=root/'evidence';evidence.mkdir(exist_ok=True)
manifest={'remotionVersion':'4.0.499','screenshots':[],'previews':[],'submission':'not submitted'}
for locale,folder in [('ko','ko-KR'),('en','en-US'),('ja','ja-JP')]:
    if len(sys.argv)>1 and locale not in sys.argv[1:]: continue
    for size,dims in [('6.9',(1320,2868)),('6.5',(1284,2778))]:
        paths=sorted((root/folder/f'screenshots-{size}').glob('*.png'))
        assert len(paths)==8,(folder,size,len(paths))
        for p in paths:
            with Image.open(p) as im:
                assert im.size==dims,(p,im.size)
                if im.mode=='RGBA':
                    assert im.getchannel('A').getextrema()==(255,255),p
                    im.convert('RGB').save(p)
                else: assert im.mode=='RGB',(p,im.mode)
            manifest['screenshots'].append({'locale':locale,'size':size,'path':str(p.relative_to(root)),
                'width':dims[0],'height':dims[1],'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
        if size=='6.9':
            sheet=Image.new('RGB',(4*264,2*598),'#e9e5dd');draw=ImageDraw.Draw(sheet)
            for i,p in enumerate(paths):
                im=Image.open(p);im.thumbnail((264,574));x=i%4*264;y=i//4*598
                sheet.paste(im,(x,y));draw.text((x+8,y+578),f'{i+1:02d}  {locale}',fill='#19291f')
            sheet.save(evidence/f'{locale}-screenshots-contact.jpg',quality=92)
    p=root/folder/'preview'/f'app-preview-{locale}-886x1920.mp4'
    meta=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(p)]))
    v=next(s for s in meta['streams'] if s['codec_type']=='video');a=next(s for s in meta['streams'] if s['codec_type']=='audio')
    assert (v['width'],v['height'])==(886,1920)
    assert v['codec_name']=='h264' and v['pix_fmt']=='yuv420p' and v['r_frame_rate']=='30/1'
    assert a['codec_name']=='aac' and int(a['sample_rate'])==48000 and a['channels']==2
    assert abs(float(meta['format']['duration'])-28)<.1
    assert p.stat().st_size<500_000_000
    poster=p.parent/'poster.png'
    subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-ss','1.5','-i',str(p),'-frames:v','1',str(poster)],check=True)
    manifest['previews'].append({'locale':locale,'path':str(p.relative_to(root)),'duration':meta['format']['duration'],
        'videoCodec':v['codec_name'],'audioCodec':a['codec_name'],'sampleRate':a['sample_rate'],'bytes':p.stat().st_size,
        'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'posterTime':'00:00:01.500',
        'poster':str(poster.relative_to(root)),'posterSha256':hashlib.sha256(poster.read_bytes()).hexdigest()})
    sheet=Image.new('RGB',(4*222,2*510),'#e9e5dd');draw=ImageDraw.Draw(sheet)
    for i,t in enumerate([1.5,6,9.5,12.5,16,19.5,23,26]):
        frame=evidence/f'{locale}-frame-{i}.png'
        subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-ss',str(t),'-i',str(p),'-frames:v','1',str(frame)],check=True)
        im=Image.open(frame);im.thumbnail((222,481));x=i%4*222;y=i//4*510
        sheet.paste(im,(x,y));draw.text((x+8,y+487),f'{t:.1f}s',fill='#19291f');frame.unlink()
    sheet.save(evidence/f'{locale}-preview-contact.jpg',quality=92)
(root/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
print(f"Verified {len(manifest['screenshots'])} RGB screenshots and {len(manifest['previews'])} previews")
