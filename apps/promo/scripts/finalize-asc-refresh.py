#!/usr/bin/env python3
"""Make Rec.709 limited-range App Store delivery files from the Remotion renders."""
import json
import pathlib
import subprocess
import sys
repo=pathlib.Path(__file__).resolve().parents[3]
root=repo/'marketing/appstore/2026-09-refresh'
for locale,folder in [('ko','ko-KR'),('en','en-US'),('ja','ja-JP')]:
    if len(sys.argv)>1 and locale not in sys.argv[1:]: continue
    p=root/folder/'preview'/f'app-preview-{locale}-886x1920.mp4'
    meta=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-of','json',str(p)]))
    v=next(s for s in meta['streams'] if s['codec_type']=='video')
    if v.get('pix_fmt')=='yuv420p' and v.get('color_space')=='bt709':
        print('Already normalized',locale);continue
    temp=p.with_name('.delivery.tmp.mp4')
    subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(p),'-t','28',
        '-vf','scale=in_range=pc:out_range=tv,format=yuv420p',
        '-c:v','libx264','-preset','fast','-profile:v','main','-level:v','4.0','-r','30',
        '-b:v','10M','-maxrate','12M','-bufsize','20M','-g','60',
        '-color_range','tv','-colorspace','bt709','-color_primaries','bt709','-color_trc','bt709',
        '-af','loudnorm=I=-16:TP=-1.5:LRA=8','-c:a','aac','-b:a','256k','-ar','48000','-ac','2',
        '-movflags','+faststart',str(temp)],check=True)
    temp.replace(p)
    print('NORMALIZED',locale,flush=True)
